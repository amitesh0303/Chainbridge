import { useState, useEffect } from "react";
import { useAccount, useChainId, useSwitchChain } from "wagmi";
import { sepolia } from "wagmi/chains";
import { hoodi, EXPLORER_URLS } from "../config";
import { formatAmount, parseAmount, explorerTxUrl } from "../utils/bridge";
import {
  useOriginTokenBalance,
  useWrappedTokenBalance,
  useVaultAllowance,
  useVaultNonce,
  useBurnNonce,
  useIsProcessedOnHoodi,
  useIsProcessedOnSepolia,
  useApproveToken,
  useLockTokens,
  useBurnForBridge,
  useTxIdComputed,
  type BridgeDirection,
} from "../hooks/useBridge";

type BridgeStep =
  | "idle"
  | "approving"
  | "approved"
  | "locking"
  | "locked"
  | "burning"
  | "burned"
  | "waiting_relay"
  | "success"
  | "error";

export function BridgeWidget() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();

  const [direction, setDirection] = useState<BridgeDirection>("AtoB");
  const [amountInput, setAmountInput] = useState("");
  const [customRecipient, setCustomRecipient] = useState(false);
  const [recipientInput, setRecipientInput] = useState("");
  const [step, setStep] = useState<BridgeStep>("idle");
  const [errorMsg, setErrorMsg] = useState<string>("");
  const [originTxHash, setOriginTxHash] = useState<string>("");
  const [pendingTxId, setPendingTxId] = useState<`0x${string}` | undefined>(undefined);

  const isAtoB = direction === "AtoB";
  const requiredChainId = isAtoB ? sepolia.id : hoodi.id;
  const isWrongNetwork = isConnected && chainId !== requiredChainId;

  const recipient = (customRecipient && recipientInput
    ? recipientInput
    : address) as `0x${string}` | undefined;

  // Balances
  const { data: originBalance, refetch: refetchOrigin } = useOriginTokenBalance(address);
  const { data: wrappedBalance, refetch: refetchWrapped } = useWrappedTokenBalance(address);

  // Nonces for txId computation
  const { data: vaultNonce } = useVaultNonce(address);
  const { data: burnNonce } = useBurnNonce(address);

  // Allowance
  const { data: allowance, refetch: refetchAllowance } = useVaultAllowance(address);

  // Parse amount
  const parsedAmount = amountInput ? parseAmount(amountInput) : 0n;

  // Compute the expected txId to poll relay status
  const nonce = isAtoB ? vaultNonce : burnNonce;
  const computedTxId = useTxIdComputed(direction, address, recipient, parsedAmount, nonce);

  // Relay status polling
  const { data: processedOnHoodi } = useIsProcessedOnHoodi(
    step === "waiting_relay" && isAtoB ? pendingTxId : undefined
  );
  const { data: processedOnSepolia } = useIsProcessedOnSepolia(
    step === "waiting_relay" && !isAtoB ? pendingTxId : undefined
  );

  // Watch relay completion
  useEffect(() => {
    if (step === "waiting_relay") {
      if (isAtoB && processedOnHoodi) {
        setStep("success");
        refetchWrapped();
      } else if (!isAtoB && processedOnSepolia) {
        setStep("success");
        refetchOrigin();
      }
    }
  }, [step, isAtoB, processedOnHoodi, processedOnSepolia, refetchWrapped, refetchOrigin]);

  const { approve, isPending: isApproving } = useApproveToken();
  const { lockTokens, isPending: isLocking } = useLockTokens();
  const { burnForBridge, isPending: isBurning } = useBurnForBridge();

  function resetForm() {
    setStep("idle");
    setAmountInput("");
    setErrorMsg("");
    setOriginTxHash("");
    setPendingTxId(undefined);
  }

  async function handleApprove() {
    setErrorMsg("");
    setStep("approving");
    try {
      await approve(parsedAmount);
      await refetchAllowance();
      setStep("approved");
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Approve failed";
      setErrorMsg(msg);
      setStep("error");
    }
  }

  async function handleLock() {
    setErrorMsg("");
    setStep("locking");
    try {
      const txId = computedTxId;
      const txHash = await lockTokens(parsedAmount, recipient!, BigInt(hoodi.id));
      setOriginTxHash(txHash);
      setPendingTxId(txId);
      setStep("waiting_relay");
      refetchOrigin();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Lock failed";
      setErrorMsg(msg);
      setStep("error");
    }
  }

  async function handleBurn() {
    setErrorMsg("");
    setStep("burning");
    try {
      const txId = computedTxId;
      const txHash = await burnForBridge(parsedAmount, recipient!, BigInt(sepolia.id));
      setOriginTxHash(txHash);
      setPendingTxId(txId);
      setStep("waiting_relay");
      refetchWrapped();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Burn failed";
      setErrorMsg(msg);
      setStep("error");
    }
  }

  const needsApproval =
    isAtoB && parsedAmount > 0n && allowance !== undefined && allowance < parsedAmount;

  const sourceBalance = isAtoB ? originBalance : wrappedBalance;
  const sourceBalanceStr = sourceBalance !== undefined ? formatAmount(sourceBalance) : "...";
  const destBalance = isAtoB ? wrappedBalance : originBalance;
  const destBalanceStr = destBalance !== undefined ? formatAmount(destBalance) : "...";

  const sourceExplorer = isAtoB ? EXPLORER_URLS.sepolia : EXPLORER_URLS.hoodi;
  const destExplorer = isAtoB ? EXPLORER_URLS.hoodi : EXPLORER_URLS.sepolia;

  if (!isConnected) {
    return (
      <div className="bridge-card">
        <p className="connect-prompt">Connect your wallet to use ChainBridge</p>
      </div>
    );
  }

  return (
    <div className="bridge-card">
      {/* Direction selector */}
      <div className="direction-selector">
        <button
          className={`dir-btn${isAtoB ? " active" : ""}`}
          onClick={() => { setDirection("AtoB"); resetForm(); }}
        >
          Sepolia → Hoodi
        </button>
        <button
          className={`dir-btn${!isAtoB ? " active" : ""}`}
          onClick={() => { setDirection("BtoA"); resetForm(); }}
        >
          Hoodi → Sepolia
        </button>
      </div>

      {/* Network guard */}
      {isWrongNetwork && (
        <div className="alert alert-warn">
          <span>
            Wrong network. Please switch to {isAtoB ? "Sepolia" : "Hoodi"}.
          </span>
          <button
            className="switch-btn"
            onClick={() => switchChain({ chainId: requiredChainId })}
          >
            Switch Network
          </button>
        </div>
      )}

      {/* Balances */}
      <div className="balances">
        <div>
          <span className="label">Source ({isAtoB ? "Sepolia BTK" : "Hoodi wBTK"})</span>
          <span className="value">{sourceBalanceStr}</span>
        </div>
        <div>
          <span className="label">Destination ({isAtoB ? "Hoodi wBTK" : "Sepolia BTK"})</span>
          <span className="value">{destBalanceStr}</span>
        </div>
      </div>

      {/* Amount input */}
      <div className="input-group">
        <label>Amount</label>
        <div className="amount-row">
          <input
            type="number"
            min="0"
            step="any"
            placeholder="0.0"
            value={amountInput}
            onChange={(e) => setAmountInput(e.target.value)}
            disabled={step !== "idle" && step !== "approved"}
          />
          <button
            className="max-btn"
            onClick={() =>
              setAmountInput(sourceBalance !== undefined ? formatAmount(sourceBalance) : "0")
            }
          >
            MAX
          </button>
        </div>
      </div>

      {/* Recipient */}
      <div className="input-group">
        <label>
          <input
            type="checkbox"
            checked={customRecipient}
            onChange={(e) => setCustomRecipient(e.target.checked)}
          />{" "}
          Send to a different address
        </label>
        {customRecipient && (
          <input
            type="text"
            placeholder="0x..."
            value={recipientInput}
            onChange={(e) => setRecipientInput(e.target.value)}
          />
        )}
        {!customRecipient && address && (
          <p className="hint">Recipient: {address} (your connected address on destination)</p>
        )}
      </div>

      {/* Action buttons */}
      {step === "idle" && isAtoB && needsApproval && (
        <button
          className="action-btn"
          onClick={handleApprove}
          disabled={isApproving || isWrongNetwork || parsedAmount === 0n}
        >
          {isApproving ? "Approving…" : "Step 1: Approve BTK"}
        </button>
      )}

      {(step === "idle" || step === "approved") && isAtoB && !needsApproval && (
        <button
          className="action-btn primary"
          onClick={handleLock}
          disabled={isLocking || isWrongNetwork || parsedAmount === 0n || !recipient}
        >
          {isLocking ? "Locking…" : "Bridge Tokens (Lock)"}
        </button>
      )}

      {step === "approved" && isAtoB && (
        <button
          className="action-btn primary"
          onClick={handleLock}
          disabled={isLocking || isWrongNetwork || parsedAmount === 0n || !recipient}
        >
          {isLocking ? "Locking…" : "Step 2: Lock Tokens"}
        </button>
      )}

      {step === "idle" && !isAtoB && (
        <button
          className="action-btn primary"
          onClick={handleBurn}
          disabled={isBurning || isWrongNetwork || parsedAmount === 0n || !recipient}
        >
          {isBurning ? "Burning…" : "Bridge Back (Burn wBTK)"}
        </button>
      )}

      {/* Status area */}
      {step === "waiting_relay" && (
        <div className="status-box waiting">
          <p>⏳ Waiting for relayer to confirm on {isAtoB ? "Hoodi" : "Sepolia"}…</p>
          {originTxHash && (
            <a
              href={explorerTxUrl(sourceExplorer, originTxHash)}
              target="_blank"
              rel="noopener noreferrer"
            >
              View origin tx on {isAtoB ? "Etherscan" : "Hoodi Explorer"} ↗
            </a>
          )}
          {pendingTxId && <p className="txid-hint">txId: {pendingTxId}</p>}
        </div>
      )}

      {step === "success" && (
        <div className="status-box success">
          <p>✅ Bridge complete!</p>
          {originTxHash && (
            <a
              href={explorerTxUrl(sourceExplorer, originTxHash)}
              target="_blank"
              rel="noopener noreferrer"
            >
              View origin tx ↗
            </a>
          )}
          <p>
            Check your balance on{" "}
            <a href={destExplorer} target="_blank" rel="noopener noreferrer">
              {isAtoB ? "Hoodi Explorer" : "Etherscan"} ↗
            </a>
          </p>
          <button className="reset-btn" onClick={resetForm}>
            Bridge More
          </button>
        </div>
      )}

      {step === "error" && (
        <div className="status-box error">
          <p>❌ Error: {errorMsg}</p>
          <button className="reset-btn" onClick={resetForm}>
            Try Again
          </button>
        </div>
      )}
    </div>
  );
}
