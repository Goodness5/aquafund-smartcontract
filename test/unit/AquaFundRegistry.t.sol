// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AquaFundRegistry} from "../../src/AquaFundRegistry.sol";
import {AquaFundFactory} from "../../src/AquaFundFactory.sol";
import {AquaFundProject} from "../../src/AquaFundProject.sol";
import {IAquaFundProject} from "../../src/interfaces/IAquaFundProject.sol";
import "forge-std/console.sol";

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

        // Grant admin role to the test contract so it can call setFactory
        vm.startPrank(address(this));
        registry.grantRole(registry.DEFAULT_ADMIN_ROLE(), address(this));
        vm.stopPrank();

        // Correct registration order for registry/factory wiring:
        registry.setFactory(address(factory));
        factory.setRegistry(address(registry));

        vm.prank(admin);
        factory.grantRole(factory.PROJECT_CREATOR_ROLE(), admin);
    }

    function test_RegisterProject() public {
        vm.prank(admin);
        factory.createProject(
            projectAdmin,           // admin
            admin,                 // creator
            10 ether,              // fundingGoal
            "Test Project",        // title
            "Test Description",    // description
            new string[](0),       // images
            "Test Location",       // location
            "Test Category"        // category
        );

        AquaFundRegistry.PlatformStats memory stats = registry.getPlatformStats();
        assertEq(stats.totalProjects, 1);
    }

    function test_GetPlatformStats() public {
        vm.prank(admin);
        address project1Addr = factory.createProject(
            projectAdmin, admin, 10 ether, "Project 1", "Description 1", new string[](0), "Location 1", "Category 1"
        );
        vm.prank(admin);
        address project2Addr = factory.createProject(
            projectAdmin, admin, 20 ether, "Project 2", "Description 2", new string[](0), "Location 2", "Category 2"
        );
        AquaFundProject project1 = AquaFundProject(payable(project1Addr));
        AquaFundProject project2 = AquaFundProject(payable(project2Addr));
        vm.deal(donor, 100 ether);
        vm.prank(donor);
        project1.donate{value: 10 ether}();
        vm.prank(donor);
        project2.donate{value: 20 ether}();
        AquaFundRegistry.PlatformStats memory stats = registry.getPlatformStats();
        // Debug: log registry projects and addresses
        uint256[] memory ids = registry.getAllProjectIds();
        console.logUint(ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            console.logUint(ids[i]);
            console.logAddress(factory.getProjectAddress(ids[i]));
        }
        console.logUint(stats.totalProjects);
        console.logUint(factory.getTotalProjects());
        assertEq(stats.totalFundsRaised, 30 ether);
        console.log("total donors:::",stats.totalDonors);
        assertEq(stats.totalDonors, 2);
    }

    function test_GetProjectsByStatus() public {
        vm.prank(admin);
        factory.createProject(
            projectAdmin, admin, 10 ether, "Project 1", "Description 1", new string[](0), "Location 1", "Category 1"
        );

        vm.prank(admin);
        factory.createProject(
            projectAdmin, admin, 20 ether, "Project 2", "Description 2", new string[](0), "Location 2", "Category 2"
        );

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
            projectAdmin,           // admin
            admin,                 // creator
            10 ether,              // fundingGoal
            "Test Project",        // title
            "Test Description",    // description
            new string[](0),       // images
            "Test Location",       // location
            "Test Category"        // category
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
            factory.createProject(
                projectAdmin, admin, 10 ether, 
                string(abi.encodePacked("Project ", vm.toString(i))),
                "Description", new string[](0), "Location", "Category"
            );
        }

        (uint256[] memory projectIds, address[] memory addresses) = registry.getProjectsPaginated(0, 3);
        

        assertEq(projectIds.length, 3);
        assertEq(addresses.length, 3);
        assertEq(projectIds[0], 1);
        assertEq(projectIds[1], 2);
        assertEq(projectIds[2], 3);
    }
}

