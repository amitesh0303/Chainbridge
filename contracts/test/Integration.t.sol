// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BridgeVault.sol";
import "../src/BridgeRouter.sol";
import "../src/WrappedToken.sol";
import "../src/MockERC20.sol";

/// @title Integration test simulating A→B and B→A bridge flows on local anvil
/// @notice Uses chainid cheat codes to simulate two chains in a single test environment
contract IntegrationTest is Test {
    // Origin-chain contracts
    MockERC20 public originToken;
    BridgeVault public vault;
    BridgeRouter public originRouter;

    // Destination-chain contracts
    WrappedToken public wrappedToken;
    BridgeRouter public destRouter;

    address public relayer = address(0xBEEF);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    // Simulate two different chain IDs
    uint256 public constant ORIGIN_CHAIN_ID = 11155111; // Sepolia
    uint256 public constant DEST_CHAIN_ID = 17000;      // Hoodi

    function setUp() public {
        // ── Origin chain setup ──────────────────────────────────────────────
        vm.chainId(ORIGIN_CHAIN_ID);

        originToken = new MockERC20("Bridge Token", "BTK", 1_000_000 ether);
        originRouter = new BridgeRouter(relayer);
        vault = new BridgeVault(address(originToken), address(originRouter));
        originRouter.setVault(address(vault));

        // Fund alice with origin tokens
        originToken.transfer(alice, 10_000 ether);

        // ── Destination chain setup ─────────────────────────────────────────
        // (In reality these are on a different chain, but we test the logic here)
        vm.chainId(DEST_CHAIN_ID);

        destRouter = new BridgeRouter(relayer);
        wrappedToken = new WrappedToken("Wrapped BTK", "wBTK", address(destRouter));
        destRouter.setWrappedToken(address(wrappedToken));

        // Reset to origin chain for the actual flow
        vm.chainId(ORIGIN_CHAIN_ID);
    }

    // ─── A→B flow ──────────────────────────────────────────────────────────────

    function test_AtoB_FullFlow() public {
        uint256 amount = 1_000 ether;

        // ── Step 1: Alice locks tokens on origin chain ──────────────────────
        vm.chainId(ORIGIN_CHAIN_ID);

        uint256 aliceNonce = vault.nonces(alice);
        bytes32 expectedTxId = keccak256(
            abi.encodePacked(alice, bob, amount, aliceNonce, ORIGIN_CHAIN_ID, DEST_CHAIN_ID)
        );

        vm.startPrank(alice);
        originToken.approve(address(vault), amount);

        vm.expectEmit(true, true, true, true);
        emit BridgeVault.TokensLocked(expectedTxId, alice, bob, amount, aliceNonce, DEST_CHAIN_ID);
        vault.lockTokens(amount, bob, DEST_CHAIN_ID);
        vm.stopPrank();

        assertEq(originToken.balanceOf(address(vault)), amount);
        assertEq(originToken.balanceOf(alice), 10_000 ether - amount);

        // ── Step 2: Relayer calls completeBridge on destination chain ────────
        vm.chainId(DEST_CHAIN_ID);

        vm.prank(relayer);
        destRouter.completeBridge(expectedTxId, bob, amount, ORIGIN_CHAIN_ID);

        assertEq(wrappedToken.balanceOf(bob), amount);
        assertTrue(destRouter.processed(expectedTxId));
    }

    // ─── B→A flow ──────────────────────────────────────────────────────────────

    function test_BtoA_FullFlow() public {
        uint256 amount = 500 ether;

        // ── Pre-condition: Bob has wrapped tokens on destination chain ────────
        vm.chainId(DEST_CHAIN_ID);
        vm.prank(relayer);
        destRouter.completeBridge(keccak256("initial-bridge"), bob, amount, ORIGIN_CHAIN_ID);
        // Also lock corresponding tokens on origin side
        vm.chainId(ORIGIN_CHAIN_ID);
        originToken.transfer(alice, 0); // no-op, just keep tokens in vault by transferring to vault
        vm.startPrank(alice);
        originToken.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DEST_CHAIN_ID);
        vm.stopPrank();

        // ── Step 1: Bob burns wrapped tokens on destination chain ─────────────
        vm.chainId(DEST_CHAIN_ID);

        uint256 bobNonce = wrappedToken.burnNonces(bob);
        bytes32 expectedTxId = keccak256(
            abi.encodePacked(bob, alice, amount, bobNonce, DEST_CHAIN_ID, ORIGIN_CHAIN_ID)
        );

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit WrappedToken.TokensBurned(expectedTxId, bob, alice, amount, bobNonce, ORIGIN_CHAIN_ID);
        wrappedToken.burnForBridge(amount, alice, ORIGIN_CHAIN_ID);

        assertEq(wrappedToken.balanceOf(bob), 0);

        // ── Step 2: Relayer calls releaseBridge on origin chain ───────────────
        vm.chainId(ORIGIN_CHAIN_ID);

        uint256 aliceBalanceBefore = originToken.balanceOf(alice);

        vm.prank(relayer);
        originRouter.releaseBridge(expectedTxId, alice, amount, DEST_CHAIN_ID);

        assertEq(originToken.balanceOf(alice), aliceBalanceBefore + amount);
        assertTrue(originRouter.processed(expectedTxId));
    }

    // ─── Replay protection ─────────────────────────────────────────────────────

    function test_AtoB_ReplayProtection() public {
        uint256 amount = 100 ether;
        vm.chainId(ORIGIN_CHAIN_ID);

        uint256 aliceNonce = vault.nonces(alice);
        bytes32 txId = keccak256(
            abi.encodePacked(alice, bob, amount, aliceNonce, ORIGIN_CHAIN_ID, DEST_CHAIN_ID)
        );

        vm.startPrank(alice);
        originToken.approve(address(vault), amount);
        vault.lockTokens(amount, bob, DEST_CHAIN_ID);
        vm.stopPrank();

        vm.chainId(DEST_CHAIN_ID);

        vm.prank(relayer);
        destRouter.completeBridge(txId, bob, amount, ORIGIN_CHAIN_ID);

        // Replay attempt
        vm.prank(relayer);
        vm.expectRevert("BridgeRouter: txId already processed");
        destRouter.completeBridge(txId, bob, amount, ORIGIN_CHAIN_ID);
    }

    function test_BtoA_ReplayProtection() public {
        uint256 amount = 100 ether;

        // Setup: give bob some wrapped tokens
        vm.chainId(DEST_CHAIN_ID);
        vm.prank(relayer);
        destRouter.completeBridge(keccak256("setup"), bob, amount, ORIGIN_CHAIN_ID);

        // Setup: lock some tokens in vault
        vm.chainId(ORIGIN_CHAIN_ID);
        vm.startPrank(alice);
        originToken.approve(address(vault), amount * 2);
        vault.lockTokens(amount, bob, DEST_CHAIN_ID);
        vault.lockTokens(amount, bob, DEST_CHAIN_ID); // second lock for second release
        vm.stopPrank();

        vm.chainId(DEST_CHAIN_ID);

        uint256 bobNonce = wrappedToken.burnNonces(bob);
        bytes32 txId = keccak256(
            abi.encodePacked(bob, alice, amount, bobNonce, DEST_CHAIN_ID, ORIGIN_CHAIN_ID)
        );

        vm.prank(bob);
        wrappedToken.burnForBridge(amount, alice, ORIGIN_CHAIN_ID);

        vm.chainId(ORIGIN_CHAIN_ID);
        vm.prank(relayer);
        originRouter.releaseBridge(txId, alice, amount, DEST_CHAIN_ID);

        // Replay attempt
        vm.prank(relayer);
        vm.expectRevert("BridgeRouter: txId already processed");
        originRouter.releaseBridge(txId, alice, amount, DEST_CHAIN_ID);
    }
}
