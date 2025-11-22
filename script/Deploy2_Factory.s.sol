// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AquaFundFactory} from "../src/AquaFundFactory.sol";

/**
 * @title Deploy2_Factory
 * @dev Step 2: Deploy AquaFundFactory
 * @notice Requires: IMPLEMENTATION address from Step 1
 */
contract Deploy2_Factory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get implementation address from environment (set after Step 1)
        address implementation = vm.envAddress("IMPLEMENTATION");
        address treasury = vm.envOr("TREASURY", deployer);
        uint256 serviceFee = vm.envOr("SERVICE_FEE", uint256(1000));

        console.log("Step 2: Deploying AquaFundFactory...");
        console.log("Deployer:", deployer);
        console.log("Implementation:", implementation);
        console.log("Treasury:", treasury);
        console.log("Service Fee:", serviceFee);

        vm.startBroadcast(deployerPrivateKey);
        
        AquaFundFactory factory = new AquaFundFactory(
            implementation,
            treasury,
            serviceFee
        );
        
        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("Factory:", address(factory));
        console.log("\nSave this address and use it in the next deployment step!");
    }
}

