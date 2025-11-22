// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AquaFundBadge} from "../src/AquaFundBadge.sol";

/**
 * @title Deploy3_Badge
 * @dev Step 3: Deploy AquaFundBadge
 * @notice Requires: FACTORY address from Step 2
 */
contract Deploy3_Badge is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factory = vm.envAddress("FACTORY");

        console.log("Step 3: Deploying AquaFundBadge...");
        console.log("Factory (minter):", factory);

        vm.startBroadcast(deployerPrivateKey);
        
        AquaFundBadge badge = new AquaFundBadge(
            "AquaFund Badge",
            "AFB",
            "https://api.aquafund.io/badges/",
            factory
        );
        
        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("Badge:", address(badge));
        console.log("\nSave this address and use it in the next deployment step!");
    }
}

