// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AquaFundProject} from "./AquaFundProject.sol";
import {IAquaFundFactory} from "./interfaces/IAquaFundFactory.sol";
import {IAquaFundBadge} from "./interfaces/IAquaFundBadge.sol";
import {AquaFundRegistry} from "./AquaFundRegistry.sol";

/**
 * @title AquaFundFactory
 * @dev Factory contract for creating AquaFund projects using minimal proxy pattern
 * @notice Uses EIP-1167 minimal proxy (clone) pattern for gas-efficient project creation
 */
contract AquaFundFactory is
    IAquaFundFactory,
    Ownable,
    AccessControl,
    Pausable
{
    using Clones for address;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PROJECT_CREATOR_ROLE = keccak256("PROJECT_CREATOR_ROLE");

    // Implementation contract for cloning
    AquaFundProject public immutable IMPLEMENTATION;

    // Badge contract for minting donor rewards
    IAquaFundBadge public badgeContract;
    
    // Registry contract for analytics
    AquaFundRegistry public registry;

    // Project tracking
    mapping(uint256 => address) private _projects; // projectId => projectAddress
    mapping(address => bool) public isAdmin; // admin addresses (verified NGOs)
    
    uint256 private _projectCounter;
    uint256 public serviceFee; // in basis points (10000 = 100%), default 1000 = 10%
    address public treasury;

    // Global donation tracking for leaderboard
    mapping(address => uint256) public totalDonated; // donor => total donated across all projects
    address[] private _allDonors; // Array of all unique donors
    uint256 public totalDonationsCount; // Total number of donations
    uint256 public totalFundsRaised; // Total funds raised across all projects

    // Token allowlist for donations (security measure)
    mapping(address => bool) public allowedTokens; // token address => is allowed
    address[] private _allowedTokensList; // Array of allowed token addresses
    bool public allowAllTokens; // If true, allow any token (use with caution)

    // Custom errors
    error InvalidAddress();
    error InvalidFee();
    error InvalidImplementation();
    error ProjectNotExists();
    error UnauthorizedAccess();
    error TokenNotAllowed();

    /**
     * @dev Constructor
     * @param _implementation Implementation contract address for cloning
     * @param _treasury Treasury address for service fees
     * @param _serviceFee Service fee in basis points (1000 = 10%)
     */
    constructor(
        address _implementation,
        address _treasury,
        uint256 _serviceFee
    ) Ownable(msg.sender) {
        if (_implementation == address(0)) revert InvalidImplementation();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_serviceFee > 5000) revert InvalidFee(); // Max 50%

        IMPLEMENTATION = AquaFundProject(payable(_implementation));
        treasury = _treasury;
        serviceFee = _serviceFee;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PROJECT_CREATOR_ROLE, msg.sender);

        emit TreasuryUpdated(address(0), _treasury);
        emit ServiceFeeUpdated(0, _serviceFee);

        // ETH is always allowed (address(0) for native)
        // No need to add it to allowlist
    }

    /**
     * @dev Create a new project using minimal proxy
     * @param admin Project administrator address
     * @param fundingGoal Funding goal in wei
     * @param metadataURI IPFS hash for project metadata
     * @return projectAddress Address of the created project
     */
    function createProject(
        address admin,
        uint256 fundingGoal,
        bytes32 metadataURI
    )
        external
        whenNotPaused
        onlyRole(PROJECT_CREATOR_ROLE)
        returns (address projectAddress)
    {
        if (admin == address(0)) revert InvalidAddress();
        if (fundingGoal == 0) revert InvalidAddress();

        // Create minimal proxy (clone)
        projectAddress = address(IMPLEMENTATION).clone();

        // Increment project counter
        uint256 projectId = ++_projectCounter;

        // Initialize the clone
        AquaFundProject(payable(projectAddress)).initialize(
            projectId,
            admin,
            fundingGoal,
            metadataURI
        );

        // Store project address
        _projects[projectId] = projectAddress;

        // Mark admin as verified if not already
        if (!isAdmin[admin]) {
            isAdmin[admin] = true;
            emit AdminStatusUpdated(admin, true);
        }

        // Register project with registry if set
        if (address(registry) != address(0)) {
            try registry.registerProject(projectId) {
                // Successfully registered
            } catch {
                // Registry registration failed but project created
            }
        }

        emit ProjectCreated(projectId, projectAddress, admin, fundingGoal);

        return projectAddress;
    }

    /**
     * @dev Get project address by ID
     * @param projectId Project identifier
     * @return Project contract address
     */
    function getProjectAddress(
        uint256 projectId
    ) external view returns (address) {
        address projectAddr = _projects[projectId];
        if (projectAddr == address(0)) revert ProjectNotExists();
        return projectAddr;
    }

    /**
     * @dev Get total number of projects created
     * @return Total project count
     */
    function getTotalProjects() external view returns (uint256) {
        return _projectCounter;
    }

    /**
     * @dev Update service fee (only owner)
     * @param _newFee New service fee in basis points
     */
    function updateServiceFee(
        uint256 _newFee
    ) external onlyRole(ADMIN_ROLE) {
        if (_newFee > 5000) revert InvalidFee(); // Max 50%
        uint256 oldFee = serviceFee;
        serviceFee = _newFee;
        emit ServiceFeeUpdated(oldFee, _newFee);
    }

    /**
     * @dev Update treasury address (only owner)
     * @param _newTreasury New treasury address
     */
    function updateTreasury(
        address _newTreasury
    ) external onlyRole(ADMIN_ROLE) {
        if (_newTreasury == address(0)) revert InvalidAddress();
        address oldTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    /**
     * @dev Set badge contract address and grant factory MINTER_ROLE
     * @param _badgeContract Badge contract address
     */
    function setBadgeContract(
        address _badgeContract
    ) external onlyRole(ADMIN_ROLE) {
        if (_badgeContract == address(0)) revert InvalidAddress();
        badgeContract = IAquaFundBadge(_badgeContract);
        
        // Grant factory MINTER_ROLE so it can mint badges
        // This requires the badge contract to implement AccessControl
        // The badge contract should have a function to grant roles
        // For now, badge contract grants minter role in constructor
    }

    /**
     * @dev Set registry contract address
     * @param _registry Registry contract address
     */
    function setRegistry(
        address _registry
    ) external onlyRole(ADMIN_ROLE) {
        if (_registry == address(0)) revert InvalidAddress();
        registry = AquaFundRegistry(_registry);
    }

    /**
     * @dev Update admin verification status
     * @param admin Admin address
     * @param status Verification status
     */
    function updateAdminStatus(
        address admin,
        bool status
    ) external onlyRole(ADMIN_ROLE) {
        if (admin == address(0)) revert InvalidAddress();
        isAdmin[admin] = status;
        emit AdminStatusUpdated(admin, status);
    }

    /**
     * @dev Grant project creator role
     * @param account Address to grant role
     */
    function grantProjectCreatorRole(
        address account
    ) external onlyRole(ADMIN_ROLE) {
        _grantRole(PROJECT_CREATOR_ROLE, account);
    }

    /**
     * @dev Revoke project creator role
     * @param account Address to revoke role
     */
    function revokeProjectCreatorRole(
        address account
    ) external onlyRole(ADMIN_ROLE) {
        _revokeRole(PROJECT_CREATOR_ROLE, account);
    }

    /**
     * @dev Pause project creation
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause project creation
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Get service fee
     * @return Service fee in basis points
     */
    function getServiceFee() external view returns (uint256) {
        return serviceFee;
    }

    /**
     * @dev Get treasury address
     * @return Treasury address
     */
    function getTreasury() external view returns (address) {
        return treasury;
    }

    /**
     * @dev Get all project IDs for a range (for pagination)
     * @param start Starting index
     * @param end Ending index
     * @return projectIds Array of project IDs
     * @return addresses Array of project addresses
     */
    function getProjectsRange(
        uint256 start,
        uint256 end
    )
        external
        view
        returns (uint256[] memory projectIds, address[] memory addresses)
    {
        if (end > _projectCounter) {
            end = _projectCounter;
        }
        if (start > end) {
            start = end;
        }

        uint256 length = end - start;
        projectIds = new uint256[](length);
        addresses = new address[](length);

        for (uint256 i = 0; i < length; ) {
            uint256 projectId = start + i + 1;
            projectIds[i] = projectId;
            addresses[i] = _projects[projectId];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Record donation globally (called by project contracts)
     * @param donor Donor address
     * @param projectId Project ID
     * @param amount Donation amount
     */
    function recordDonation(
        address donor,
        uint256 projectId,
        uint256 amount
    ) external {
        // Only allow project contracts to record donations
        address projectAddr = _projects[projectId];
        if (projectAddr == address(0) || msg.sender != projectAddr) {
            revert UnauthorizedAccess();
        }

        // Track if new donor
        bool isNewDonor = totalDonated[donor] == 0;
        if (isNewDonor) {
            _allDonors.push(donor);
        }

        // Update global stats
        totalDonated[donor] += amount;
        totalDonationsCount++;
        totalFundsRaised += amount;

        emit GlobalDonationReceived(
            donor,
            projectId,
            amount,
            totalDonated[donor],
            block.timestamp
        );
    }

    /**
     * @dev Get total amount donated by a specific donor
     * @param donor Donor address
     * @return Total amount donated across all projects
     */
    function getTotalDonated(address donor) external view returns (uint256) {
        return totalDonated[donor];
    }

    /**
     * @dev Get leaderboard (sorted by total donations descending)
     * @param start Starting index (0-based)
     * @param end Ending index (exclusive)
     * @return donors Array of donor addresses
     * @return amounts Array of total donation amounts
     * @notice This is a view function but may be gas-intensive for large datasets
     * @notice Consider using off-chain indexing for better performance
     */
    function getLeaderboard(
        uint256 start,
        uint256 end
    )
        external
        view
        returns (address[] memory donors, uint256[] memory amounts)
    {
        uint256 totalDonors = _allDonors.length;
        if (end > totalDonors) {
            end = totalDonors;
        }
        if (start > end) {
            start = end;
        }

        uint256 length = end - start;
        donors = new address[](length);
        amounts = new uint256[](length);

        // Create array with all donor data for sorting
        address[] memory sortedDonors = new address[](totalDonors);
        uint256[] memory sortedAmounts = new uint256[](totalDonors);

        for (uint256 i = 0; i < totalDonors; ) {
            sortedDonors[i] = _allDonors[i];
            sortedAmounts[i] = totalDonated[_allDonors[i]];
            unchecked {
                ++i;
            }
        }

        // Simple insertion sort (gas-efficient for small datasets)
        // For production with many donors, consider off-chain sorting
        for (uint256 i = 0; i < totalDonors; ) {
            uint256 maxIdx = i;
            for (uint256 j = i + 1; j < totalDonors; ) {
                if (sortedAmounts[j] > sortedAmounts[maxIdx]) {
                    maxIdx = j;
                }
                unchecked {
                    ++j;
                }
            }
            if (maxIdx != i) {
                // Swap
                address tempAddr = sortedDonors[i];
                uint256 tempAmt = sortedAmounts[i];
                sortedDonors[i] = sortedDonors[maxIdx];
                sortedAmounts[i] = sortedAmounts[maxIdx];
                sortedDonors[maxIdx] = tempAddr;
                sortedAmounts[maxIdx] = tempAmt;
            }
            unchecked {
                ++i;
            }
        }

        // Extract requested range
        for (uint256 i = 0; i < length; ) {
            donors[i] = sortedDonors[start + i];
            amounts[i] = sortedAmounts[start + i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Get total number of unique donors
     * @return Number of unique donors
     */
    function getTotalDonors() external view returns (uint256) {
        return _allDonors.length;
    }

    /**
     * @dev Get platform-wide statistics
     * @return totalProjects Total number of projects
     * @return totalRaised Total funds raised
     * @return totalDonors_ Total unique donors
     * @return totalDonations Total donation count
     */
    function getPlatformStats()
        external
        view
        returns (
            uint256 totalProjects,
            uint256 totalRaised,
            uint256 totalDonors_,
            uint256 totalDonations
        )
    {
        return (
            _projectCounter,
            totalFundsRaised,
            _allDonors.length,
            totalDonationsCount
        );
    }

    /**
     * @dev Check if a token is allowed for donations
     * @param token Token address (address(0) for ETH is always allowed)
     * @return True if token is allowed
     */
    function isTokenAllowed(address token) external view returns (bool) {
        // ETH (native) is always allowed
        if (token == address(0)) {
            return true;
        }
        // If allowAllTokens is true, allow any token
        if (allowAllTokens) {
            return true;
        }
        // Check allowlist
        return allowedTokens[token];
    }

    /**
     * @dev Add a token to the allowlist
     * @param token Token contract address
     */
    function addAllowedToken(address token) external onlyRole(ADMIN_ROLE) {
        if (token == address(0)) revert InvalidAddress();
        if (allowedTokens[token]) {
            return; // Already allowed
        }

        allowedTokens[token] = true;
        _allowedTokensList.push(token);

        emit TokenAllowed(token, true);
    }

    /**
     * @dev Remove a token from the allowlist
     * @param token Token contract address
     */
    function removeAllowedToken(address token) external onlyRole(ADMIN_ROLE) {
        if (token == address(0)) revert InvalidAddress();
        if (!allowedTokens[token]) {
            return; // Already not allowed
        }

        allowedTokens[token] = false;

        // Remove from array
        uint256 length = _allowedTokensList.length;
        for (uint256 i = 0; i < length; ) {
            if (_allowedTokensList[i] == token) {
                _allowedTokensList[i] = _allowedTokensList[length - 1];
                _allowedTokensList.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }

        emit TokenAllowed(token, false);
    }

    /**
     * @dev Get all allowed tokens
     * @return Array of allowed token addresses
     */
    function getAllowedTokens() external view returns (address[] memory) {
        return _allowedTokensList;
    }

    /**
     * @dev Set whether to allow all tokens (use with extreme caution)
     * @param _allowAllTokens True to allow all tokens, false to use allowlist
     */
    function setAllowAllTokens(
        bool _allowAllTokens
    ) external onlyRole(ADMIN_ROLE) {
        allowAllTokens = _allowAllTokens;
    }

    /**
     * @dev Mint badge for donor (called by backend after IPFS upload)
     * @param donor Donor address
     * @param projectId Project ID
     * @param donationAmount Total donation amount for tier calculation
     * @param tokenURI IPFS URI for badge metadata (generated by backend)
     * @notice This should be called by backend after:
     *         1. Listening to DonationReceived event
     *         2. Generating badge metadata JSON
     *         3. Uploading to IPFS
     *         4. Getting IPFS URI
     */
    function mintBadgeForDonor(
        address donor,
        uint256 projectId,
        uint256 donationAmount,
        string memory tokenURI
    ) external {
        // Only allow project contracts or authorized backend to mint
        // Verify project exists and donor made a donation
        address projectAddr = _projects[projectId];
        if (projectAddr == address(0)) revert ProjectNotExists();
        
        // Allow project contracts or admin/backend with special role
        // For now, allow anyone - backend should be the one calling this
        // In production, consider adding a role for backend service
        if (address(badgeContract) == address(0)) {
            revert InvalidAddress(); // Badge contract not set
        }

        // Mint badge with IPFS URI
        badgeContract.mintBadge(donor, projectId, donationAmount, tokenURI);
    }
}

