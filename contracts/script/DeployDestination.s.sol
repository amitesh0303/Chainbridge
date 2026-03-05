// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/WrappedToken.sol";
import "../src/BridgeRouter.sol";

/// @notice Deploy destination-chain contracts (Hoodi)
/// Usage:
///   forge script script/DeployDestination.s.sol --rpc-url $HOODI_RPC_URL \
///     --broadcast --private-key $DEPLOYER_PRIVATE_KEY --verify
contract DeployDestination is Script {
    function run() external {
        address relayerAddress = vm.envAddress("RELAYER_ADDRESS");

        vm.startBroadcast();

        // Deploy destination router
        BridgeRouter destRouter = new BridgeRouter(relayerAddress);
        console.log("DestRouter deployed at:", address(destRouter));

        // Deploy wrapped token (router as the initial controller)
        WrappedToken wrappedToken = new WrappedToken(
            "Wrapped Bridge Token",
            "wBTK",
            address(destRouter)
        );
        console.log("WrappedToken deployed at:", address(wrappedToken));

        // Wire up: router -> wrappedToken
        destRouter.setWrappedToken(address(wrappedToken));
        console.log("WrappedToken wired to DestRouter");

        vm.stopBroadcast();

        console.log("\n=== Destination Chain (Hoodi) Deployment ===");
        console.log("WrappedToken: ", address(wrappedToken));
        console.log("DestRouter:   ", address(destRouter));
        console.log("Relayer:      ", relayerAddress);
    }
}
