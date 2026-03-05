// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/WrappedToken.sol";

contract WrappedTokenTest is Test {
    WrappedToken public token;

    address public owner = address(this);
    address public router = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);

    uint256 public constant DST_CHAIN_ID = 11155111; // Sepolia chain ID

    function setUp() public {
        token = new WrappedToken("Wrapped Test Token", "wTEST", router);
    }

    // ─── mint ──────────────────────────────────────────────────────────────────

    function test_Mint_RouterCanMint() public {
        vm.prank(router);
        token.mint(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
    }

    function test_Mint_RevertsNonRouter() public {
        vm.prank(alice);
        vm.expectRevert("WrappedToken: caller is not the router");
        token.mint(alice, 100 ether);
    }

    function test_Mint_RevertsZeroAddress() public {
        vm.prank(router);
        vm.expectRevert("WrappedToken: zero address");
        token.mint(address(0), 100 ether);
    }

    function test_Mint_RevertsZeroAmount() public {
        vm.prank(router);
        vm.expectRevert("WrappedToken: amount must be > 0");
        token.mint(alice, 0);
    }

    // ─── burnForBridge ─────────────────────────────────────────────────────────

    function test_BurnForBridge_BurnsTokens() public {
        // First mint some tokens to alice
        vm.prank(router);
        token.mint(alice, 200 ether);

        vm.prank(alice);
        token.burnForBridge(100 ether, bob, DST_CHAIN_ID);

        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.totalSupply(), 100 ether);
    }

    function test_BurnForBridge_EmitsCorrectTxId() public {
        vm.prank(router);
        token.mint(alice, 100 ether);

        uint256 amount = 100 ether;
        uint256 nonce = 0;
        bytes32 expectedTxId = keccak256(
            abi.encodePacked(alice, bob, amount, nonce, block.chainid, DST_CHAIN_ID)
        );

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit WrappedToken.TokensBurned(expectedTxId, alice, bob, amount, nonce, DST_CHAIN_ID);
        token.burnForBridge(amount, bob, DST_CHAIN_ID);
    }

    function test_BurnForBridge_IncrementsNonce() public {
        vm.prank(router);
        token.mint(alice, 200 ether);

        assertEq(token.burnNonces(alice), 0);
        vm.prank(alice);
        token.burnForBridge(50 ether, bob, DST_CHAIN_ID);
        assertEq(token.burnNonces(alice), 1);

        vm.prank(alice);
        token.burnForBridge(50 ether, bob, DST_CHAIN_ID);
        assertEq(token.burnNonces(alice), 2);
    }

    function test_BurnForBridge_DifferentNoncesDifferentTxIds() public {
        vm.prank(router);
        token.mint(alice, 200 ether);

        uint256 amount = 50 ether;

        bytes32 txId1 = keccak256(abi.encodePacked(alice, bob, amount, uint256(0), block.chainid, DST_CHAIN_ID));
        bytes32 txId2 = keccak256(abi.encodePacked(alice, bob, amount, uint256(1), block.chainid, DST_CHAIN_ID));

        assertTrue(txId1 != txId2);

        vm.startPrank(alice);
        token.burnForBridge(amount, bob, DST_CHAIN_ID);
        token.burnForBridge(amount, bob, DST_CHAIN_ID);
        vm.stopPrank();
    }

    function test_BurnForBridge_RevertsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("WrappedToken: amount must be > 0");
        token.burnForBridge(0, bob, DST_CHAIN_ID);
    }

    function test_BurnForBridge_RevertsZeroRecipient() public {
        vm.prank(router);
        token.mint(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert("WrappedToken: zero recipient");
        token.burnForBridge(100 ether, address(0), DST_CHAIN_ID);
    }

    function test_BurnForBridge_RevertsSameChain() public {
        vm.prank(router);
        token.mint(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert("WrappedToken: same chain");
        token.burnForBridge(100 ether, bob, block.chainid);
    }

    // ─── Pause ─────────────────────────────────────────────────────────────────

    function test_Pause_BlocksMint() public {
        token.pause();
        vm.prank(router);
        vm.expectRevert();
        token.mint(alice, 100 ether);
    }

    function test_Pause_BlocksBurn() public {
        vm.prank(router);
        token.mint(alice, 100 ether);

        token.pause();

        vm.prank(alice);
        vm.expectRevert();
        token.burnForBridge(100 ether, bob, DST_CHAIN_ID);
    }

    function test_SetRouter_OnlyOwner() public {
        address newRouter = address(0x99);
        token.setRouter(newRouter);
        assertEq(token.router(), newRouter);

        vm.prank(alice);
        vm.expectRevert();
        token.setRouter(address(0x88));
    }
}
