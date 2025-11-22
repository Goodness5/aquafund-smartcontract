// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AquaFundProject} from "../src/AquaFundProject.sol";

/**
 * @title Deploy1_Project
 * @dev Step 1: Deploy AquaFundProject IMPLEMENTATION contract
 * @notice This is the TEMPLATE contract that will be cloned by the factory.
 *         Individual projects are created as clones (minimal proxies) of this implementation.
 *         We only deploy this ONCE - the factory will create clones when createProject() is called.
 */
contract Deploy1_Project is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Step 1: Deploying AquaFundProject IMPLEMENTATION (template)...");
        console.log("Deployer:", deployer);
        console.log("Note: This is the template contract. Individual projects will be clones of this.");

        vm.startBroadcast(deployerPrivateKey);
        
        AquaFundProject implementation = new AquaFundProject();
        
        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("Implementation (template):", address(implementation));
        console.log("\nThis address will be used by the factory to create project clones.");
        console.log("Save this address and use it in Step 2 (Factory deployment)!");
    }
}

