// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BridgeRouter.sol";
import "../src/BridgeVault.sol";
import "../src/WrappedToken.sol";
import "../src/MockERC20.sol";

contract BridgeRouterTest is Test {
    BridgeRouter public routerOrigin;   // origin chain router
    BridgeRouter public routerDest;     // destination chain router
    BridgeVault public vault;
    WrappedToken public wrappedToken;
    MockERC20 public originToken;

    address public owner = address(this);
    address public relayer = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public attacker = address(0x4);

    uint256 public constant SRC_CHAIN_ID = 11155111;
    uint256 public constant DST_CHAIN_ID = 17000;

    function setUp() public {
        // Deploy origin infrastructure
        originToken = new MockERC20("Origin Token", "OTK", 1_000_000 ether);
        routerOrigin = new BridgeRouter(relayer);
        vault = new BridgeVault(address(originToken), address(routerOrigin));
        routerOrigin.setVault(address(vault));

        // Deploy destination infrastructure
        routerDest = new BridgeRouter(relayer);
        wrappedToken = new WrappedToken("Wrapped Origin", "wOTK", address(routerDest));
        routerDest.setWrappedToken(address(wrappedToken));

        // Fund alice
        originToken.transfer(alice, 10_000 ether);
    }

    // ─── completeBridge ────────────────────────────────────────────────────────

    function test_CompleteBridge_MintsTokens() public {
        bytes32 txId = keccak256("lock-event-txid");
        uint256 amount = 500 ether;

        vm.prank(relayer);
        routerDest.completeBridge(txId, alice, amount, SRC_CHAIN_ID);

        assertEq(wrappedToken.balanceOf(alice), amount);
    }

    function test_CompleteBridge_MarksProcessed() public {
        bytes32 txId = keccak256("lock-event-txid");

        vm.prank(relayer);
        routerDest.completeBridge(txId, alice, 100 ether, SRC_CHAIN_ID);

        assertTrue(routerDest.processed(txId));
    }

    function test_CompleteBridge_EmitsEvent() public {
        bytes32 txId = keccak256("lock-event-txid");
        uint256 amount = 100 ether;

        vm.prank(relayer);
        vm.expectEmit(true, true, false, true);
        emit BridgeRouter.BridgeCompleted(txId, alice, amount, SRC_CHAIN_ID);
        routerDest.completeBridge(txId, alice, amount, SRC_CHAIN_ID);
    }

    function test_CompleteBridge_RevertsNonRelayer() public {
        bytes32 txId = keccak256("lock-event-txid");

        vm.prank(attacker);
        vm.expectRevert("BridgeRouter: caller is not the relayer");
        routerDest.completeBridge(txId, alice, 100 ether, SRC_CHAIN_ID);
    }

    function test_CompleteBridge_RevertsReplay() public {
        bytes32 txId = keccak256("lock-event-txid");

        vm.prank(relayer);
        routerDest.completeBridge(txId, alice, 100 ether, SRC_CHAIN_ID);

        vm.prank(relayer);
        vm.expectRevert("BridgeRouter: txId already processed");
        routerDest.completeBridge(txId, alice, 100 ether, SRC_CHAIN_ID);
    }

    function test_CompleteBridge_RevertsWhenNoWrappedToken() public {
        BridgeRouter freshRouter = new BridgeRouter(relayer);
        bytes32 txId = keccak256("lock-event-txid");

        vm.prank(relayer);
        vm.expectRevert("BridgeRouter: wrapped token not set");
        freshRouter.completeBridge(txId, alice, 100 ether, SRC_CHAIN_ID);
    }

    // ─── releaseBridge ─────────────────────────────────────────────────────────

    function test_ReleaseBridge_ReleasesTokens() public {
        // Lock tokens first so vault has funds
        uint256 amount = 300 ether;
        vm.startPrank(alice);
        originToken.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        bytes32 txId = keccak256("burn-event-txid");

        vm.prank(relayer);
        routerOrigin.releaseBridge(txId, alice, amount, DST_CHAIN_ID);

        assertEq(originToken.balanceOf(alice), 10_000 ether - amount + amount);
    }

    function test_ReleaseBridge_MarksProcessed() public {
        uint256 amount = 100 ether;
        vm.startPrank(alice);
        originToken.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        bytes32 txId = keccak256("burn-event-txid");

        vm.prank(relayer);
        routerOrigin.releaseBridge(txId, alice, amount, DST_CHAIN_ID);

        assertTrue(routerOrigin.processed(txId));
    }

    function test_ReleaseBridge_EmitsEvent() public {
        uint256 amount = 100 ether;
        vm.startPrank(alice);
        originToken.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        bytes32 txId = keccak256("burn-event-txid");

        vm.prank(relayer);
        vm.expectEmit(true, true, false, true);
        emit BridgeRouter.BridgeReleased(txId, alice, amount, DST_CHAIN_ID);
        routerOrigin.releaseBridge(txId, alice, amount, DST_CHAIN_ID);
    }

    function test_ReleaseBridge_RevertsNonRelayer() public {
        bytes32 txId = keccak256("burn-event-txid");

        vm.prank(attacker);
        vm.expectRevert("BridgeRouter: caller is not the relayer");
        routerOrigin.releaseBridge(txId, alice, 100 ether, DST_CHAIN_ID);
    }

    function test_ReleaseBridge_RevertsReplay() public {
        uint256 amount = 200 ether;
        vm.startPrank(alice);
        originToken.approve(address(vault), amount * 2);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        bytes32 txId = keccak256("burn-event-txid");

        vm.prank(relayer);
        routerOrigin.releaseBridge(txId, alice, amount, DST_CHAIN_ID);

        vm.prank(relayer);
        vm.expectRevert("BridgeRouter: txId already processed");
        routerOrigin.releaseBridge(txId, alice, amount, DST_CHAIN_ID);
    }

    function test_ReleaseBridge_RevertsWhenNoVault() public {
        BridgeRouter freshRouter = new BridgeRouter(relayer);
        bytes32 txId = keccak256("burn-event-txid");

        vm.prank(relayer);
        vm.expectRevert("BridgeRouter: vault not set");
        freshRouter.releaseBridge(txId, alice, 100 ether, DST_CHAIN_ID);
    }

    // ─── Admin ─────────────────────────────────────────────────────────────────

    function test_SetRelayer_OnlyOwner() public {
        address newRelayer = address(0x99);
        routerDest.setRelayer(newRelayer);
        assertEq(routerDest.relayer(), newRelayer);

        vm.prank(attacker);
        vm.expectRevert();
        routerDest.setRelayer(address(0x88));
    }

    function test_Pause_BlocksCompleteBridge() public {
        routerDest.pause();
        bytes32 txId = keccak256("lock-event-txid");

        vm.prank(relayer);
        vm.expectRevert();
        routerDest.completeBridge(txId, alice, 100 ether, SRC_CHAIN_ID);
    }
}
