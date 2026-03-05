// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BridgeVault.sol";
import "../src/MockERC20.sol";

contract BridgeVaultTest is Test {
    BridgeVault public vault;
    MockERC20 public token;

    address public owner = address(this);
    address public router = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 public constant DST_CHAIN_ID = 17000; // Hoodi chain ID

    function setUp() public {
        token = new MockERC20("Test Token", "TEST", INITIAL_SUPPLY);
        vault = new BridgeVault(address(token), router);

        // Fund alice
        token.transfer(alice, 10_000 ether);
    }

    // ─── lockTokens ────────────────────────────────────────────────────────────

    function test_LockTokens_TransfersTokens() public {
        uint256 amount = 100 ether;
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), amount);
        assertEq(token.balanceOf(alice), 10_000 ether - amount);
    }

    function test_LockTokens_EmitsEvent() public {
        uint256 amount = 100 ether;
        uint256 nonce = 0;
        bytes32 expectedTxId = keccak256(
            abi.encodePacked(alice, bob, amount, nonce, block.chainid, DST_CHAIN_ID)
        );

        vm.startPrank(alice);
        token.approve(address(vault), amount);

        vm.expectEmit(true, true, true, true);
        emit BridgeVault.TokensLocked(expectedTxId, alice, bob, amount, nonce, DST_CHAIN_ID);

        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();
    }

    function test_LockTokens_IncrementsNonce() public {
        uint256 amount = 50 ether;
        vm.startPrank(alice);
        token.approve(address(vault), amount * 3);

        assertEq(vault.nonces(alice), 0);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        assertEq(vault.nonces(alice), 1);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        assertEq(vault.nonces(alice), 2);
        vm.stopPrank();
    }

    function test_LockTokens_RevertsZeroAmount() public {
        vm.startPrank(alice);
        token.approve(address(vault), 100 ether);
        vm.expectRevert("BridgeVault: amount must be > 0");
        vault.lockTokens(0, bob, DST_CHAIN_ID);
        vm.stopPrank();
    }

    function test_LockTokens_RevertsZeroRecipient() public {
        vm.startPrank(alice);
        token.approve(address(vault), 100 ether);
        vm.expectRevert("BridgeVault: zero recipient");
        vault.lockTokens(100 ether, address(0), DST_CHAIN_ID);
        vm.stopPrank();
    }

    function test_LockTokens_RevertsSameChain() public {
        vm.startPrank(alice);
        token.approve(address(vault), 100 ether);
        vm.expectRevert("BridgeVault: same chain");
        vault.lockTokens(100 ether, bob, block.chainid);
        vm.stopPrank();
    }

    // ─── releaseTokens ─────────────────────────────────────────────────────────

    function test_ReleaseTokens_TransfersTokens() public {
        // First lock some tokens so vault has funds
        uint256 amount = 100 ether;
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        bytes32 txId = keccak256("some-unique-txid");

        uint256 recipientBalanceBefore = token.balanceOf(bob);

        vm.prank(router);
        vault.releaseTokens(txId, bob, amount);

        assertEq(token.balanceOf(bob), recipientBalanceBefore + amount);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_ReleaseTokens_EmitsEvent() public {
        uint256 amount = 100 ether;
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        bytes32 txId = keccak256("some-unique-txid");

        vm.prank(router);
        vm.expectEmit(true, true, false, true);
        emit BridgeVault.TokensReleased(txId, bob, amount);
        vault.releaseTokens(txId, bob, amount);
    }

    function test_ReleaseTokens_MarksProcessed() public {
        uint256 amount = 100 ether;
        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        bytes32 txId = keccak256("some-unique-txid");
        vm.prank(router);
        vault.releaseTokens(txId, bob, amount);

        assertTrue(vault.processedTxIds(txId));
    }

    function test_ReleaseTokens_RevertsReplay() public {
        uint256 amount = 100 ether;
        vm.startPrank(alice);
        token.approve(address(vault), amount * 2);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vault.lockTokens(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();

        bytes32 txId = keccak256("some-unique-txid");
        vm.prank(router);
        vault.releaseTokens(txId, bob, amount);

        vm.prank(router);
        vm.expectRevert("BridgeVault: txId already processed");
        vault.releaseTokens(txId, bob, amount);
    }

    function test_ReleaseTokens_RevertsNonRouter() public {
        bytes32 txId = keccak256("some-unique-txid");
        vm.prank(alice);
        vm.expectRevert("BridgeVault: caller is not the router");
        vault.releaseTokens(txId, bob, 100 ether);
    }

    // ─── Pause ─────────────────────────────────────────────────────────────────

    function test_Pause_BlocksLock() public {
        vault.pause();
        vm.startPrank(alice);
        token.approve(address(vault), 100 ether);
        vm.expectRevert();
        vault.lockTokens(100 ether, bob, DST_CHAIN_ID);
        vm.stopPrank();
    }

    function test_Pause_BlocksRelease() public {
        vault.pause();
        bytes32 txId = keccak256("some-unique-txid");
        vm.prank(router);
        vm.expectRevert();
        vault.releaseTokens(txId, bob, 100 ether);
    }

    function test_SetRouter_OnlyOwner() public {
        address newRouter = address(0x99);
        vault.setRouter(newRouter);
        assertEq(vault.router(), newRouter);

        vm.prank(alice);
        vm.expectRevert();
        vault.setRouter(address(0x88));
    }
}
