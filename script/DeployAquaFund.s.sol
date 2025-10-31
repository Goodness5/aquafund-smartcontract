// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AquaFundProject} from "../src/AquaFundProject.sol";
import {AquaFundFactory} from "../src/AquaFundFactory.sol";
import {AquaFundBadge} from "../src/AquaFundBadge.sol";
import {AquaFundRegistry} from "../src/AquaFundRegistry.sol";

/**
 * @title DeployAquaFund
 * @dev Deployment script for AquaFund smart contracts
 * @notice Deploys all contracts in the correct order with proper initialization
 * 
 * Deployment Order:
 * 1. Deploy implementation contract (requires factory address - we'll use a compute trick)
 * 2. Deploy factory contract
 * 3. Deploy badge contract
 * 4. Deploy registry contract
 * 5. Configure all contracts
 */
contract DeployAquaFund is Script {
    // Deployment addresses
    address public implementation;
    address public factory;
    address public badge;
    address public registry;

    // Configuration
    address public treasury;
    uint256 public serviceFee = 1000; // 10% in basis points

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get configuration from environment or use defaults
        treasury = vm.envOr("TREASURY", deployer);
        serviceFee = vm.envOr("SERVICE_FEE", uint256(1000));

        console.log("Deploying AquaFund contracts...");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("Service Fee:", serviceFee, "basis points (10% = 1000)");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts in order
        // Factory address is set during initialization, so no circular dependency issues
        
        console.log("\n1. Deploying AquaFundProject implementation...");
        AquaFundProject implementationContract = new AquaFundProject();
        implementation = address(implementationContract);
        console.log("Implementation deployed at:", implementation);

        console.log("\n2. Deploying AquaFundFactory...");
        AquaFundFactory factoryContract = new AquaFundFactory(
            implementation,
            treasury,
            serviceFee
        );
        factory = address(factoryContract);
        console.log("Factory deployed at:", factory);

        // Step 3: Deploy Badge contract
        console.log("\n3. Deploying AquaFundBadge...");
        AquaFundBadge badgeContract = new AquaFundBadge(
            "AquaFund Badge",
            "AFB",
            "https://api.aquafund.io/badges/", // Base URI for metadata
            factory // Factory is the minter
        );
        badge = address(badgeContract);
        console.log("Badge deployed at:", badge);

        // Step 4: Deploy Registry
        console.log("\n4. Deploying AquaFundRegistry...");
        AquaFundRegistry registryContract = new AquaFundRegistry();
        registry = address(registryContract);
        console.log("Registry deployed at:", registry);

        // Step 5: Configure contracts
        console.log("\n5. Configuring contracts...");

        // Set badge contract in factory
        factoryContract.setBadgeContract(badge);
        console.log("Badge contract set in factory");

        // Set registry in factory
        factoryContract.setRegistry(registry);
        console.log("[OK] Registry set in factory");

        // Set factory in registry
        registryContract.setFactory(factory);
        console.log("[OK] Factory set in registry");

        vm.stopBroadcast();

        // Summary
        console.log("\n=== Deployment Summary ===");
        console.log("Implementation:", implementation);
        console.log("Factory:", factory);
        console.log("Badge:", badge);
        console.log("Registry:", registry);
        console.log("\nNext steps:");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Grant PROJECT_CREATOR_ROLE to verified NGOs");
        console.log("3. Update base URI for badges if needed");
        console.log("4. Test contract interactions");
    }
}
