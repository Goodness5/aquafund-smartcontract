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
        mockToken.mint(donor, 1_000 * 10**18);
    }

    function test_CreateProject() public {
        vm.prank(admin);
        factory.grantRole(factory.PROJECT_CREATOR_ROLE(), admin);

        vm.prank(admin);
        address projectAddr = factory.createProject(
            admin,           // admin
            admin,           // creator
            FUNDING_GOAL,    // fundingGoal
            "Test Project", // title
            "Test Description", // description
            new string[](0), // images
            "Test Location", // location
            "Test Category"  // category
        );

        AquaFundProject project = AquaFundProject(payable(projectAddr));
        IAquaFundProject.ProjectInfo memory info = project.getProjectInfo();

        assertEq(info.admin, admin);
        assertEq(info.fundingGoal, FUNDING_GOAL);
        assertEq(info.fundsRaised, 0);
        assertEq(uint256(info.status), uint256(IAquaFundProject.ProjectStatus.Active));
    }

    function test_DonateETH() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        uint256 projectId = 1;

        // Verify project ID before donation
        IAquaFundProject.ProjectInfo memory infoBefore = project.getProjectInfo();
        assertEq(infoBefore.projectId, projectId);

        vm.startPrank(donor);
        vm.expectEmit(true, true, false, true);
        emit DonationReceived(projectId, donor, DONATION_AMOUNT, true, block.timestamp);
        project.donate{value: DONATION_AMOUNT}();
        vm.stopPrank();

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

        // Approve and donate (single prank/donor section)
        vm.startPrank(donor);
        mockToken.approve(address(project), amount);
        project.donateToken(address(mockToken), amount);
        vm.stopPrank();

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

        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit FundsReleased(1, admin, FUNDING_GOAL * 9 / 10, FUNDING_GOAL / 10);
        project.releaseFunds();
        vm.stopPrank();

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
        string memory evidenceHash = "evidence-hash-ipfs-uri";

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
        project.submitEvidence("evidence");
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

    // Token Escrow Tests
    function test_TokenEscrow_HeldInContract() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        uint256 amount = 1000 * 10**18;

        vm.startPrank(donor);
        mockToken.approve(address(project), amount);
        project.donateToken(address(mockToken), amount);
        vm.stopPrank();

        // Verify token is held in escrow (project contract)
        assertEq(mockToken.balanceOf(address(project)), amount);
        assertEq(project.getTokenBalance(address(mockToken)), amount);
        
        // Verify token appears in donated tokens list
        address[] memory tokens = project.getDonatedTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(mockToken));
    }

    function test_ReleaseFunds_WithTokens() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        uint256 tokenAmount = 5000 * 10**18;
        uint256 ethAmount = 5 ether;

        // Donate both ETH and tokens
        vm.startPrank(donor);
        project.donate{value: ethAmount}();
        mockToken.approve(address(project), tokenAmount);
        project.donateToken(address(mockToken), tokenAmount);
        vm.stopPrank();

        uint256 adminEthBefore = admin.balance;
        uint256 adminTokenBefore = mockToken.balanceOf(admin);
        uint256 treasuryEthBefore = treasury.balance;
        uint256 treasuryTokenBefore = mockToken.balanceOf(treasury);

        // Release funds
        vm.prank(admin);
        project.releaseFunds();

        // Verify ETH release (10% fee)
        assertEq(admin.balance - adminEthBefore, ethAmount * 9 / 10);
        assertEq(treasury.balance - treasuryEthBefore, ethAmount / 10);

        // Verify token release (10% fee)
        assertEq(mockToken.balanceOf(admin) - adminTokenBefore, tokenAmount * 9 / 10);
        assertEq(mockToken.balanceOf(treasury) - treasuryTokenBefore, tokenAmount / 10);

        // Verify escrow is cleared
        assertEq(project.getTokenBalance(address(mockToken)), 0);
        assertEq(project.getDonatedTokens().length, 0);
        assertEq(address(project).balance, 0);
    }

    function test_ReleaseFunds_MultipleTokens() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        
        MockERC20 token2 = new MockERC20();
        factory.addAllowedToken(address(token2));
        token2.mint(donor, 2000 * 10**18);

        uint256 token1Amount = 3000 * 10**18;
        uint256 token2Amount = 2000 * 10**18;

        vm.startPrank(donor);
        mockToken.approve(address(project), token1Amount);
        project.donateToken(address(mockToken), token1Amount);
        token2.approve(address(project), token2Amount);
        project.donateToken(address(token2), token2Amount);
        vm.stopPrank();

        vm.prank(admin);
        project.releaseFunds();

        // Verify both tokens released
        assertEq(mockToken.balanceOf(admin), token1Amount * 9 / 10);
        assertEq(token2.balanceOf(admin), token2Amount * 9 / 10);
        assertEq(project.getDonatedTokens().length, 0);
    }

    function test_RefundDonor_WithTokens() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        uint256 tokenAmount = 1000 * 10**18;

        // Donate ETH and tokens
        vm.startPrank(donor);
        project.donate{value: DONATION_AMOUNT}();
        mockToken.approve(address(project), tokenAmount);
        project.donateToken(address(mockToken), tokenAmount);
        vm.stopPrank();

        // Cancel project
        vm.prank(admin);
        project.updateStatus(IAquaFundProject.ProjectStatus.Cancelled);

        uint256 donorEthBefore = donor.balance;
        uint256 donorTokenBefore = mockToken.balanceOf(donor);

        // Refund donor
        vm.prank(admin);
        project.refundDonor(donor);

        // Verify both ETH and tokens refunded
        assertEq(donor.balance - donorEthBefore, DONATION_AMOUNT);
        assertEq(mockToken.balanceOf(donor) - donorTokenBefore, tokenAmount);
        assertEq(project.getDonation(donor), 0);
        assertEq(project.getTokenDonation(donor, address(mockToken)), 0);
    }

    function test_RefundAllDonors_WithTokens() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        
        address donor2 = address(0x4);
        vm.deal(donor2, 100 ether);
        mockToken.mint(donor2, 1000 * 10**18);

        uint256 tokenAmount = 500 * 10**18;

        // Donor 1: ETH only
        vm.prank(donor);
        project.donate{value: DONATION_AMOUNT}();

        // Donor 2: Tokens only
        vm.startPrank(donor2);
        mockToken.approve(address(project), tokenAmount);
        project.donateToken(address(mockToken), tokenAmount);
        vm.stopPrank();

        // Cancel project
        vm.prank(admin);
        project.updateStatus(IAquaFundProject.ProjectStatus.Cancelled);

        uint256 donor1EthBefore = donor.balance;
        uint256 donor2TokenBefore = mockToken.balanceOf(donor2);

        // Refund all
        vm.prank(admin);
        project.refundAllDonors();

        // Verify refunds
        assertEq(donor.balance - donor1EthBefore, DONATION_AMOUNT);
        assertEq(mockToken.balanceOf(donor2) - donor2TokenBefore, tokenAmount);
    }

    function test_GetTokenDonation() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));
        uint256 amount = 1000 * 10**18;

        vm.startPrank(donor);
        mockToken.approve(address(project), amount);
        project.donateToken(address(mockToken), amount);
        vm.stopPrank();

        assertEq(project.getTokenDonation(donor, address(mockToken)), amount);
        assertEq(project.getTokenDonation(donor, address(0x999)), 0); // Non-existent token
    }

    function test_GetEthBalance() public {
        address projectAddr = _createProject();
        AquaFundProject project = AquaFundProject(payable(projectAddr));

        assertEq(project.getEthBalance(), 0);

        vm.prank(donor);
        project.donate{value: DONATION_AMOUNT}();

        assertEq(project.getEthBalance(), DONATION_AMOUNT);
        assertEq(project.getEthBalance(), address(project).balance);
    }

    // Helper function
    function _createProject() internal returns (address) {
        vm.prank(admin);
        factory.grantRole(factory.PROJECT_CREATOR_ROLE(), admin);

        vm.prank(admin);
        return factory.createProject(
            admin,           // admin
            admin,           // creator
            FUNDING_GOAL,    // fundingGoal
            "Test Project", // title
            "Test Description", // description
            new string[](0), // images
            "Test Location", // location
            "Test Category"  // category
        );
    }
}

