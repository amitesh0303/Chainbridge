// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title BridgeVault - Locks ERC-20 tokens on the origin chain
/// @notice Users lock tokens here; the relayer releases them on return
contract BridgeVault is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public router;

    mapping(bytes32 => bool) public processedTxIds;
    mapping(address => uint256) public nonces;

    event TokensLocked(
        bytes32 indexed txId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 nonce,
        uint256 dstChainId
    );

    event TokensReleased(bytes32 indexed txId, address indexed recipient, uint256 amount);

    event RouterUpdated(address indexed oldRouter, address indexed newRouter);

    modifier onlyRouter() {
        require(msg.sender == router, "BridgeVault: caller is not the router");
        _;
    }

    constructor(address _token, address _router) Ownable(msg.sender) {
        require(_token != address(0), "BridgeVault: zero token address");
        token = IERC20(_token);
        router = _router;
    }

    /// @notice Lock tokens on the origin chain to initiate a cross-chain transfer
    /// @param amount The amount of tokens to lock
    /// @param recipient The recipient address on the destination chain
    /// @param dstChainId The destination chain ID
    function lockTokens(uint256 amount, address recipient, uint256 dstChainId)
        external
        whenNotPaused
        nonReentrant
    {
        require(amount > 0, "BridgeVault: amount must be > 0");
        require(recipient != address(0), "BridgeVault: zero recipient");
        require(dstChainId != block.chainid, "BridgeVault: same chain");

        uint256 nonce = nonces[msg.sender];
        bytes32 txId = keccak256(
            abi.encodePacked(msg.sender, recipient, amount, nonce, block.chainid, dstChainId)
        );

        nonces[msg.sender] = nonce + 1;
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit TokensLocked(txId, msg.sender, recipient, amount, nonce, dstChainId);
    }

    /// @notice Release tokens back to a recipient (called by router on return bridge)
    /// @param txId The unique transaction ID from the burn event
    /// @param recipient The address to receive the released tokens
    /// @param amount The amount of tokens to release
    function releaseTokens(bytes32 txId, address recipient, uint256 amount)
        external
        onlyRouter
        whenNotPaused
        nonReentrant
    {
        require(!processedTxIds[txId], "BridgeVault: txId already processed");
        require(recipient != address(0), "BridgeVault: zero recipient");
        require(amount > 0, "BridgeVault: amount must be > 0");

        processedTxIds[txId] = true;
        token.safeTransfer(recipient, amount);

        emit TokensReleased(txId, recipient, amount);
    }

    /// @notice Update the router address
    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "BridgeVault: zero router address");
        emit RouterUpdated(router, _router);
        router = _router;
    }

    /// @notice Pause vault operations
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause vault operations
    function unpause() external onlyOwner {
        _unpause();
    }
}
