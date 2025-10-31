// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AquaFundRegistry} from "../../src/AquaFundRegistry.sol";
import {AquaFundFactory} from "../../src/AquaFundFactory.sol";
import {AquaFundProject} from "../../src/AquaFundProject.sol";
import {IAquaFundProject} from "../../src/interfaces/IAquaFundProject.sol";

contract AquaFundRegistryTest is Test {
    AquaFundRegistry public registry;
    AquaFundFactory public factory;
    AquaFundProject public implementation;

    address public admin = address(0x1);
    address public projectAdmin = address(0x2);
    address public donor = address(0x3);
    address public treasury = address(0x4);

    function setUp() public {
        implementation = new AquaFundProject();
        
        factory = new AquaFundFactory(
            address(implementation),
            treasury,
            1000
        );

        registry = new AquaFundRegistry();
        
        registry.setFactory(address(factory));
        factory.setRegistry(address(registry));

        vm.prank(admin);
        factory.grantRole(factory.PROJECT_CREATOR_ROLE(), admin);
    }

    function test_RegisterProject() public {
        vm.prank(admin);
        factory.createProject(
            projectAdmin,
            10 ether,
            keccak256("metadata")
        );

        AquaFundRegistry.PlatformStats memory stats = registry.getPlatformStats();
        assertEq(stats.totalProjects, 1);
    }

    function test_GetPlatformStats() public {
        vm.prank(admin);
        address project1Addr = factory.createProject(projectAdmin, 10 ether, keccak256("p1"));

        vm.prank(admin);
        address project2Addr = factory.createProject(projectAdmin, 20 ether, keccak256("p2"));

        AquaFundProject project1 = AquaFundProject(payable(project1Addr));
        AquaFundProject project2 = AquaFundProject(payable(project2Addr));

        vm.deal(donor, 100 ether);
        vm.prank(donor);
        project1.donate{value: 10 ether}();

        vm.prank(donor);
        project2.donate{value: 20 ether}();

        AquaFundRegistry.PlatformStats memory stats = registry.getPlatformStats();

        assertEq(stats.totalProjects, 2);
        assertEq(stats.totalFundsRaised, 30 ether);
        assertEq(stats.totalDonors, 1);
    }

    function test_GetProjectsByStatus() public {
        vm.prank(admin);
        factory.createProject(projectAdmin, 10 ether, keccak256("p1"));

        vm.prank(admin);
        factory.createProject(projectAdmin, 20 ether, keccak256("p2"));

        address project1Addr = factory.getProjectAddress(1);
        AquaFundProject project1 = AquaFundProject(payable(project1Addr));

        vm.deal(donor, 100 ether);
        vm.prank(donor);
        project1.donate{value: 10 ether}();

        uint256[] memory activeProjects = registry.getProjectsByStatus(
            IAquaFundProject.ProjectStatus.Active
        );
        assertEq(activeProjects.length, 1); // Only project2 is still active

        uint256[] memory fundedProjects = registry.getProjectsByStatus(
            IAquaFundProject.ProjectStatus.Funded
        );
        assertEq(fundedProjects.length, 1); // project1 is funded
    }

    function test_GetProjectDetails() public {
        vm.prank(admin);
        factory.createProject(
            projectAdmin,
            10 ether,
            keccak256("metadata")
        );

        IAquaFundProject.ProjectInfo memory info = registry.getProjectDetails(1);

        assertEq(info.admin, projectAdmin);
        assertEq(info.fundingGoal, 10 ether);
        assertEq(info.projectId, 1);
    }

    function test_GetProjectsPaginated() public {
        // Create 5 projects
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(admin);
            factory.createProject(projectAdmin, 10 ether, keccak256(abi.encodePacked("p", i)));
        }

        (uint256[] memory projectIds, address[] memory addresses) = registry.getProjectsPaginated(0, 3);

        assertEq(projectIds.length, 3);
        assertEq(addresses.length, 3);
        assertEq(projectIds[0], 1);
        assertEq(projectIds[1], 2);
        assertEq(projectIds[2], 3);
    }
}

