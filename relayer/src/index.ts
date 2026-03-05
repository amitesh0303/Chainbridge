import config from "./config";
import { BridgeListener } from "./listener";
import { BridgeExecutor } from "./executor";

const listener = new BridgeListener();
const executor = new BridgeExecutor();

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function processLockEvents(): Promise<void> {
  try {
    const lockEvents = await listener.fetchLockEvents();
    if (lockEvents.length > 0) {
      console.log(`[Relayer] Found ${lockEvents.length} new lock event(s)`);
    }
    for (const event of lockEvents) {
      await executor.handleLockEvent(event);
    }
  } catch (err) {
    console.error("[Relayer] Error processing lock events:", err);
  }
}

async function processBurnEvents(): Promise<void> {
  try {
    const burnEvents = await listener.fetchBurnEvents();
    if (burnEvents.length > 0) {
      console.log(`[Relayer] Found ${burnEvents.length} new burn event(s)`);
    }
    for (const event of burnEvents) {
      await executor.handleBurnEvent(event);
    }
  } catch (err) {
    console.error("[Relayer] Error processing burn events:", err);
  }
}

async function main(): Promise<void> {
  console.log("=== ChainBridge Relayer Starting ===");
  console.log(`Sepolia RPC:       ${config.sepolia.rpcUrl}`);
  console.log(`Hoodi RPC:         ${config.hoodi.rpcUrl}`);
  console.log(`Sepolia Vault:     ${config.sepolia.vaultAddress}`);
  console.log(`Sepolia Router:    ${config.sepolia.routerAddress}`);
  console.log(`Hoodi Router:      ${config.hoodi.routerAddress}`);
  console.log(`Hoodi WrappedToken:${config.hoodi.wrappedTokenAddress}`);
  console.log(`Poll Interval:     ${config.pollIntervalMs}ms`);
  console.log(`Min Confirmations: ${config.minConfirmations}`);
  console.log("====================================\n");

  // eslint-disable-next-line no-constant-condition
  while (true) {
    console.log(`[Relayer] Polling at ${new Date().toISOString()}...`);

    await processLockEvents();
    await processBurnEvents();

    await sleep(config.pollIntervalMs);
  }
}

main().catch((err) => {
  console.error("[Relayer] Fatal error:", err);
  process.exit(1);
});
