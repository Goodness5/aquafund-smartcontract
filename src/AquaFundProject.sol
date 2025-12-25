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
    
    // Platform admin oversight - stored for gas efficiency
    address public platformAdmin;
    
    // Donation pause state
    bool public donationsPaused;
    
    // Donation tracking - using mappings for O(1) access
    mapping(address => uint256) private _donations; // donor => total donated
    mapping(address => uint256) private _ethDonations; // donor => ETH donated
    mapping(address => mapping(address => uint256)) private _tokenDonationsByDonor; // donor => token => amount
    address[] private _donors; // Array of unique donors
    
    // Token escrow tracking - tracks which tokens are held in escrow
    mapping(address => uint256) private _tokenBalances; // token => total amount held
    address[] private _donatedTokens; // Array of unique token addresses that received donations
    
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
    error DonationsPaused();

    modifier onlyFactory() {
        if (msg.sender != address(factory)) revert UnauthorizedAccess();
        _;
    }

    /**
     * @dev Check if caller is project creator or admin (NGO level access)
     */
    modifier onlyProjectCreatorOrAdmin() {
        bool isProjectAdmin = msg.sender == _projectInfo.admin;
        bool isProjectCreator = msg.sender == _projectInfo.creator;
        if (!isProjectAdmin && !isProjectCreator) revert UnauthorizedAccess();
        _;
    }

    /**
     * @dev Check if caller is platform admin (organization level - ultimate control)
     */
    modifier onlyPlatformAdmin() {
        bool isPlatformAdmin = msg.sender == platformAdmin || 
                              (address(factory) != address(0) && msg.sender == factory.owner());
        if (!isPlatformAdmin) revert UnauthorizedAccess();
        _;
    }

    /**
     * @dev Check if caller is project creator/admin OR platform admin
     * Project creator/admin (NGO) has same level access for their projects
     * Platform admin (organization) has ultimate control
     */
    modifier onlyAdminOrPlatformAdmin() {
        bool isProjectAdmin = msg.sender == _projectInfo.admin;
        bool isProjectCreator = msg.sender == _projectInfo.creator;
        bool isPlatformAdmin = msg.sender == platformAdmin || 
                              (address(factory) != address(0) && msg.sender == factory.owner());
        if (!isProjectAdmin && !isProjectCreator && !isPlatformAdmin) revert UnauthorizedAccess();
        _;
    }

    modifier onlyAdmin() {
        // Project admin, creator, or platform admin
        bool isProjectAdmin = msg.sender == _projectInfo.admin;
        bool isProjectCreator = msg.sender == _projectInfo.creator;
        bool isPlatformAdmin = msg.sender == platformAdmin || 
                              (address(factory) != address(0) && msg.sender == factory.owner());
        if (!isProjectAdmin && !isProjectCreator && !isPlatformAdmin) revert UnauthorizedAccess();
        _;
    }

    modifier onlyWhenInitialized() {
        if (!_initialized) revert NotInitialized();
        _;
    }

    modifier whenDonationsNotPaused() {
        if (donationsPaused) revert DonationsPaused();
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
     * @param _creator Address that created the project
     * @param _fundingGoal Funding goal in wei
     * @param _title Project title
     * @param _description Project description
     * @param _images Array of project images
     * @param _location Project location
     * @param _category Project category
     */
    function initialize(
        uint256 _projectId,
        address _admin,
        address _creator,
        uint256 _fundingGoal,
        string memory _title,
        string memory _description,
        string[] memory _images,
        string memory _location,
        string memory _category
    ) external {
        if (_initialized) revert AlreadyInitialized();
        if (address(factory) != address(0) && msg.sender != address(factory)) {
            revert UnauthorizedAccess();
        }
        if (_admin == address(0)) revert InvalidAddress();
        if (_creator == address(0)) revert InvalidAddress();
        if (_fundingGoal == 0) revert InvalidAmount();
        
        // Set factory on first initialization (for clones)
        if (address(factory) == address(0)) {
            factory = IAquaFundFactory(msg.sender);
        }

        // Set platform admin (factory owner has ADMIN_ROLE)
        platformAdmin = factory.owner();

        uint64 timestamp = uint64(block.timestamp);

        // Initialize all ProjectInfo fields during project creation
        // All data is set here: projectId, admin, creator, fundingGoal, 
        // fundsRaised (starts at 0), status (starts as Active), 
        // title, description, images (array), location, category,
        // createdAt, and updatedAt timestamps
        _projectInfo = ProjectInfo({
            projectId: uint128(_projectId),      // From factory (auto-incremented)
            admin: _admin,                       // Project administrator (NGO)
            creator: _creator,                   // Address that created the project
            fundingGoal: _fundingGoal,          // Funding target in wei
            fundsRaised: 0,                      // Starts at zero
            status: ProjectStatus.Active,        // Initial status
            title: _title,                       // Project title
            description: _description,           // Project description
            images: _images,                     // Array of project images
            location: _location,                 // Project location
            category: _category,                 // Project category
            createdAt: timestamp,                // Creation timestamp
            updatedAt: timestamp                 // Last update timestamp
        });

        donationsPaused = false;
        _initialized = true;
        _transferOwnership(_admin);

        emit ProjectInitialized(_projectId, _admin, _creator, _fundingGoal, _title, _description, _images, _location, _category);
    }

    /**
     * @dev Accept ETH donations
     */
    function donate() external payable nonReentrant onlyWhenInitialized whenDonationsNotPaused {
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
    ) external nonReentrant onlyWhenInitialized whenDonationsNotPaused {
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

        // Transfer token to this contract (escrow)
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Track token donations per donor
        bool isNewToken = _tokenBalances[token] == 0;
        if (isNewToken) {
            _donatedTokens.push(token);
        }
        _tokenBalances[token] += amount;
        _tokenDonationsByDonor[msg.sender][token] += amount;

        _processDonation(msg.sender, amount, false);

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
            _projectInfo.updatedAt = uint64(block.timestamp);
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
     * @dev Release funds to project admin (service fee deducted)
     * Releases both ETH and all ERC20 tokens held in escrow
     * Can be called by project admin or platform admin
     */
    function releaseFunds() external nonReentrant onlyAdminOrPlatformAdmin onlyWhenInitialized {
        if (_projectInfo.status != ProjectStatus.Funded) {
            if (_projectInfo.fundsRaised < _projectInfo.fundingGoal) {
                revert FundingGoalNotReached();
            }
        }
        if (_projectInfo.status == ProjectStatus.Completed) {
            revert FundsAlreadyReleased();
        }

        address treasury = factory.getTreasury();
        uint256 serviceFeeBps = factory.getServiceFee();

        // Release ETH with service fee
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            uint256 ethServiceFee = (ethBalance * serviceFeeBps) / 10000;
            uint256 ethNetAmount = ethBalance - ethServiceFee;

            // Transfer service fee to treasury
            if (treasury != address(0) && ethServiceFee > 0) {
                (bool success, ) = payable(treasury).call{value: ethServiceFee}("");
                if (!success) revert TransferFailed();
            }

            // Transfer remaining ETH to admin
            if (ethNetAmount > 0) {
                (bool successAdmin, ) = payable(_projectInfo.admin).call{value: ethNetAmount}("");
                if (!successAdmin) revert TransferFailed();
            }
        }

        // Release all ERC20 tokens with service fee
        uint256 tokenCount = _donatedTokens.length;
        for (uint256 i = 0; i < tokenCount; ) {
            address token = _donatedTokens[i];
            uint256 tokenBalance = _tokenBalances[token];
            
            if (tokenBalance > 0) {
                uint256 tokenServiceFee = (tokenBalance * serviceFeeBps) / 10000;
                uint256 tokenNetAmount = tokenBalance - tokenServiceFee;

                // Transfer service fee to treasury
                if (treasury != address(0) && tokenServiceFee > 0) {
                    IERC20(token).safeTransfer(treasury, tokenServiceFee);
                }

                // Transfer remaining tokens to admin
                if (tokenNetAmount > 0) {
                    IERC20(token).safeTransfer(_projectInfo.admin, tokenNetAmount);
                }

                // Clear token balance tracking
                _tokenBalances[token] = 0;
            }

            unchecked {
                ++i;
            }
        }

        // Clear token list
        delete _donatedTokens;

        _projectInfo.status = ProjectStatus.Completed;
        _projectInfo.updatedAt = uint64(block.timestamp);

        emit FundsReleased(
            _projectInfo.projectId,
            _projectInfo.admin,
            ethBalance,
            (ethBalance * serviceFeeBps) / 10000
        );
    }

    /**
     * @dev Submit evidence for project completion
     * @param _evidenceHash Evidence hash or URI
     * Can be called by project admin or platform admin
     */
    function submitEvidence(
        string memory _evidenceHash
    ) external onlyAdminOrPlatformAdmin onlyWhenInitialized {
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
     * Can be called by project admin or platform admin
     */
    function updateStatus(
        ProjectStatus _newStatus
    ) external onlyAdminOrPlatformAdmin onlyWhenInitialized {
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
        _projectInfo.updatedAt = uint64(block.timestamp);

        emit ProjectStatusChanged(
            _projectInfo.projectId,
            oldStatus,
            _projectInfo.status
        );
    }

    /**
     * @dev Refund a specific donor (both ETH and tokens)
     * @param donor Address of donor to refund
     * Can be called by project admin or platform admin
     */
    function refundDonor(
        address donor
    ) external nonReentrant onlyAdminOrPlatformAdmin onlyWhenInitialized {
        uint256 donationAmount = _donations[donor];
        if (donationAmount == 0) revert NoDonationsToRefund();
        if (_projectInfo.status != ProjectStatus.Cancelled) {
            revert InvalidStatusTransition();
        }

        _donations[donor] = 0;
        _projectInfo.fundsRaised -= donationAmount;

        // Refund ETH
        uint256 ethAmount = _ethDonations[donor];
        if (ethAmount > 0) {
            _ethDonations[donor] = 0;
            (bool success, ) = payable(donor).call{value: ethAmount}("");
            if (!success) revert TransferFailed();
        }

        // Refund all tokens donated by this donor
        uint256 tokenCount = _donatedTokens.length;
        for (uint256 i = 0; i < tokenCount; ) {
            address token = _donatedTokens[i];
            uint256 tokenAmount = _tokenDonationsByDonor[donor][token];
            
            if (tokenAmount > 0) {
                _tokenDonationsByDonor[donor][token] = 0;
                _tokenBalances[token] -= tokenAmount;
                
                // If this was the last donation for this token, remove it from list
                if (_tokenBalances[token] == 0) {
                    // Swap with last element and pop
                    _donatedTokens[i] = _donatedTokens[tokenCount - 1];
                    _donatedTokens.pop();
                    tokenCount--;
                    i--; // Recheck this index
                }
                
                IERC20(token).safeTransfer(donor, tokenAmount);
            }

            unchecked {
                ++i;
            }
        }

        emit RefundIssued(_projectInfo.projectId, donor, donationAmount);
    }

    /**
     * @dev Refund all donors (emergency function) - both ETH and tokens
     * Can be called by project admin or platform admin
     */
    function refundAllDonors() external nonReentrant onlyAdminOrPlatformAdmin onlyWhenInitialized {
        if (_projectInfo.status != ProjectStatus.Cancelled) {
            revert InvalidStatusTransition();
        }

        uint256 donorCount = _donors.length;
        for (uint256 i = 0; i < donorCount; ) {
            address donor = _donors[i];
            uint256 totalDonationAmount = _donations[donor];
            uint256 ethAmount = _ethDonations[donor];
            
            // Refund ETH
            if (ethAmount > 0) {
                _ethDonations[donor] = 0;
                (bool success, ) = payable(donor).call{value: ethAmount}("");
                if (!success) revert TransferFailed();
            }

            // Refund all tokens for this donor
            uint256 donorTokenCount = _donatedTokens.length;
            for (uint256 j = 0; j < donorTokenCount; ) {
                address token = _donatedTokens[j];
                uint256 tokenAmount = _tokenDonationsByDonor[donor][token];
                
                if (tokenAmount > 0) {
                    _tokenDonationsByDonor[donor][token] = 0;
                    _tokenBalances[token] -= tokenAmount;
                    
                    IERC20(token).safeTransfer(donor, tokenAmount);
                }

                unchecked {
                    ++j;
                }
            }

            _donations[donor] = 0;
            emit RefundIssued(_projectInfo.projectId, donor, totalDonationAmount);

            unchecked {
                ++i;
            }
        }

        // Clear all tracking
        _projectInfo.fundsRaised = 0;
        delete _donors;
        
        // Clear token balances before deleting array
        uint256 tokenCount = _donatedTokens.length;
        for (uint256 i = 0; i < tokenCount; ) {
            delete _tokenBalances[_donatedTokens[i]];
            unchecked {
                ++i;
            }
        }
        delete _donatedTokens;
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
     * @dev Get token balance held in escrow for a specific token
     * @param token Token contract address
     * @return balance Amount of tokens held in escrow
     */
    function getTokenBalance(address token) external view onlyWhenInitialized returns (uint256) {
        return _tokenBalances[token];
    }

    /**
     * @dev Get all tokens that have received donations
     * @return tokens Array of token addresses
     */
    function getDonatedTokens() external view onlyWhenInitialized returns (address[] memory) {
        return _donatedTokens;
    }

    /**
     * @dev Get token donation amount for a specific donor and token
     * @param donor Address of donor
     * @param token Token contract address
     * @return amount Amount of tokens donated by this donor
     */
    function getTokenDonation(address donor, address token) 
        external 
        view 
        onlyWhenInitialized 
        returns (uint256) 
    {
        return _tokenDonationsByDonor[donor][token];
    }

    /**
     * @dev Get ETH balance held in escrow
     * @return balance Amount of ETH held in escrow
     */
    function getEthBalance() external view onlyWhenInitialized returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Pause donations (can be called by project creator/admin or platform admin)
     */
    function pauseDonations() external onlyAdminOrPlatformAdmin onlyWhenInitialized {
        donationsPaused = true;
        emit ProjectStatusChanged(
            _projectInfo.projectId,
            _projectInfo.status,
            _projectInfo.status // Status doesn't change, just pause state
        );
    }

    /**
     * @dev Unpause donations (can be called by project creator/admin or platform admin)
     */
    function unpauseDonations() external onlyAdminOrPlatformAdmin onlyWhenInitialized {
        donationsPaused = false;
        emit ProjectStatusChanged(
            _projectInfo.projectId,
            _projectInfo.status,
            _projectInfo.status // Status doesn't change, just pause state
        );
    }

    /**
     * @dev End project after goal reached (can be called by project creator/admin or platform admin)
     * This allows manually ending a project even if goal is reached
     */
    function endProject() external onlyAdminOrPlatformAdmin onlyWhenInitialized {
        if (_projectInfo.status != ProjectStatus.Active && _projectInfo.status != ProjectStatus.Funded) {
            revert InvalidStatusTransition();
        }
        if (_projectInfo.fundsRaised < _projectInfo.fundingGoal) {
            revert FundingGoalNotReached();
        }
        
        ProjectStatus oldStatus = _projectInfo.status;
        _projectInfo.status = ProjectStatus.Funded;
        _projectInfo.updatedAt = uint64(block.timestamp);
        
        emit ProjectStatusChanged(
            _projectInfo.projectId,
            oldStatus,
            ProjectStatus.Funded
        );
    }

    /**
     * @dev Remove/Delete project (ONLY platform admin - ultimate control)
     * This permanently marks the project as removed and prevents further operations
     * Funds should be refunded before removal
     */
    function removeProject() external onlyPlatformAdmin onlyWhenInitialized {
        // Mark as cancelled if not already
        if (_projectInfo.status != ProjectStatus.Cancelled && 
            _projectInfo.status != ProjectStatus.Completed &&
            _projectInfo.status != ProjectStatus.Refunded) {
            ProjectStatus oldStatus = _projectInfo.status;
            _projectInfo.status = ProjectStatus.Cancelled;
            _projectInfo.updatedAt = uint64(block.timestamp);
            
            emit ProjectStatusChanged(
                _projectInfo.projectId,
                oldStatus,
                ProjectStatus.Cancelled
            );
        }
        
        // Pause donations permanently
        donationsPaused = true;
        
        emit ProjectStatusChanged(
            _projectInfo.projectId,
            _projectInfo.status,
            _projectInfo.status
        );
    }

    /**
     * @dev Receive ETH - automatically processes donation
     */
    receive() external payable nonReentrant {
        if (!_initialized) {
            revert NotInitialized();
        }
        if (donationsPaused) {
            revert DonationsPaused();
        }
        _handleEthDonation();
    }
}

