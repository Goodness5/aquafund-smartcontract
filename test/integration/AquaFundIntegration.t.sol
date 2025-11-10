// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AquaFundProject} from "../../src/AquaFundProject.sol";
import {AquaFundFactory} from "../../src/AquaFundFactory.sol";
import {AquaFundBadge} from "../../src/AquaFundBadge.sol";
import {AquaFundRegistry} from "../../src/AquaFundRegistry.sol";
import {IAquaFundProject} from "../../src/interfaces/IAquaFundProject.sol";
import {MockERC20} from "../unit/AquaFundProject.t.sol";
import "forge-std/console.sol";

/**
 * @title AquaFundIntegrationTest
 * @dev Integration tests for the complete AquaFund workflow
 */
contract AquaFundIntegrationTest is Test {
    AquaFundFactory public factory;
    AquaFundBadge public badge;
    AquaFundRegistry public registry;
    MockERC20 public usdc;

    // Actors
    address public platformAdmin = address(0x1);
    address public ngoAdmin = address(0x2);
    address public donor1 = address(0x3);
    address public donor2 = address(0x4);
    address public donor3 = address(0x5);
    address public treasury = address(0x6);

    // Project details
    uint256 public constant PROJECT_GOAL = 100 ether;
    bytes32 public constant METADATA_URI = keccak256("water-project-kenya");

    function setUp() public {
        // Deploy contracts
        AquaFundProject implementation = new AquaFundProject();
        
        factory = new AquaFundFactory(
            address(implementation),
            treasury,
            1000 // 10% service fee
        );

        badge = new AquaFundBadge(
            "AquaFund Badge",
            "AFB",
            "https://api.aquafund.io/badges/",
            address(factory)
        );

        registry = new AquaFundRegistry();

        usdc = new MockERC20();

        // Configure system
        factory.setBadgeContract(address(badge));
        factory.setRegistry(address(registry));
        registry.setFactory(address(factory));
        factory.addAllowedToken(address(usdc));

        // Setup roles
        vm.prank(platformAdmin);
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), platformAdmin);

        vm.prank(platformAdmin);
        factory.grantRole(factory.PROJECT_CREATOR_ROLE(), ngoAdmin);

        // Fund donors
        vm.deal(donor1, 200 ether);
        vm.deal(donor2, 200 ether);
        vm.deal(donor3, 200 ether);
        usdc.mint(donor1, 1000000 * 10**18);
        usdc.mint(donor2, 1000000 * 10**18);
    }

    function test_CompleteWorkflow_ETHDonations() public {
        // Step 1: Create project
        vm.prank(ngoAdmin);
        address projectAddr = factory.createProject(
            ngoAdmin,
            PROJECT_GOAL,
            METADATA_URI
        );
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        uint256 projectId = 1;

        assertEq(factory.getTotalProjects(), 1);
        assertEq(factory.isAdmin(ngoAdmin), true);

        // Step 2: Multiple donors contribute
        vm.prank(donor1);
        project.donate{value: 30 ether}();

        vm.prank(donor2);
        project.donate{value: 40 ether}();

        vm.prank(donor3);
        project.donate{value: 30 ether}();

        // Verify donations
        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();
        assertEq(info.fundsRaised, 100 ether);
        assertEq(uint256(info.status), uint256(IAquaFundProject.ProjectStatus.Funded));
        assertEq(project.getDonationCount(), 3);

        // Verify global tracking
        assertEq(factory.getTotalDonated(donor1), 30 ether);
        assertEq(factory.getTotalDonated(donor2), 40 ether);
        assertEq(factory.getTotalDonated(donor3), 30 ether);
        assertEq(factory.totalFundsRaised(), 100 ether);
        assertEq(factory.getTotalDonors(), 3);

        // Step 3: Submit evidence
        bytes32 evidenceHash = keccak256("project-completion-photos");
        vm.prank(ngoAdmin);
        project.submitEvidence(evidenceHash);

        assertEq(project.getEvidenceCount(), 1);

        // Step 4: Release funds
        uint256 ngoBalanceBefore = ngoAdmin.balance;
        uint256 treasuryBalanceBefore = treasury.balance;

        vm.prank(ngoAdmin);
        project.releaseFunds();

        assertEq(ngoAdmin.balance - ngoBalanceBefore, 90 ether); // 90% to NGO
        assertEq(treasury.balance - treasuryBalanceBefore, 10 ether); // 10% service fee
        assertEq(uint256(project.getProjectInfo().status), uint256(IAquaFundProject.ProjectStatus.Completed));

        // Step 5: Mint badges (simulating backend)
        string memory tokenUri1 = "ipfs://QmDonor1Badge";
        string memory tokenUri2 = "ipfs://QmDonor2Badge";
        string memory tokenUri3 = "ipfs://QmDonor3Badge";

        factory.mintBadgeForDonor(donor1, projectId, 30 ether, tokenUri1);
        factory.mintBadgeForDonor(donor2, projectId, 40 ether, tokenUri2);
        factory.mintBadgeForDonor(donor3, projectId, 30 ether, tokenUri3);

        assertEq(badge.balanceOf(donor1), 1);
        assertEq(badge.balanceOf(donor2), 1);
        assertEq(badge.balanceOf(donor3), 1);
    }

    function test_CompleteWorkflow_MixedDonations() public {
        // Create project
        vm.prank(ngoAdmin);
        address projectAddr = factory.createProject(ngoAdmin, PROJECT_GOAL, METADATA_URI);
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        // Donate with ETH
        vm.prank(donor1);
        project.donate{value: 50 ether}();
        // Donate with USDC (make sure MIN_DONATION for project is 1e15)
        uint256 usdcAmount = 1e18; // use 1e18 for 18 decimals, or adjust as needed for config
        vm.prank(donor2);
        usdc.approve(address(project), usdcAmount);
        vm.prank(donor2);
        project.donateToken(address(usdc), usdcAmount);
        // Verify totals
        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();
        assertEq(info.fundsRaised, 50 ether + usdcAmount);
        assertEq(project.getDonationCount(), 2);
    }

    function test_MultipleProjects() public {
        // Create first project
        vm.prank(ngoAdmin);
        address project1Addr = factory.createProject(ngoAdmin, 50 ether, keccak256("project1"));
        AquaFundProject project1 = AquaFundProject(payable(project1Addr));

        // Create second project
        vm.prank(ngoAdmin);
        address project2Addr = factory.createProject(ngoAdmin, 75 ether, keccak256("project2"));
        AquaFundProject project2 = AquaFundProject(payable(project2Addr));

        assertEq(factory.getTotalProjects(), 2);

        // Donate to both projects
        vm.prank(donor1);
        project1.donate{value: 50 ether}();

        vm.prank(donor1);
        project2.donate{value: 75 ether}();

        // Verify donor's total contributions
        assertEq(factory.getTotalDonated(donor1), 125 ether);
        assertEq(factory.totalFundsRaised(), 125 ether);
    }

    function test_LeaderboardAcrossProjects() public {
        // Create two projects
        vm.prank(ngoAdmin);
        address project1Addr = factory.createProject(ngoAdmin, 100 ether, keccak256("p1"));
        
        vm.prank(ngoAdmin);
        address project2Addr = factory.createProject(ngoAdmin, 100 ether, keccak256("p2"));

        AquaFundProject project1 = AquaFundProject(payable(project1Addr));
        AquaFundProject project2 = AquaFundProject(payable(project2Addr));

        // Donor1: 60 ether total (30 + 30)
        vm.prank(donor1);
        project1.donate{value: 30 ether}();

        vm.prank(donor1);
        project2.donate{value: 30 ether}();

        // Donor2: 50 ether total (40 + 10)
        vm.prank(donor2);
        project1.donate{value: 40 ether}();

        vm.prank(donor2);
        project2.donate{value: 10 ether}();

        // Donor3: 20 ether total
        vm.prank(donor3);
        project1.donate{value: 20 ether}();

        // Check leaderboard
        (address[] memory donors, uint256[] memory amounts) = factory.getLeaderboard(0, 3);

        assertEq(donors[0], donor1); // 60 ether
        assertEq(amounts[0], 60 ether);
        assertEq(donors[1], donor2); // 50 ether
        assertEq(amounts[1], 50 ether);
        assertEq(donors[2], donor3); // 20 ether
        assertEq(amounts[2], 20 ether);
    }

    function test_CancelAndRefund() public {
        // Create project
        vm.prank(ngoAdmin);
        address projectAddr = factory.createProject(ngoAdmin, PROJECT_GOAL, METADATA_URI);
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        // Donations
        vm.prank(donor1);
        project.donate{value: 30 ether}();

        vm.prank(donor2);
        project.donate{value: 20 ether}();

        // Cancel project
        vm.prank(ngoAdmin);
        project.updateStatus(IAquaFundProject.ProjectStatus.Cancelled);

        // Refund all
        uint256 donor1BalanceBefore = donor1.balance;
        uint256 donor2BalanceBefore = donor2.balance;

        vm.prank(ngoAdmin);
        project.refundAllDonors();

        assertEq(donor1.balance - donor1BalanceBefore, 30 ether);
        assertEq(donor2.balance - donor2BalanceBefore, 20 ether);
    }

    function test_RegistryIntegration() public {
        // Create projects
        vm.prank(ngoAdmin);
        factory.createProject(ngoAdmin, 50 ether, keccak256("p1"));

        vm.prank(ngoAdmin);
        factory.createProject(ngoAdmin, 75 ether, keccak256("p2"));

        // Check registry stats  
        AquaFundRegistry.PlatformStats memory stats = registry.getPlatformStats();

        assertEq(stats.totalProjects, 2);
        assertEq(stats.activeProjects, 2);
    }

    function test_TokenAllowlist() public {
        MockERC20 maliciousToken = new MockERC20();
        maliciousToken.mint(donor1, 1e18);
        vm.prank(ngoAdmin);
        address projectAddr = factory.createProject(ngoAdmin, PROJECT_GOAL, METADATA_URI);
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        vm.prank(donor1);
        maliciousToken.approve(address(project), 1e18);
        console.logUint(maliciousToken.balanceOf(donor1));
        console.logUint(maliciousToken.allowance(donor1, address(project)));
        factory.grantRole(factory.ADMIN_ROLE(), platformAdmin);
        vm.prank(platformAdmin);
        factory.addAllowedToken(address(maliciousToken));
        console.logUint(maliciousToken.balanceOf(donor1));
        console.logUint(maliciousToken.allowance(donor1, address(project)));
        vm.prank(donor1);
        project.donateToken(address(maliciousToken), 1e18);
        console.logUint(maliciousToken.balanceOf(address(project)));
    }

}

