import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { sepolia } from "wagmi/chains";
import { hoodi, CONTRACT_ADDRESSES } from "../config";
import { BRIDGE_VAULT_ABI, WRAPPED_TOKEN_ABI, ERC20_ABI, BRIDGE_ROUTER_ABI } from "../abis";
import { computeTxId } from "../utils/bridge";

export type BridgeDirection = "AtoB" | "BtoA";

/**
 * Read origin token balance on Sepolia
 */
export function useOriginTokenBalance(address?: `0x${string}`) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.sepolia.token,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
    chainId: sepolia.id,
  });
}

/**
 * Read wrapped token balance on Hoodi
 */
export function useWrappedTokenBalance(address?: `0x${string}`) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.hoodi.wrappedToken,
    abi: WRAPPED_TOKEN_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
    chainId: hoodi.id,
  });
}

/**
 * Read ERC20 allowance for BridgeVault
 */
export function useVaultAllowance(owner?: `0x${string}`) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.sepolia.token,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: owner ? [owner, CONTRACT_ADDRESSES.sepolia.vault] : undefined,
    query: { enabled: !!owner },
    chainId: sepolia.id,
  });
}

/**
 * Read vault nonce for computing txId
 */
export function useVaultNonce(address?: `0x${string}`) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.sepolia.vault,
    abi: BRIDGE_VAULT_ABI,
    functionName: "nonces",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
    chainId: sepolia.id,
  });
}

/**
 * Read burn nonce for computing txId on Hoodi
 */
export function useBurnNonce(address?: `0x${string}`) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.hoodi.wrappedToken,
    abi: WRAPPED_TOKEN_ABI,
    functionName: "burnNonces",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
    chainId: hoodi.id,
  });
}

/**
 * Poll whether a txId has been processed on the destination router
 */
export function useIsProcessedOnHoodi(txId?: `0x${string}`) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.hoodi.router,
    abi: BRIDGE_ROUTER_ABI,
    functionName: "processed",
    args: txId ? [txId] : undefined,
    query: {
      enabled: !!txId,
      refetchInterval: 10_000,
    },
    chainId: hoodi.id,
  });
}

/**
 * Poll whether a txId has been processed on the origin router
 */
export function useIsProcessedOnSepolia(txId?: `0x${string}`) {
  return useReadContract({
    address: CONTRACT_ADDRESSES.sepolia.router,
    abi: BRIDGE_ROUTER_ABI,
    functionName: "processed",
    args: txId ? [txId] : undefined,
    query: {
      enabled: !!txId,
      refetchInterval: 10_000,
    },
    chainId: sepolia.id,
  });
}

export function useApproveToken() {
  const { writeContractAsync, data: txHash, isPending, isError, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const approve = async (amount: bigint) => {
    return writeContractAsync({
      address: CONTRACT_ADDRESSES.sepolia.token,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [CONTRACT_ADDRESSES.sepolia.vault, amount],
      chainId: sepolia.id,
    });
  };

  return { approve, txHash, isPending, isConfirming, isSuccess, isError, error };
}

export function useLockTokens() {
  const { writeContractAsync, data: txHash, isPending, isError, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const lockTokens = async (amount: bigint, recipient: `0x${string}`, dstChainId: bigint) => {
    return writeContractAsync({
      address: CONTRACT_ADDRESSES.sepolia.vault,
      abi: BRIDGE_VAULT_ABI,
      functionName: "lockTokens",
      args: [amount, recipient, dstChainId],
      chainId: sepolia.id,
    });
  };

  return { lockTokens, txHash, isPending, isConfirming, isSuccess, isError, error };
}

export function useBurnForBridge() {
  const { writeContractAsync, data: txHash, isPending, isError, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const burnForBridge = async (amount: bigint, recipient: `0x${string}`, dstChainId: bigint) => {
    return writeContractAsync({
      address: CONTRACT_ADDRESSES.hoodi.wrappedToken,
      abi: WRAPPED_TOKEN_ABI,
      functionName: "burnForBridge",
      args: [amount, recipient, dstChainId],
      chainId: hoodi.id,
    });
  };

  return { burnForBridge, txHash, isPending, isConfirming, isSuccess, isError, error };
}

/**
 * Helper to compute txId on the frontend matching Solidity logic
 */
export function useTxIdComputed(
  direction: BridgeDirection,
  sender?: `0x${string}`,
  recipient?: `0x${string}`,
  amount?: bigint,
  nonce?: bigint
): `0x${string}` | undefined {
  if (!sender || !recipient || amount === undefined || nonce === undefined) return undefined;

  if (direction === "AtoB") {
    return computeTxId(
      sender,
      recipient,
      amount,
      nonce,
      BigInt(sepolia.id),
      BigInt(hoodi.id)
    );
  } else {
    return computeTxId(
      sender,
      recipient,
      amount,
      nonce,
      BigInt(hoodi.id),
      BigInt(sepolia.id)
    );
  }
}
