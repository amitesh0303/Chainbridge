// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BridgeVault.sol";
import "../src/BridgeRouter.sol";
import "../src/MockERC20.sol";

/// @notice Deploy origin-chain contracts (Sepolia)
/// Usage:
///   forge script script/DeployOrigin.s.sol --rpc-url $SEPOLIA_RPC_URL \
///     --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify
contract DeployOrigin is Script {
    function run() external {
        address deployerKey = vm.envAddress("DEPLOYER_ADDRESS");
        address relayerAddress = vm.envAddress("RELAYER_ADDRESS");

        vm.startBroadcast();

        // Deploy the native ERC-20 token
        MockERC20 originToken = new MockERC20(
            "Bridge Token",
            "BTK",
            1_000_000 ether
        );
        console.log("OriginToken deployed at:", address(originToken));

        // Deploy origin router
        BridgeRouter originRouter = new BridgeRouter(relayerAddress);
        console.log("OriginRouter deployed at:", address(originRouter));

        // Deploy vault
        BridgeVault vault = new BridgeVault(address(originToken), address(originRouter));
        console.log("BridgeVault deployed at:", address(vault));

        // Wire up: router -> vault
        originRouter.setVault(address(vault));
        console.log("Vault wired to OriginRouter");

        vm.stopBroadcast();

        console.log("\n=== Origin Chain (Sepolia) Deployment ===");
        console.log("OriginToken:  ", address(originToken));
        console.log("BridgeVault:  ", address(vault));
        console.log("OriginRouter: ", address(originRouter));
        console.log("Relayer:      ", relayerAddress);
        console.log("Deployer:     ", deployerKey);
    }
}
