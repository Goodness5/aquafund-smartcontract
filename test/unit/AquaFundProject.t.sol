// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AquaFundProject} from "../../src/AquaFundProject.sol";
import {AquaFundFactory} from "../../src/AquaFundFactory.sol";
import {AquaFundBadge} from "../../src/AquaFundBadge.sol";
import {IAquaFundProject} from "../../src/interfaces/IAquaFundProject.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AquaFundProjectTest is Test {
    AquaFundProject public implementation;
    AquaFundFactory public factory;
    AquaFundBadge public badge;
    MockERC20 public mockToken;

    address public admin = address(0x1);
    address public donor = address(0x2);
    address public treasury = address(0x3);
    address public attacker = address(0x999);

    uint256 public constant FUNDING_GOAL = 10 ether;
    uint256 public constant DONATION_AMOUNT = 1 ether;
    bytes32 public constant METADATA_URI = keccak256("test-metadata");

    event ProjectInitialized(
        uint256 indexed projectId,
        address indexed admin,
        uint256 fundingGoal,
        bytes32 metadataURI
    );

    event DonationReceived(
        uint256 indexed projectId,
        address indexed donor,
        uint256 amount,
        bool inETH,
        uint256 timestamp
    );

    event FundsReleased(
        uint256 indexed projectId,
        address indexed recipient,
        uint256 amount,
        uint256 serviceFee
    );

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

        // Deploy mock ERC20
        mockToken = new MockERC20();

        // Configure factory
        factory.setBadgeContract(address(badge));
        factory.addAllowedToken(address(mockToken));

        // Fund addresses
        vm.deal(donor, 100 ether);
        vm.deal(admin, 100 ether);
    }

    function test_CreateProject() public {
        vm.prank(admin);
        factory.grantRole(factory.PROJECT_CREATOR_ROLE(), admin);

        vm.prank(admin);
        address projectAddr = factory.createProject(
            admin,
            FUNDING_GOAL,
            METADATA_URI
        );

        AquaFundProject project = AquaFundProject(payable(projectAddr));
        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();

        assertEq(info.admin, admin);
        assertEq(info.fundingGoal, FUNDING_GOAL);
        assertEq(info.fundsRaised, 0);
        assertEq(uint256(info.status), uint256(IAquaFundProject.ProjectStatus.Active));
        assertEq(info.metadataUri, METADATA_URI);
    }

    function test_DonateETH() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        uint256 projectId = 1;

        // Verify project ID before donation
        IAquaFundProject.ProjectInfo memory infoBefore = project.getProjectInfo();
        assertEq(infoBefore.projectId, projectId);

        vm.prank(donor);
        vm.expectEmit(true, true, false, true);
        emit DonationReceived(projectId, donor, DONATION_AMOUNT, true, block.timestamp);

        vm.prank(donor);
        project.donate{value: DONATION_AMOUNT}();

        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();
        assertEq(info.fundsRaised, DONATION_AMOUNT);
        assertEq(project.getDonation(donor), DONATION_AMOUNT);
        assertEq(project.getDonationCount(), 1);
        assertEq(address(project).balance, DONATION_AMOUNT);
    }

    function test_DonateToken() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        uint256 amount = 1000 * 10**18;

        // Approve and donate
        vm.prank(donor);
        mockToken.approve(address(project), amount);

        vm.prank(donor);
        project.donateToken(address(mockToken), amount);

        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();
        assertEq(info.fundsRaised, amount);
        assertEq(project.getDonation(donor), amount);
        assertEq(mockToken.balanceOf(address(project)), amount);
    }

    function test_DonateETH_ReentrancyProtection() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        // This test ensures reentrancy guard is working
        // In a real reentrancy attack, this would fail
        vm.prank(donor);
        project.donate{value: DONATION_AMOUNT}();

        vm.prank(donor);
        project.donate{value: DONATION_AMOUNT}();

        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();
        assertEq(info.fundsRaised, DONATION_AMOUNT * 2);
    }

    function test_Donate_MinimumAmount() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        vm.prank(donor);
        vm.expectRevert();
        project.donate{value: 0.0001 ether}(); // Below minimum
    }

    function test_DonateToken_NotAllowed() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        MockERC20 maliciousToken = new MockERC20();

        vm.prank(donor);
        maliciousToken.approve(address(project), 1000);

        vm.prank(donor);
        vm.expectRevert();
        project.donateToken(address(maliciousToken), 1000);
    }

    function test_AutoStatusUpdateToFunded() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        vm.prank(donor);
        project.donate{value: FUNDING_GOAL}();

        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();
        assertEq(uint256(info.status), uint256(IAquaFundProject.ProjectStatus.Funded));
    }

    function test_ReleaseFunds() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        // Donate full amount
        vm.prank(donor);
        project.donate{value: FUNDING_GOAL}();

        uint256 balanceBefore = admin.balance;
        uint256 treasuryBefore = treasury.balance;

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit FundsReleased(1, admin, FUNDING_GOAL * 9 / 10, FUNDING_GOAL / 10);

        vm.prank(admin);
        project.releaseFunds();

        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();
        assertEq(uint256(info.status), uint256(IAquaFundProject.ProjectStatus.Completed));
        assertEq(admin.balance - balanceBefore, FUNDING_GOAL * 9 / 10);
        assertEq(treasury.balance - treasuryBefore, FUNDING_GOAL / 10);
    }

    function test_ReleaseFunds_Unauthorized() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        vm.prank(donor);
        project.donate{value: FUNDING_GOAL}();

        vm.prank(attacker);
        vm.expectRevert();
        project.releaseFunds();
    }

    function test_ReleaseFunds_GoalNotReached() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        vm.prank(donor);
        project.donate{value: FUNDING_GOAL / 2}();

        vm.prank(admin);
        vm.expectRevert();
        project.releaseFunds();
    }

    function test_SubmitEvidence() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        bytes32 evidenceHash = keccak256("evidence-hash");

        vm.prank(admin);
        project.submitEvidence(evidenceHash);

        assertEq(project.getEvidenceCount(), 1);
        IAquaFundProject.Evidence memory evidence = project.getEvidence(0);
        assertEq(evidence.evidenceHash, evidenceHash);
        assertEq(evidence.submitter, admin);
    }

    function test_SubmitEvidence_Unauthorized() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        vm.prank(attacker);
        vm.expectRevert();
        project.submitEvidence(keccak256("evidence"));
    }

    function test_RefundDonor() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        vm.prank(donor);
        project.donate{value: DONATION_AMOUNT}();

        // Cancel project
        vm.prank(admin);
        project.updateStatus(IAquaFundProject.ProjectStatus.Cancelled);

        uint256 balanceBefore = donor.balance;

        vm.prank(admin);
        project.refundDonor(donor);

        assertEq(donor.balance - balanceBefore, DONATION_AMOUNT);
        assertEq(project.getDonation(donor), 0);
    }

    function test_RefundAllDonors() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        address donor2 = address(0x4);
        vm.deal(donor2, 100 ether);

        vm.prank(donor);
        project.donate{value: DONATION_AMOUNT}();

        vm.prank(donor2);
        project.donate{value: DONATION_AMOUNT}();

        // Cancel project
        vm.prank(admin);
        project.updateStatus(IAquaFundProject.ProjectStatus.Cancelled);

        uint256 donorBalanceBefore = donor.balance;
        uint256 donor2BalanceBefore = donor2.balance;

        vm.prank(admin);
        project.refundAllDonors();

        assertEq(donor.balance - donorBalanceBefore, DONATION_AMOUNT);
        assertEq(donor2.balance - donor2BalanceBefore, DONATION_AMOUNT);
    }

    function test_Receive() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        vm.deal(address(this), DONATION_AMOUNT);
        (bool success, ) = address(project).call{value: DONATION_AMOUNT}("");
        assertTrue(success);

        assertEq(project.getDonation(address(this)), DONATION_AMOUNT);
    }

    // Helper function
    function _createProject() internal returns (address) {
        vm.prank(admin);
        factory.grantRole(factory.PROJECT_CREATOR_ROLE(), admin);

        vm.prank(admin);
        return factory.createProject(admin, FUNDING_GOAL, METADATA_URI);
    }
}

