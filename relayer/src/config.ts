import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.resolve(__dirname, "../.env") });

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function optionalEnv(name: string, defaultValue: string): string {
  return process.env[name] ?? defaultValue;
}

export interface ChainConfig {
  rpcUrl: string;
  chainId: number;
  startBlock: number;
}

export interface Config {
  sepolia: ChainConfig & {
    vaultAddress: string;
    routerAddress: string;
    originTokenAddress: string;
  };
  hoodi: ChainConfig & {
    routerAddress: string;
    wrappedTokenAddress: string;
  };
  relayerPrivateKey: string;
  pollIntervalMs: number;
  minConfirmations: number;
}

const config: Config = {
  sepolia: {
    rpcUrl: requireEnv("SEPOLIA_RPC_URL"),
    chainId: 11155111,
    vaultAddress: requireEnv("SEPOLIA_VAULT_ADDRESS"),
    routerAddress: requireEnv("SEPOLIA_ROUTER_ADDRESS"),
    originTokenAddress: requireEnv("SEPOLIA_ORIGIN_TOKEN_ADDRESS"),
    startBlock: parseInt(optionalEnv("SEPOLIA_START_BLOCK", "0"), 10),
  },
  hoodi: {
    rpcUrl: requireEnv("HOODI_RPC_URL"),
    chainId: 17000,
    routerAddress: requireEnv("HOODI_ROUTER_ADDRESS"),
    wrappedTokenAddress: requireEnv("HOODI_WRAPPED_TOKEN_ADDRESS"),
    startBlock: parseInt(optionalEnv("HOODI_START_BLOCK", "0"), 10),
  },
  relayerPrivateKey: requireEnv("RELAYER_PRIVATE_KEY"),
  pollIntervalMs: parseInt(optionalEnv("POLL_INTERVAL_MS", "15000"), 10),
  minConfirmations: parseInt(optionalEnv("MIN_CONFIRMATIONS", "2"), 10),
};

export default config;
