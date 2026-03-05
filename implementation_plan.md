# ChainBridge Implementation Plan

## Overview

ChainBridge is a real, end-to-end cross-chain ERC-20 bridge between Ethereum Sepolia and Hoodi testnets, using a trusted-relayer model with lock-and-release on origin and mint-and-burn on destination.

---

## Components

### 1. Smart Contracts (`contracts/`)

**Foundry project with Solidity ^0.8.20**

#### Contracts

| Contract | Chain | Purpose |
|---|---|---|
| `MockERC20.sol` | Sepolia | Native ERC-20 token (BTK) |
| `BridgeVault.sol` | Sepolia | Locks BTK, releases on return bridge |
| `WrappedToken.sol` | Hoodi | Mintable/burnable wBTK |
| `BridgeRouter.sol` | Both | Entry-point for the relayer |

#### Key Design Decisions

- `txId = keccak256(abi.encodePacked(sender, recipient, amount, nonce, chainId, dstChainId))`
  - Nonce prevents replay: same user bridging same amount twice gets different txIds
  - ChainId included so a txId from chain A cannot be replayed on chain A itself
- BridgeVault uses `ReentrancyGuard` + `SafeERC20` for safe token handling
- BridgeRouter is the single entry-point for the relayer — it checks processed status before calling vault/token
- Both vault and wrapped token are `Pausable` for emergency stops

#### Test Coverage

- `BridgeVault.t.sol` — lock, release, replay protection, access control, pause
- `WrappedToken.t.sol` — mint, burnForBridge, nonce tracking, access control, pause
- `BridgeRouter.t.sol` — completeBridge, releaseBridge, replay protection, only-relayer
- `Integration.t.sol` — full A→B and B→A flows using `vm.chainId()` cheat code

---

### 2. Relayer (`relayer/`)

**Node.js + TypeScript using ethers.js v6**

#### Architecture

```
index.ts (main loop)
  ├── listener.ts (BridgeListener)
  │     ├── fetchLockEvents() — polls Sepolia BridgeVault
  │     └── fetchBurnEvents() — polls Hoodi WrappedToken
  ├── executor.ts (BridgeExecutor)
  │     ├── handleLockEvent() — calls completeBridge on Hoodi router
  │     └── handleBurnEvent() — calls releaseBridge on Sepolia router
  └── checkpoints.ts — persists last-processed block to data/checkpoints.json
```

#### Features

- Block checkpoint persistence (crash recovery)
- N-confirmation wait before processing events
- Exponential backoff retry on nonce/gas/network errors
- Idempotent: checks `processed[txId]` before sending tx

---

### 3. Frontend (`frontend/`)

**React + Vite + wagmi v2 + RainbowKit v2**

#### Architecture

```
main.tsx — WagmiProvider + RainbowKitProvider + QueryClient
  └── App.tsx
        └── BridgeWidget.tsx
              ├── Direction selector (A→B / B→A)
              ├── Network guard (prompt switch)
              ├── Balance display (origin + destination)
              ├── Amount input + MAX button
              ├── Recipient (default = connected wallet)
              └── Multi-step flow:
                    A→B: Approve → Lock → Poll relay → Success
                    B→A: Burn → Poll relay → Success
```

#### Key Features

- Real wallet connection via RainbowKit
- Real on-chain reads (balances, allowances, nonces)
- txId computed on frontend = same formula as contracts
- Polls destination router `processed[txId]` every 10s to detect relay completion
- Etherscan / Hoodi Explorer links for all transactions
- Network switch prompt when user is on wrong chain

---

## Security Summary

| Risk | Mitigation |
|---|---|
| Replay attack | `processedTxIds` in vault + `processed` in router; txId includes nonce |
| Unauthorized mint | `onlyRouter` modifier on `WrappedToken.mint` |
| Unauthorized release | `onlyRouter` modifier on `BridgeVault.releaseTokens` |
| Reentrancy | `ReentrancyGuard` on BridgeVault; `SafeERC20` for transfers |
| Token theft | `transferFrom` only from `msg.sender` |
| Same-chain bridge | `require(dstChainId != block.chainid)` in lock and burn |
| Trusted relayer risk | Single trusted relayer (acceptable for testnet; for production use multi-sig) |

---

## Deployment Checklist

- [ ] Deploy contracts to Sepolia (`forge script script/DeployOrigin.s.sol`)
- [ ] Deploy contracts to Hoodi (`forge script script/DeployDestination.s.sol`)
- [ ] Fill `relayer/.env` with all addresses
- [ ] Fund relayer wallet on both chains
- [ ] Start relayer (`cd relayer && npm start`)
- [ ] Fill `frontend/.env` with all addresses
- [ ] Start frontend (`cd frontend && npm run dev`)
- [ ] Test A→B flow with small amount
- [ ] Test B→A flow with small amount
