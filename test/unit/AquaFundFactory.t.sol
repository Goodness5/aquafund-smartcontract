// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AquaFundProject} from "../../src/AquaFundProject.sol";
import {AquaFundFactory} from "../../src/AquaFundFactory.sol";
import {AquaFundBadge} from "../../src/AquaFundBadge.sol";
import {AquaFundRegistry} from "../../src/AquaFundRegistry.sol";
import {MockERC20} from "./AquaFundProject.t.sol";

contract AquaFundFactoryTest is Test {
    AquaFundProject public implementation;
    AquaFundFactory public factory;
    AquaFundBadge public badge;
    AquaFundRegistry public registry;
    MockERC20 public mockToken;

    address public admin = address(0x1);
    address public projectCreator = address(0x2);
    address public donor = address(0x3);
    address public treasury = address(0x4);

    uint256 public constant FUNDING_GOAL = 10 ether;
    bytes32 public constant METADATA_URI = keccak256("test");

    function setUp() public {
        // Deploy implementation
        implementation = new AquaFundProject();

        // Deploy factory
        factory = new AquaFundFactory(
            address(implementation),
            treasury,
            1000 // 10% service fee
        );

        // Deploy badge
        badge = new AquaFundBadge(
            "AquaFund Badge",
            "AFB",
            "https://api.aquafund.io/badges/",
            address(factory)
        );

        // Deploy registry
        registry = new AquaFundRegistry();

        // Deploy mock token
        mockToken = new MockERC20();

        // Configure contracts
        factory.setBadgeContract(address(badge));
        factory.setRegistry(address(registry));
        registry.setFactory(address(factory));

        // Setup roles
        vm.prank(admin);
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), admin);

        vm.prank(admin);
        factory.grantRole(factory.PROJECT_CREATOR_ROLE(), projectCreator);
    }

    function test_CreateProject() public {
        vm.prank(projectCreator);
        address projectAddr = factory.createProject(
            admin,
            FUNDING_GOAL,
            METADATA_URI
        );

        assertTrue(projectAddr != address(0));
        assertEq(factory.getTotalProjects(), 1);
        assertEq(factory.getProjectAddress(1), projectAddr);
    }

    function test_CreateProject_Unauthorized() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        factory.createProject(admin, FUNDING_GOAL, METADATA_URI);
    }

    function test_AddAllowedToken() public {
        factory.grantRole(factory.ADMIN_ROLE(), admin);
        vm.prank(admin);
        factory.addAllowedToken(address(mockToken));
        assertTrue(factory.isTokenAllowed(address(mockToken)));
        assertTrue(factory.isTokenAllowed(address(0)));
    }

    function test_RemoveAllowedToken() public {
        factory.grantRole(factory.ADMIN_ROLE(), admin);
        vm.prank(admin);
        factory.addAllowedToken(address(mockToken));
        vm.prank(admin);
        factory.removeAllowedToken(address(mockToken));
        assertFalse(factory.isTokenAllowed(address(mockToken)));
    }

    function test_RecordDonation() public {
        vm.prank(projectCreator);
        address projectAddr = factory.createProject(admin, FUNDING_GOAL, METADATA_URI);

        AquaFundProject project = AquaFundProject(payable(projectAddr));
        vm.deal(donor, 10 ether);

        vm.prank(donor);
        project.donate{value: 1 ether}();

        assertEq(factory.getTotalDonated(donor), 1 ether);
        assertEq(factory.getTotalDonors(), 1);
        assertEq(factory.totalFundsRaised(), 1 ether);
        assertEq(factory.totalDonationsCount(), 1);
    }

    function test_RecordDonation_Unauthorized() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        factory.recordDonation(donor, 1, 1 ether);
    }

    function test_GetLeaderboard() public {
        vm.prank(projectCreator);
        address projectAddr = factory.createProject(admin, FUNDING_GOAL, METADATA_URI);

        AquaFundProject project = AquaFundProject(payable(projectAddr));
        address donor2 = address(0x6);
        address donor3 = address(0x7);
        
        vm.deal(donor, 10 ether);
        vm.deal(donor2, 10 ether);
        vm.deal(donor3, 10 ether);

        vm.prank(donor);
        project.donate{value: 5 ether}();

        vm.prank(donor2);
        project.donate{value: 3 ether}();

        vm.prank(donor3);
        project.donate{value: 2 ether}();

        (address[] memory donors, uint256[] memory amounts) = factory.getLeaderboard(0, 3);

        assertEq(donors.length, 3);
        assertEq(amounts.length, 3);
        assertEq(donors[0], donor); // Highest donor first
        assertEq(amounts[0], 5 ether);
    }

    function test_GetPlatformStats() public {
        vm.prank(projectCreator);
        address projectAddr = factory.createProject(admin, FUNDING_GOAL, METADATA_URI);

        AquaFundProject project = AquaFundProject(payable(projectAddr));
        vm.deal(donor, 10 ether);

        vm.prank(donor);
        project.donate{value: 1 ether}();

        (
            uint256 totalProjects,
            uint256 totalRaised,
            uint256 totalDonors_,
            uint256 totalDonations
        ) = factory.getPlatformStats();

        assertEq(totalProjects, 1);
        assertEq(totalRaised, 1 ether);
        assertEq(totalDonors_, 1);
        assertEq(totalDonations, 1);
    }

    function test_MintBadgeForDonor() public {
        vm.prank(projectCreator);
        address projectAddr = factory.createProject(admin, FUNDING_GOAL, METADATA_URI);

        AquaFundProject project = AquaFundProject(payable(projectAddr));
        vm.deal(donor, 10 ether);

        vm.prank(donor);
        project.donate{value: 1 ether}();

        string memory tokenUri = "ipfs://QmTestHash";

        factory.mintBadgeForDonor(donor, 1, 1 ether, tokenUri);

        assertEq(badge.balanceOf(donor), 1);
    }

    function test_MintBadgeForDonor_InvalidProject() public {
        vm.expectRevert();
        factory.mintBadgeForDonor(donor, 999, 1 ether, "ipfs://test");
    }

    function test_UpdateServiceFee() public {
        factory.grantRole(factory.ADMIN_ROLE(), admin);
        vm.prank(admin);
        factory.updateServiceFee(1500); // 15%

        assertEq(factory.getServiceFee(), 1500);
    }

    function test_UpdateServiceFee_Unauthorized() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        factory.updateServiceFee(2000);
    }

    function test_UpdateServiceFee_MaxLimit() public {
        vm.prank(admin);
        vm.expectRevert();
        factory.updateServiceFee(6000); // 60% - exceeds max
    }

    function test_UpdateTreasury() public {
        factory.grantRole(factory.ADMIN_ROLE(), admin);
        address newTreasury = address(0x5);
        vm.prank(admin);
        factory.updateTreasury(newTreasury);
        assertEq(factory.getTreasury(), newTreasury);
    }

    function test_PauseUnpause() public {
        factory.grantRole(factory.ADMIN_ROLE(), admin);
        vm.prank(admin);
        factory.pause();
        vm.prank(projectCreator);
        vm.expectRevert();
        factory.createProject(admin, FUNDING_GOAL, METADATA_URI);
        vm.prank(admin);
        factory.unpause();
        vm.prank(projectCreator);
        address projectAddr = factory.createProject(admin, FUNDING_GOAL, METADATA_URI);
        assertTrue(projectAddr != address(0));
    }
}

