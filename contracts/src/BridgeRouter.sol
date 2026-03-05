// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IBridgeVault {
    function releaseTokens(bytes32 txId, address recipient, uint256 amount) external;
}

interface IWrappedToken {
    function mint(address to, uint256 amount) external;
}

/// @title BridgeRouter - Trusted relayer entry-point deployed on both chains
/// @notice On origin chain: calls BridgeVault.releaseTokens
///         On destination chain: calls WrappedToken.mint
contract BridgeRouter is Ownable, Pausable {
    address public relayer;
    IBridgeVault public vault;
    IWrappedToken public wrappedToken;

    mapping(bytes32 => bool) public processed;

    event BridgeCompleted(
        bytes32 indexed txId,
        address indexed recipient,
        uint256 amount,
        uint256 srcChainId
    );

    event BridgeReleased(
        bytes32 indexed txId,
        address indexed recipient,
        uint256 amount,
        uint256 srcChainId
    );

    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);
    event VaultUpdated(address indexed oldVault, address indexed newVault);
    event WrappedTokenUpdated(address indexed oldToken, address indexed newToken);

    modifier onlyRelayer() {
        require(msg.sender == relayer, "BridgeRouter: caller is not the relayer");
        _;
    }

    constructor(address _relayer) Ownable(msg.sender) {
        require(_relayer != address(0), "BridgeRouter: zero relayer address");
        relayer = _relayer;
    }

    /// @notice Complete a bridge transfer on the destination chain by minting wrapped tokens
    /// @param txId The unique transaction ID from the origin lock event
    /// @param recipient The recipient address
    /// @param amount The amount to mint
    /// @param srcChainId The source chain ID
    function completeBridge(bytes32 txId, address recipient, uint256 amount, uint256 srcChainId)
        external
        onlyRelayer
        whenNotPaused
    {
        require(!processed[txId], "BridgeRouter: txId already processed");
        require(address(wrappedToken) != address(0), "BridgeRouter: wrapped token not set");
        require(recipient != address(0), "BridgeRouter: zero recipient");
        require(amount > 0, "BridgeRouter: amount must be > 0");

        processed[txId] = true;
        wrappedToken.mint(recipient, amount);

        emit BridgeCompleted(txId, recipient, amount, srcChainId);
    }

    /// @notice Release tokens on the origin chain (called by relayer after burn event)
    /// @param txId The unique transaction ID from the destination burn event
    /// @param recipient The recipient address
    /// @param amount The amount to release
    /// @param srcChainId The source chain ID (destination chain where burn happened)
    function releaseBridge(bytes32 txId, address recipient, uint256 amount, uint256 srcChainId)
        external
        onlyRelayer
        whenNotPaused
    {
        require(!processed[txId], "BridgeRouter: txId already processed");
        require(address(vault) != address(0), "BridgeRouter: vault not set");
        require(recipient != address(0), "BridgeRouter: zero recipient");
        require(amount > 0, "BridgeRouter: amount must be > 0");

        processed[txId] = true;
        vault.releaseTokens(txId, recipient, amount);

        emit BridgeReleased(txId, recipient, amount, srcChainId);
    }

    /// @notice Set the vault address (origin chain only)
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "BridgeRouter: zero vault address");
        emit VaultUpdated(address(vault), _vault);
        vault = IBridgeVault(_vault);
    }

    /// @notice Set the wrapped token address (destination chain only)
    function setWrappedToken(address _wrappedToken) external onlyOwner {
        require(_wrappedToken != address(0), "BridgeRouter: zero wrapped token address");
        emit WrappedTokenUpdated(address(wrappedToken), _wrappedToken);
        wrappedToken = IWrappedToken(_wrappedToken);
    }

    /// @notice Update the relayer address
    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "BridgeRouter: zero relayer address");
        emit RelayerUpdated(relayer, _relayer);
        relayer = _relayer;
    }

    /// @notice Pause router operations
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause router operations
    function unpause() external onlyOwner {
        _unpause();
    }
}
