// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AquaFundFactory} from "../src/AquaFundFactory.sol";
import {AquaFundRegistry} from "../src/AquaFundRegistry.sol";

/**
 * @title Deploy5_Configure
 * @dev Step 5: Configure all contracts
 * @notice Requires: FACTORY, BADGE, and REGISTRY addresses from previous steps
 */
contract Deploy5_Configure is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address factory = vm.envAddress("FACTORY");
        address badge = vm.envAddress("BADGE");
        address registry = vm.envAddress("REGISTRY");

        console.log("Step 5: Configuring contracts...");
        console.log("Factory:", factory);
        console.log("Badge:", badge);
        console.log("Registry:", registry);

        vm.startBroadcast(deployerPrivateKey);
        
        AquaFundFactory factoryContract = AquaFundFactory(payable(factory));
        AquaFundRegistry registryContract = AquaFundRegistry(payable(registry));

        // Set badge contract in factory
        factoryContract.setBadgeContract(badge);
        console.log("Badge contract set in factory");

        // Set registry in factory
        factoryContract.setRegistry(registry);
        console.log("Registry set in factory");

        // Set factory in registry
        registryContract.setFactory(factory);
        console.log("Factory set in registry");
        
        vm.stopBroadcast();

        console.log("\n=== Configuration Complete ===");
        console.log("All contracts are now configured and ready to use!");
    }
}

