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

    function createProject(
        address admin,
        uint256 fundingGoal,
        bytes32 metadataUri
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
}

