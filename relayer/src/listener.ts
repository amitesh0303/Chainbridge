import { ethers } from "ethers";
import { BRIDGE_VAULT_ABI, WRAPPED_TOKEN_ABI } from "./abis";
import { loadCheckpoints, saveCheckpoints } from "./checkpoints";
import config from "./config";

export interface LockEvent {
  txId: string;
  sender: string;
  recipient: string;
  amount: bigint;
  nonce: bigint;
  dstChainId: bigint;
  blockNumber: number;
  transactionHash: string;
}

export interface BurnEvent {
  txId: string;
  sender: string;
  recipient: string;
  amount: bigint;
  nonce: bigint;
  dstChainId: bigint;
  blockNumber: number;
  transactionHash: string;
}

export class BridgeListener {
  private sepoliaProvider: ethers.JsonRpcProvider;
  private hoodiProvider: ethers.JsonRpcProvider;

  constructor() {
    this.sepoliaProvider = new ethers.JsonRpcProvider(config.sepolia.rpcUrl);
    this.hoodiProvider = new ethers.JsonRpcProvider(config.hoodi.rpcUrl);
  }

  /**
   * Fetch new TokensLocked events from BridgeVault on Sepolia
   */
  async fetchLockEvents(): Promise<LockEvent[]> {
    const checkpoints = loadCheckpoints();
    const fromBlock = Math.max(
      checkpoints.sepolia,
      config.sepolia.startBlock
    );

    const currentBlock = await this.sepoliaProvider.getBlockNumber();
    const safeBlock = currentBlock - config.minConfirmations;

    if (safeBlock <= fromBlock) {
      return [];
    }

    console.log(
      `[Sepolia] Scanning TokensLocked events from block ${fromBlock} to ${safeBlock}`
    );

    const vault = new ethers.Contract(
      config.sepolia.vaultAddress,
      BRIDGE_VAULT_ABI,
      this.sepoliaProvider
    );

    const filter = vault.filters.TokensLocked();
    const rawLogs = await vault.queryFilter(filter, fromBlock, safeBlock);

    const events: LockEvent[] = rawLogs.map((log) => {
      const parsed = vault.interface.parseLog({
        topics: log.topics as string[],
        data: log.data,
      })!;

      return {
        txId: parsed.args[0] as string,
        sender: parsed.args[1] as string,
        recipient: parsed.args[2] as string,
        amount: parsed.args[3] as bigint,
        nonce: parsed.args[4] as bigint,
        dstChainId: parsed.args[5] as bigint,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
      };
    });

    // Update checkpoint
    checkpoints.sepolia = safeBlock + 1;
    saveCheckpoints(checkpoints);

    return events;
  }

  /**
   * Fetch new TokensBurned events from WrappedToken on Hoodi
   */
  async fetchBurnEvents(): Promise<BurnEvent[]> {
    const checkpoints = loadCheckpoints();
    const fromBlock = Math.max(
      checkpoints.hoodi,
      config.hoodi.startBlock
    );

    const currentBlock = await this.hoodiProvider.getBlockNumber();
    const safeBlock = currentBlock - config.minConfirmations;

    if (safeBlock <= fromBlock) {
      return [];
    }

    console.log(
      `[Hoodi] Scanning TokensBurned events from block ${fromBlock} to ${safeBlock}`
    );

    const wrappedToken = new ethers.Contract(
      config.hoodi.wrappedTokenAddress,
      WRAPPED_TOKEN_ABI,
      this.hoodiProvider
    );

    const filter = wrappedToken.filters.TokensBurned();
    const rawLogs = await wrappedToken.queryFilter(filter, fromBlock, safeBlock);

    const events: BurnEvent[] = rawLogs.map((log) => {
      const parsed = wrappedToken.interface.parseLog({
        topics: log.topics as string[],
        data: log.data,
      })!;

      return {
        txId: parsed.args[0] as string,
        sender: parsed.args[1] as string,
        recipient: parsed.args[2] as string,
        amount: parsed.args[3] as bigint,
        nonce: parsed.args[4] as bigint,
        dstChainId: parsed.args[5] as bigint,
        blockNumber: log.blockNumber,
        transactionHash: log.transactionHash,
      };
    });

    // Update checkpoint
    checkpoints.hoodi = safeBlock + 1;
    saveCheckpoints(checkpoints);

    return events;
  }
}
