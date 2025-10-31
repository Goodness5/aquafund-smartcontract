// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAquaFundProject} from "./interfaces/IAquaFundProject.sol";
import {IAquaFundFactory} from "./interfaces/IAquaFundFactory.sol";

/**
 * @title AquaFundProject
 * @dev Cloneable project contract for managing individual water funding projects
 * @notice This contract uses the minimal proxy pattern (EIP-1167) for gas efficiency
 */
contract AquaFundProject is IAquaFundProject, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Packed storage for gas optimization
    ProjectInfo private _projectInfo;
    
    // Factory contract reference (set during initialization)
    IAquaFundFactory public factory;
    
    // Donation tracking - using mappings for O(1) access
    mapping(address => uint256) private _donations; // donor => total donated
    mapping(address => uint256) private _ethDonations; // donor => ETH donated
    mapping(address => uint256) private _tokenDonations; // donor => token donated (indexed by token address)
    address[] private _donors; // Array of unique donors
    
    // Evidence tracking
    Evidence[] private _evidence;
    
    // Initialization flag
    bool private _initialized;

    // Constants
    uint256 public constant MIN_DONATION = 0.001 ether;
    
    // Custom errors for gas optimization
    error AlreadyInitialized();
    error NotInitialized();
    error InvalidProjectId();
    error InvalidAmount();
    error InvalidAddress();
    error FundingGoalNotReached();
    error FundsAlreadyReleased();
    error UnauthorizedAccess();
    error InvalidStatusTransition();
    error NoDonationsToRefund();
    error TransferFailed();
    error TokenNotAllowed();

    modifier onlyFactory() {
        if (msg.sender != address(factory)) revert UnauthorizedAccess();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != _projectInfo.admin) revert UnauthorizedAccess();
        _;
    }

    modifier onlyWhenInitialized() {
        if (!_initialized) revert NotInitialized();
        _;
    }

    constructor() Ownable(msg.sender) {
        // Factory will be set during initialization
        // This allows flexible deployment order
    }

    /**
     * @dev Initialize the project (called by factory)
     * @param _projectId Unique project identifier
     * @param _admin Project administrator address
     * @param _fundingGoal Funding goal in wei
     * @param _metadataUri IPFS hash for project metadata
     */
    function initialize(
        uint256 _projectId,
        address _admin,
        uint256 _fundingGoal,
        bytes32 _metadataUri
    ) external {
        if (_initialized) revert AlreadyInitialized();
        if (address(factory) != address(0) && msg.sender != address(factory)) {
            revert UnauthorizedAccess();
        }
        if (_admin == address(0)) revert InvalidAddress();
        if (_fundingGoal == 0) revert InvalidAmount();
        
        // Set factory on first initialization (for clones)
        if (address(factory) == address(0)) {
            factory = IAquaFundFactory(msg.sender);
        }

        // Pack projectId into uint128 (supports up to 2^128 projects)
        _projectInfo = ProjectInfo({
            projectId: uint128(_projectId),
            admin: _admin,
            fundingGoal: _fundingGoal,
            fundsRaised: 0,
            status: ProjectStatus.Active,
            metadataUri: _metadataUri
        });

        _initialized = true;
        _transferOwnership(_admin);

        emit ProjectInitialized(_projectId, _admin, _fundingGoal, _metadataUri);
    }

    /**
     * @dev Accept ETH donations
     */
    function donate() external payable nonReentrant onlyWhenInitialized {
        _handleEthDonation();
    }

    /**
     * @dev Internal function to handle ETH donations
     */
    function _handleEthDonation() internal {
        if (_projectInfo.status != ProjectStatus.Active) {
            revert InvalidStatusTransition();
        }
        if (msg.value < MIN_DONATION) revert InvalidAmount();

        _processDonation(msg.sender, msg.value, true);

        emit DonationReceived(
            _projectInfo.projectId,
            msg.sender,
            msg.value,
            true,
            block.timestamp
        );
    }

    /**
     * @dev Accept ERC20 token donations
     * @param token Token contract address
     * @param amount Amount to donate
     */
    function donateToken(
        address token,
        uint256 amount
    ) external nonReentrant onlyWhenInitialized {
        if (_projectInfo.status != ProjectStatus.Active) {
            revert InvalidStatusTransition();
        }
        if (token == address(0)) revert InvalidAddress();
        if (amount < MIN_DONATION) revert InvalidAmount();

        // Check if token is allowed via factory
        if (address(factory) != address(0)) {
            if (!factory.isTokenAllowed(token)) {
                revert TokenNotAllowed();
            }
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        _processDonation(msg.sender, amount, false);
        _tokenDonations[msg.sender] += amount;

        emit DonationReceived(
            _projectInfo.projectId,
            msg.sender,
            amount,
            false,
            block.timestamp
        );
    }

    /**
     * @dev Process donation internally (gas optimization)
     */
    function _processDonation(
        address donor,
        uint256 amount,
        bool isEth
    ) private {
        bool isNewDonor = _donations[donor] == 0;
        
        if (isNewDonor) {
            _donors.push(donor);
        }

        _donations[donor] += amount;
        _projectInfo.fundsRaised += amount;

        if (isEth) {
            _ethDonations[donor] += amount;
        }

        // Record donation in factory for global tracking
        if (address(factory) != address(0)) {
            try factory.recordDonation(donor, _projectInfo.projectId, amount) {
                // Donation recorded globally
            } catch {
                // Factory recording failed but donation succeeded (non-blocking)
            }
        }

        // Auto-update status to Funded if goal reached
        if (
            _projectInfo.status == ProjectStatus.Active &&
            _projectInfo.fundsRaised >= _projectInfo.fundingGoal
        ) {
            _projectInfo.status = ProjectStatus.Funded;
            emit ProjectStatusChanged(
                _projectInfo.projectId,
                ProjectStatus.Active,
                ProjectStatus.Funded
            );
        }

        // Badge minting is handled off-chain by backend:
        // 1. Backend listens for DonationReceived events
        // 2. Backend generates badge metadata JSON
        // 3. Backend uploads to IPFS
        // 4. Backend calls factory.mintBadgeForDonor() with IPFS URI
    }

    /**
     * @dev Release funds to project admin (10% service fee deducted)
     */
    function releaseFunds() external nonReentrant onlyAdmin onlyWhenInitialized {
        if (_projectInfo.status != ProjectStatus.Funded) {
            if (_projectInfo.fundsRaised < _projectInfo.fundingGoal) {
                revert FundingGoalNotReached();
            }
        }
        if (_projectInfo.status == ProjectStatus.Completed) {
            revert FundsAlreadyReleased();
        }

        uint256 totalAmount = address(this).balance;
        uint256 serviceFee = (totalAmount * factory.getServiceFee()) / 10000; // basis points
        uint256 netAmount = totalAmount - serviceFee;

        _projectInfo.status = ProjectStatus.Completed;

        // Transfer service fee to treasury
        address treasury = factory.getTreasury();
        if (treasury != address(0) && serviceFee > 0) {
            (bool success, ) = payable(treasury).call{value: serviceFee}("");
            if (!success) revert TransferFailed();
        }

        // Transfer remaining funds to admin
        (bool successAdmin, ) = payable(_projectInfo.admin).call{value: netAmount}("");
        if (!successAdmin) revert TransferFailed();

        emit FundsReleased(
            _projectInfo.projectId,
            _projectInfo.admin,
            netAmount,
            serviceFee
        );
    }

    /**
     * @dev Submit evidence for project completion
     * @param _evidenceHash IPFS hash of evidence (bytes32)
     */
    function submitEvidence(
        bytes32 _evidenceHash
    ) external onlyAdmin onlyWhenInitialized {
        _evidence.push(
            Evidence({
                evidenceHash: _evidenceHash,
                timestamp: uint64(block.timestamp),
                submitter: msg.sender
            })
        );

        emit EvidenceSubmitted(
            _projectInfo.projectId,
            _evidenceHash,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Update project status
     * @param _newStatus New status to set
     */
    function updateStatus(
        ProjectStatus _newStatus
    ) external onlyAdmin onlyWhenInitialized {
        ProjectStatus oldStatus = _projectInfo.status;
        
        // Validate status transition
        if (
            oldStatus == ProjectStatus.Completed ||
            oldStatus == ProjectStatus.Refunded ||
            (_newStatus == ProjectStatus.Funded &&
                _projectInfo.fundsRaised < _projectInfo.fundingGoal)
        ) {
            revert InvalidStatusTransition();
        }

        // Auto-update to Funded if goal reached
        if (
            _newStatus == ProjectStatus.Active &&
            _projectInfo.fundsRaised >= _projectInfo.fundingGoal
        ) {
            _projectInfo.status = ProjectStatus.Funded;
        } else {
            _projectInfo.status = _newStatus;
        }

        emit ProjectStatusChanged(
            _projectInfo.projectId,
            oldStatus,
            _projectInfo.status
        );
    }

    /**
     * @dev Refund a specific donor
     * @param donor Address of donor to refund
     */
    function refundDonor(
        address donor
    ) external nonReentrant onlyAdmin onlyWhenInitialized {
        uint256 donationAmount = _donations[donor];
        if (donationAmount == 0) revert NoDonationsToRefund();
        if (_projectInfo.status != ProjectStatus.Cancelled) {
            revert InvalidStatusTransition();
        }

        _donations[donor] = 0;
        _projectInfo.fundsRaised -= donationAmount;

        uint256 ethAmount = _ethDonations[donor];
        if (ethAmount > 0) {
            _ethDonations[donor] = 0;
            (bool success, ) = payable(donor).call{value: ethAmount}("");
            if (!success) revert TransferFailed();
        }

        emit RefundIssued(_projectInfo.projectId, donor, donationAmount);
    }

    /**
     * @dev Refund all donors (emergency function)
     */
    function refundAllDonors() external nonReentrant onlyAdmin onlyWhenInitialized {
        if (_projectInfo.status != ProjectStatus.Cancelled) {
            revert InvalidStatusTransition();
        }

        uint256 donorCount = _donors.length;
        for (uint256 i = 0; i < donorCount; ) {
            address donor = _donors[i];
            uint256 ethAmount = _ethDonations[donor];
            
            if (ethAmount > 0) {
                _ethDonations[donor] = 0;
                _donations[donor] = 0;
                (bool success, ) = payable(donor).call{value: ethAmount}("");
                if (!success) revert TransferFailed();
                
                emit RefundIssued(_projectInfo.projectId, donor, ethAmount);
            }

            unchecked {
                ++i;
            }
        }

        _projectInfo.fundsRaised = 0;
        delete _donors;
    }

    /**
     * @dev Get project information
     */
    function getProjectInfo()
        external
        view
        onlyWhenInitialized
        returns (ProjectInfo memory)
    {
        return _projectInfo;
    }

    /**
     * @dev Get total donations received
     */
    function getTotalDonations()
        external
        view
        onlyWhenInitialized
        returns (uint256)
    {
        return _projectInfo.fundsRaised;
    }

    /**
     * @dev Get number of unique donors
     */
    function getDonationCount()
        external
        view
        onlyWhenInitialized
        returns (uint256)
    {
        return _donors.length;
    }

    /**
     * @dev Get donation amount for a specific donor
     * @param donor Address of donor
     */
    function getDonation(
        address donor
    ) external view onlyWhenInitialized returns (uint256) {
        return _donations[donor];
    }

    /**
     * @dev Get number of evidence submissions
     */
    function getEvidenceCount()
        external
        view
        onlyWhenInitialized
        returns (uint256)
    {
        return _evidence.length;
    }

    /**
     * @dev Get all donors
     */
    function getDonors() external view onlyWhenInitialized returns (address[] memory) {
        return _donors;
    }

    /**
     * @dev Get evidence at index
     */
    function getEvidence(
        uint256 index
    ) external view onlyWhenInitialized returns (Evidence memory) {
        return _evidence[index];
    }

    /**
     * @dev Receive ETH - automatically processes donation
     */
    receive() external payable nonReentrant {
        if (!_initialized) {
            revert NotInitialized();
        }
        _handleEthDonation();
    }
}

