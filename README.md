# ChainBridge

A real, end-to-end cross-chain ERC-20 bridge between Ethereum Sepolia and Hoodi testnets.

**Lock on origin → Mint on destination · Burn on destination → Release on origin**

---

## Architecture

```
Sepolia                             Hoodi
──────────────────────────────────  ──────────────────────────────────
BridgeVault (holds BTK)             WrappedToken (wBTK, mint/burn)
BridgeRouter (releaseBridge)        BridgeRouter (completeBridge)
BTK (origin ERC-20)                 wBTK (wrapped ERC-20)
        │                                         │
        └──────────── Relayer ────────────────────┘
                 (off-chain Node.js)
```

---

## Project Layout

```
chainbridge/
  contracts/        Foundry project (Solidity ^0.8.20)
    src/
      BridgeVault.sol
      BridgeRouter.sol
      WrappedToken.sol
      MockERC20.sol
    test/
      BridgeVault.t.sol
      WrappedToken.t.sol
      BridgeRouter.t.sol
      Integration.t.sol
    script/
      DeployOrigin.s.sol
      DeployDestination.s.sol
    foundry.toml
    .env.example

  relayer/          Node.js + TypeScript relayer
    src/
      config.ts
      abis.ts
      listener.ts
      executor.ts
      checkpoints.ts
      index.ts
    data/
      checkpoints.json
    package.json
    tsconfig.json
    .env.example

  frontend/         React + Vite + wagmi + RainbowKit
    src/
      config.ts
      abis.ts
      main.tsx
      styles.css
      components/
        App.tsx
        BridgeWidget.tsx
      hooks/
        useBridge.ts
      utils/
        bridge.ts
    index.html
    vite.config.ts
    .env.example

  README.md
  implementation_plan.md
```

---

## Prerequisites

- [Foundry](https://getfoundry.sh/) — `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- Node.js >= 18
- A funded wallet on both Sepolia and Hoodi (for the deployer and relayer)
- RPC URLs for Sepolia and Hoodi (e.g., Alchemy, Infura, or public endpoints)
- [WalletConnect Project ID](https://cloud.walletconnect.com/) for the frontend

---

## 1. Deploy Contracts

### Install dependencies

```bash
cd contracts
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
```

### Create `.env`

```bash
cp .env.example .env
# Fill in:
# DEPLOYER_PRIVATE_KEY  — private key of the deployer wallet
# DEPLOYER_ADDRESS      — address of the deployer wallet
# RELAYER_ADDRESS       — address of the relayer wallet (used by both routers)
# SEPOLIA_RPC_URL       — e.g. https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
# HOODI_RPC_URL         — e.g. https://rpc.hoodi.ethpandaops.io
# ETHERSCAN_API_KEY     — optional, for contract verification
```

### Deploy to Sepolia (origin chain)

```bash
forge script script/DeployOrigin.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify
```

Note the output:
- `OriginToken` address  
- `BridgeVault` address  
- `OriginRouter` address  

### Deploy to Hoodi (destination chain)

```bash
forge script script/DeployDestination.s.sol \
  --rpc-url $HOODI_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY
```

Note the output:
- `WrappedToken` address  
- `DestRouter` address  

---

## 2. Run Tests

```bash
cd contracts
forge test -vv
```

Tests cover:
- BridgeVault: lock, release, replay protection, access control, pause
- WrappedToken: mint, burnForBridge, nonce tracking, access control, pause
- BridgeRouter: completeBridge, releaseBridge, replay protection, access control
- Integration: full A→B and B→A flows using chainid cheat codes

---

## 3. Start the Relayer

### Configure

```bash
cd relayer
cp .env.example .env
# Fill in all addresses from the deployment step above, plus:
# RELAYER_PRIVATE_KEY   — private key of the relayer wallet (funded on both chains)
# SEPOLIA_START_BLOCK   — deployment block number on Sepolia
# HOODI_START_BLOCK     — deployment block number on Hoodi
```

### Install & run

```bash
npm install
npm run start
# or for development with ts-node:
npm run dev
```

The relayer will:
1. Poll Sepolia for `TokensLocked` events every `POLL_INTERVAL_MS` milliseconds
2. For each lock event, call `completeBridge` on the Hoodi router
3. Poll Hoodi for `TokensBurned` events
4. For each burn event, call `releaseBridge` on the Sepolia router
5. Save block checkpoints to `data/checkpoints.json` for crash recovery

---

## 4. Start the Frontend

### Configure

```bash
cd frontend
cp .env.example .env
# Fill in all contract addresses and VITE_WALLETCONNECT_PROJECT_ID
```

### Install & run

```bash
npm install
npm run dev
```

Open http://localhost:5173 in your browser, connect MetaMask to Sepolia or Hoodi, and bridge tokens.

### Build for production

```bash
npm run build
# Output in frontend/dist/
```

---

## Deployed Addresses (fill in after deployment)

| Contract        | Chain   | Address |
|----------------|---------|---------|
| BTK Token       | Sepolia | `0x...` |
| BridgeVault     | Sepolia | `0x...` |
| OriginRouter    | Sepolia | `0x...` |
| wBTK Token      | Hoodi   | `0x...` |
| DestRouter      | Hoodi   | `0x...` |

---

## Bridge Flow

### A→B (Sepolia → Hoodi)

1. User approves BTK to BridgeVault
2. User calls `BridgeVault.lockTokens(amount, recipient, hoodiChainId)`
3. Relayer detects `TokensLocked` event
4. Relayer calls `DestRouter.completeBridge(txId, recipient, amount, sepoliaChainId)` on Hoodi
5. DestRouter calls `WrappedToken.mint(recipient, amount)`
6. User receives wBTK on Hoodi

### B→A (Hoodi → Sepolia)

1. User calls `WrappedToken.burnForBridge(amount, recipient, sepoliaChainId)`
2. Relayer detects `TokensBurned` event
3. Relayer calls `OriginRouter.releaseBridge(txId, recipient, amount, hoodiChainId)` on Sepolia
4. OriginRouter calls `BridgeVault.releaseTokens(txId, recipient, amount)`
5. User receives original BTK on Sepolia

### txId computation

The `txId` is computed identically in all three layers (contract, relayer, frontend):

```
txId = keccak256(abi.encodePacked(sender, recipient, amount, nonce, chainId, dstChainId))
```

This ensures trustless tracking of bridge transactions.

---

## Security Notes

- This bridge uses a **trusted-relayer model** — the relayer key is trusted to call completeBridge/releaseBridge. For production, consider a multi-sig validator set.
- Replay protection: every `txId` is tracked in `processedTxIds` (vault) and `processed` (router) mappings.
- Access control: `releaseTokens` is `onlyRouter`; `mint` is `onlyRouter`.
- Reentrancy: BridgeVault uses `ReentrancyGuard` and SafeERC20.
- Both vault and token contracts are pausable by the owner.
- All input validation is present (zero checks, same-chain checks, amount > 0).