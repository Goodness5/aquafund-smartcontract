// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AquaFundRegistry} from "../src/AquaFundRegistry.sol";

/**
 * @title Deploy4_Registry
 * @dev Step 4: Deploy AquaFundRegistry
 */
contract Deploy4_Registry is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Step 4: Deploying AquaFundRegistry...");

        vm.startBroadcast(deployerPrivateKey);
        
        AquaFundRegistry registry = new AquaFundRegistry();
        
        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("Registry:", address(registry));
        console.log("\nSave this address for the configuration step!");
    }
}

