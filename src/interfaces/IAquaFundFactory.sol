// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IAquaFundProject } from "./IAquaFundProject.sol";

/**
 * @title IAquaFundFactory
 * @dev Interface for AquaFund Factory contract
 */
interface IAquaFundFactory {
    event ProjectCreated(
        uint256 indexed projectId,
        address indexed projectAddress,
        address indexed admin,
        uint256 fundingGoal
    );

    event ServiceFeeUpdated(uint256 oldFee, uint256 newFee);

    event TreasuryUpdated(address oldTreasury, address newTreasury);

    event AdminStatusUpdated(address indexed admin, bool status);

    event TokenAllowed(address indexed token, bool allowed);

    event NGORegistered(
        uint256 indexed ngoId,
        address indexed ngoAddress,
        string name,
        string description
    );

    event NGOUpdated(
        uint256 indexed ngoId,
        string name,
        string description,
        bool isActive
    );

    event ProjectAssignedToNGO(
        uint256 indexed projectId,
        uint256 indexed ngoId
    );

    function createProject(
        address admin,
        address creator,
        uint256 fundingGoal,
        string memory title,
        string memory description,
        string[] memory images,
        string memory location,
        string memory category
    ) external returns (address projectAddress);

    function createProjectWithNGO(
        uint256 ngoId,
        address admin,
        address creator,
        uint256 fundingGoal,
        string memory title,
        string memory description,
        string[] memory images,
        string memory location,
        string memory category
    ) external returns (address projectAddress);

    event GlobalDonationReceived(
        address indexed donor,
        uint256 indexed projectId,
        uint256 amount,
        uint256 totalDonated,
        uint256 timestamp
    );

    function recordDonation(
        address donor,
        uint256 projectId,
        uint256 amount
    ) external;

    function getTotalDonated(address donor) external view returns (uint256);
    
    function getLeaderboard(
        uint256 start,
        uint256 end
    ) external view returns (address[] memory donors, uint256[] memory amounts);

    function getProjectAddress(uint256 projectId) external view returns (address);

    function getTotalProjects() external view returns (uint256);

    function isAdmin(address account) external view returns (bool);

    function getServiceFee() external view returns (uint256);

    function getTreasury() external view returns (address);

    function isTokenAllowed(address token) external view returns (bool);

    function addAllowedToken(address token) external;

    function removeAllowedToken(address token) external;

    function getAllowedTokens() external view returns (address[] memory);

    // NGO functions
    function registerNGO(
        address ngoAddress,
        string memory name,
        string memory description
    ) external returns (uint256 ngoId);

    function updateNGO(
        uint256 ngoId,
        string memory name,
        string memory description,
        bool isActive
    ) external;

    function getNGOInfo(uint256 ngoId) external view returns (
        address ngoAddress,
        string memory name,
        string memory description,
        bool isActive,
        uint256 projectCount
    );

    function getNGOIdByAddress(address ngoAddress) external view returns (uint256);

    function getProjectsByNGO(uint256 ngoId) external view returns (
        uint256[] memory projectIds,
        address[] memory projectAddresses
    );

    function getProjectNGOId(uint256 projectId) external view returns (uint256);

    function getTotalNGOs() external view returns (uint256);
}

