// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title WrappedToken - Mintable/burnable ERC-20 on the destination chain
/// @notice Minted by the router when bridging in; burned by users to bridge back
contract WrappedToken is ERC20, Ownable, Pausable {
    address public router;

    mapping(address => uint256) public burnNonces;

    event TokensBurned(
        bytes32 indexed txId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 nonce,
        uint256 dstChainId
    );

    event RouterUpdated(address indexed oldRouter, address indexed newRouter);

    modifier onlyRouter() {
        require(msg.sender == router, "WrappedToken: caller is not the router");
        _;
    }

    constructor(string memory name, string memory symbol, address _router)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        router = _router;
    }

    /// @notice Mint wrapped tokens to a recipient (called by router when bridge-in is confirmed)
    /// @param to The recipient address
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) external onlyRouter whenNotPaused {
        require(to != address(0), "WrappedToken: zero address");
        require(amount > 0, "WrappedToken: amount must be > 0");
        _mint(to, amount);
    }

    /// @notice Burn wrapped tokens to initiate a return bridge transfer
    /// @param amount The amount to burn
    /// @param recipient The recipient address on the destination chain
    /// @param dstChainId The destination chain ID
    function burnForBridge(uint256 amount, address recipient, uint256 dstChainId)
        external
        whenNotPaused
    {
        require(amount > 0, "WrappedToken: amount must be > 0");
        require(recipient != address(0), "WrappedToken: zero recipient");
        require(dstChainId != block.chainid, "WrappedToken: same chain");

        uint256 nonce = burnNonces[msg.sender];
        bytes32 txId = keccak256(
            abi.encodePacked(msg.sender, recipient, amount, nonce, block.chainid, dstChainId)
        );

        burnNonces[msg.sender] = nonce + 1;
        _burn(msg.sender, amount);

        emit TokensBurned(txId, msg.sender, recipient, amount, nonce, dstChainId);
    }

    /// @notice Update the router address
    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "WrappedToken: zero router address");
        emit RouterUpdated(router, _router);
        router = _router;
    }

    /// @notice Pause token operations
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause token operations
    function unpause() external onlyOwner {
        _unpause();
    }
}
