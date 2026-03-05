import { encodeAbiParameters, keccak256 } from "viem";

/**
 * Compute the txId exactly as the Solidity contracts do:
 * keccak256(abi.encodePacked(sender, recipient, amount, nonce, chainId, dstChainId))
 */
export function computeTxId(
  sender: `0x${string}`,
  recipient: `0x${string}`,
  amount: bigint,
  nonce: bigint,
  chainId: bigint,
  dstChainId: bigint
): `0x${string}` {
  const encoded = encodeAbiParameters(
    [
      { type: "address" },
      { type: "address" },
      { type: "uint256" },
      { type: "uint256" },
      { type: "uint256" },
      { type: "uint256" },
    ],
    [sender, recipient, amount, nonce, chainId, dstChainId]
  );
  return keccak256(encoded);
}

export function formatAmount(amount: bigint, decimals = 18): string {
  const divisor = BigInt(10 ** decimals);
  const whole = amount / divisor;
  const fraction = amount % divisor;
  const fractionStr = fraction.toString().padStart(decimals, "0").slice(0, 4);
  return `${whole}.${fractionStr}`;
}

export function parseAmount(value: string, decimals = 18): bigint {
  const [whole, fraction = ""] = value.split(".");
  const paddedFraction = fraction.padEnd(decimals, "0").slice(0, decimals);
  return BigInt(whole || "0") * BigInt(10 ** decimals) + BigInt(paddedFraction || "0");
}

export function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function explorerTxUrl(baseUrl: string, txHash: string): string {
  return `${baseUrl}/tx/${txHash}`;
}
