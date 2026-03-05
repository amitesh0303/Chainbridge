import { ConnectButton } from "@rainbow-me/rainbowkit";
import { BridgeWidget } from "./BridgeWidget";

export function App() {
  return (
    <div className="app">
      <header className="app-header">
        <div className="header-inner">
          <div className="logo">
            <span className="logo-icon">⛓️</span>
            <span className="logo-text">ChainBridge</span>
          </div>
          <ConnectButton />
        </div>
      </header>

      <main className="app-main">
        <div className="hero">
          <h1>Cross-Chain ERC-20 Bridge</h1>
          <p>Bridge tokens between Sepolia and Hoodi testnets</p>
        </div>
        <BridgeWidget />
        <div className="info-section">
          <h2>How it works</h2>
          <ol>
            <li>
              <strong>Sepolia → Hoodi:</strong> Approve &amp; lock your BTK tokens in the{" "}
              BridgeVault on Sepolia. The relayer detects the lock and mints equivalent wBTK on Hoodi.
            </li>
            <li>
              <strong>Hoodi → Sepolia:</strong> Burn your wBTK on Hoodi. The relayer detects the
              burn and releases your original BTK from the vault on Sepolia.
            </li>
          </ol>
          <p className="disclaimer">
            This bridge uses a trusted-relayer model. It is for testnet use only.
          </p>
        </div>
      </main>

      <footer className="app-footer">
        <p>ChainBridge — Testnet ERC-20 Bridge</p>
      </footer>
    </div>
  );
}
