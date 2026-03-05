/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_WALLETCONNECT_PROJECT_ID: string;
  readonly VITE_SEPOLIA_VAULT_ADDRESS: string;
  readonly VITE_SEPOLIA_ROUTER_ADDRESS: string;
  readonly VITE_SEPOLIA_TOKEN_ADDRESS: string;
  readonly VITE_HOODI_ROUTER_ADDRESS: string;
  readonly VITE_HOODI_WRAPPED_TOKEN_ADDRESS: string;
  readonly VITE_SEPOLIA_RPC_URL: string;
  readonly VITE_HOODI_RPC_URL: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
