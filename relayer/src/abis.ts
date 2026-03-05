// Minimal ABIs for ChainBridge contracts

export const BRIDGE_VAULT_ABI = [
  // Events
  "event TokensLocked(bytes32 indexed txId, address indexed sender, address indexed recipient, uint256 amount, uint256 nonce, uint256 dstChainId)",
  "event TokensReleased(bytes32 indexed txId, address indexed recipient, uint256 amount)",
  // Functions
  "function releaseTokens(bytes32 txId, address recipient, uint256 amount) external",
  "function processedTxIds(bytes32) external view returns (bool)",
  "function nonces(address) external view returns (uint256)",
] as const;

export const WRAPPED_TOKEN_ABI = [
  // Events
  "event TokensBurned(bytes32 indexed txId, address indexed sender, address indexed recipient, uint256 amount, uint256 nonce, uint256 dstChainId)",
  // Functions
  "function burnNonces(address) external view returns (uint256)",
  "function balanceOf(address) external view returns (uint256)",
] as const;

export const BRIDGE_ROUTER_ABI = [
  // Events
  "event BridgeCompleted(bytes32 indexed txId, address indexed recipient, uint256 amount, uint256 srcChainId)",
  "event BridgeReleased(bytes32 indexed txId, address indexed recipient, uint256 amount, uint256 srcChainId)",
  // Functions
  "function completeBridge(bytes32 txId, address recipient, uint256 amount, uint256 srcChainId) external",
  "function releaseBridge(bytes32 txId, address recipient, uint256 amount, uint256 srcChainId) external",
  "function processed(bytes32) external view returns (bool)",
] as const;
