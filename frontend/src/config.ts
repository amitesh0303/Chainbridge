import { http } from "wagmi";
import { sepolia } from "wagmi/chains";
import { defineChain } from "viem";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";

// Hoodi testnet custom chain definition
export const hoodi = defineChain({
  id: 17000,
  name: "Hoodi",
  nativeCurrency: {
    name: "Hoodi Ether",
    symbol: "ETH",
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: [import.meta.env.VITE_HOODI_RPC_URL || "https://rpc.hoodi.ethpandaops.io"],
    },
    public: {
      http: ["https://rpc.hoodi.ethpandaops.io"],
    },
  },
  blockExplorers: {
    default: {
      name: "Hoodi Explorer",
      url: "https://explorer.hoodi.ethpandaops.io",
    },
  },
  testnet: true,
});

export const wagmiConfig = getDefaultConfig({
  appName: "ChainBridge",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "chainbridge-demo",
  chains: [sepolia, hoodi],
  transports: {
    [sepolia.id]: http(import.meta.env.VITE_SEPOLIA_RPC_URL || "https://rpc.sepolia.org"),
    [hoodi.id]: http(import.meta.env.VITE_HOODI_RPC_URL || "https://rpc.hoodi.ethpandaops.io"),
  },
  ssr: false,
});

// Contract addresses from environment
export const CONTRACT_ADDRESSES = {
  sepolia: {
    vault: import.meta.env.VITE_SEPOLIA_VAULT_ADDRESS as `0x${string}`,
    router: import.meta.env.VITE_SEPOLIA_ROUTER_ADDRESS as `0x${string}`,
    token: import.meta.env.VITE_SEPOLIA_TOKEN_ADDRESS as `0x${string}`,
  },
  hoodi: {
    router: import.meta.env.VITE_HOODI_ROUTER_ADDRESS as `0x${string}`,
    wrappedToken: import.meta.env.VITE_HOODI_WRAPPED_TOKEN_ADDRESS as `0x${string}`,
  },
};

export const EXPLORER_URLS = {
  sepolia: "https://sepolia.etherscan.io",
  hoodi: "https://explorer.hoodi.ethpandaops.io",
};
