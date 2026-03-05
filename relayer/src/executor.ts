import { ethers } from "ethers";
import { BRIDGE_ROUTER_ABI } from "./abis";
import config from "./config";
import type { LockEvent, BurnEvent } from "./listener";

const MAX_RETRIES = 5;
const BASE_DELAY_MS = 1000;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function withRetry<T>(
  fn: () => Promise<T>,
  label: string
): Promise<T | null> {
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      return await fn();
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      const isRetryable =
        message.includes("nonce") ||
        message.includes("gas") ||
        message.includes("network") ||
        message.includes("timeout") ||
        message.includes("underpriced");

      if (!isRetryable || attempt === MAX_RETRIES - 1) {
        console.error(`[Executor] ${label} failed after ${attempt + 1} attempts:`, message);
        return null;
      }

      const delayMs = BASE_DELAY_MS * Math.pow(2, attempt);
      console.warn(
        `[Executor] ${label} attempt ${attempt + 1} failed (${message}), retrying in ${delayMs}ms...`
      );
      await sleep(delayMs);
    }
  }
  return null;
}

export class BridgeExecutor {
  private sepoliaSigner: ethers.Wallet;
  private hoodiSigner: ethers.Wallet;
  private sepoliaRouter: ethers.Contract;
  private hoodiRouter: ethers.Contract;

  constructor() {
    const sepoliaProvider = new ethers.JsonRpcProvider(config.sepolia.rpcUrl);
    const hoodiProvider = new ethers.JsonRpcProvider(config.hoodi.rpcUrl);

    this.sepoliaSigner = new ethers.Wallet(config.relayerPrivateKey, sepoliaProvider);
    this.hoodiSigner = new ethers.Wallet(config.relayerPrivateKey, hoodiProvider);

    this.sepoliaRouter = new ethers.Contract(
      config.sepolia.routerAddress,
      BRIDGE_ROUTER_ABI,
      this.sepoliaSigner
    );

    this.hoodiRouter = new ethers.Contract(
      config.hoodi.routerAddress,
      BRIDGE_ROUTER_ABI,
      this.hoodiSigner
    );
  }

  /**
   * Check if a txId has already been processed on the destination router
   */
  async isProcessedOnHoodi(txId: string): Promise<boolean> {
    return (await this.hoodiRouter.processed(txId)) as boolean;
  }

  /**
   * Check if a txId has already been processed on the origin router
   */
  async isProcessedOnSepolia(txId: string): Promise<boolean> {
    return (await this.sepoliaRouter.processed(txId)) as boolean;
  }

  /**
   * Handle a TokensLocked event: call completeBridge on Hoodi
   */
  async handleLockEvent(event: LockEvent): Promise<void> {
    const { txId, recipient, amount, blockNumber, transactionHash } = event;

    console.log(
      `[Executor] LOCK event: txId=${txId} amount=${ethers.formatEther(amount)} ` +
        `block=${blockNumber} originTx=${transactionHash}`
    );

    // Skip if already processed (idempotent)
    const alreadyProcessed = await this.isProcessedOnHoodi(txId);
    if (alreadyProcessed) {
      console.log(`[Executor] txId=${txId} already processed on Hoodi, skipping`);
      return;
    }

    const result = await withRetry(async () => {
      const tx = await this.hoodiRouter.completeBridge(
        txId,
        recipient,
        amount,
        config.sepolia.chainId
      );
      console.log(`[Executor] completeBridge tx sent: hash=${tx.hash}`);
      const receipt = await tx.wait();
      console.log(
        `[Executor] completeBridge confirmed: hash=${receipt.hash} gasUsed=${receipt.gasUsed}`
      );
      return receipt;
    }, `completeBridge(${txId})`);

    if (!result) {
      console.error(`[Executor] Failed to complete bridge for txId=${txId}`);
    }
  }

  /**
   * Handle a TokensBurned event: call releaseBridge on Sepolia
   */
  async handleBurnEvent(event: BurnEvent): Promise<void> {
    const { txId, recipient, amount, blockNumber, transactionHash } = event;

    console.log(
      `[Executor] BURN event: txId=${txId} amount=${ethers.formatEther(amount)} ` +
        `block=${blockNumber} burnTx=${transactionHash}`
    );

    // Skip if already processed (idempotent)
    const alreadyProcessed = await this.isProcessedOnSepolia(txId);
    if (alreadyProcessed) {
      console.log(`[Executor] txId=${txId} already processed on Sepolia, skipping`);
      return;
    }

    const result = await withRetry(async () => {
      const tx = await this.sepoliaRouter.releaseBridge(
        txId,
        recipient,
        amount,
        config.hoodi.chainId
      );
      console.log(`[Executor] releaseBridge tx sent: hash=${tx.hash}`);
      const receipt = await tx.wait();
      console.log(
        `[Executor] releaseBridge confirmed: hash=${receipt.hash} gasUsed=${receipt.gasUsed}`
      );
      return receipt;
    }, `releaseBridge(${txId})`);

    if (!result) {
      console.error(`[Executor] Failed to release bridge for txId=${txId}`);
    }
  }
}
