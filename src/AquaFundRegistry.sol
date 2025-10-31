// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAquaFundFactory} from "./interfaces/IAquaFundFactory.sol";
import {IAquaFundProject} from "./interfaces/IAquaFundProject.sol";
import {AquaFundProject} from "./AquaFundProject.sol";

/**
 * @title AquaFundRegistry
 * @dev Centralized registry for project management and analytics
 * @notice Provides aggregated data and project discovery functionality
 */
contract AquaFundRegistry is Ownable, AccessControl {
    // Roles
    bytes32 public constant VIEWER_ROLE = keccak256("VIEWER_ROLE");

    // Factory contract
    IAquaFundFactory public factory;

    // Analytics data
    struct PlatformStats {
        uint256 totalProjects;
        uint256 activeProjects;
        uint256 fundedProjects;
        uint256 completedProjects;
        uint256 totalFundsRaised;
        uint256 totalDonations;
        uint256 totalDonors;
    }

    // Project indexing
    mapping(uint256 => bool) private _indexedProjects;
    uint256[] private _allProjectIds;

    // Custom errors
    error InvalidAddress();
    error ProjectNotFound();
    error UnauthorizedAccess();

    /**
     * @dev Constructor
     */
    constructor() Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Set factory contract address
     * @param _factory Factory contract address
     */
    function setFactory(address _factory) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_factory == address(0)) revert InvalidAddress();
        factory = IAquaFundFactory(_factory);
    }

    /**
     * @dev Register a new project (called by factory)
     * @param projectId Project ID
     */
    function registerProject(uint256 projectId) external {
        if (msg.sender != address(factory)) revert UnauthorizedAccess();
        if (!_indexedProjects[projectId]) {
            _indexedProjects[projectId] = true;
            _allProjectIds.push(projectId);
        }
    }

    /**
     * @dev Get platform statistics
     * @return stats Platform statistics
     */
    function getPlatformStats()
        external
        view
        returns (PlatformStats memory stats)
    {
        uint256 totalProjects = _allProjectIds.length;
        uint256 active = 0;
        uint256 funded = 0;
        uint256 completed = 0;
        uint256 totalRaised = 0;
        uint256 totalDonations = 0;
        uint256 totalDonors = 0;

        for (uint256 i = 0; i < totalProjects; ) {
            address projectAddr = factory.getProjectAddress(_allProjectIds[i]);
            if (projectAddr != address(0)) {
                AquaFundProject project = AquaFundProject(payable(projectAddr));
                IAquaFundProject.ProjectInfo memory info = project
                    .getProjectInfo();

                if (info.status == IAquaFundProject.ProjectStatus.Active) {
                    active++;
                } else if (
                    info.status == IAquaFundProject.ProjectStatus.Funded
                ) {
                    funded++;
                } else if (
                    info.status == IAquaFundProject.ProjectStatus.Completed
                ) {
                    completed++;
                }

                totalRaised += info.fundsRaised;
                totalDonations += project.getDonationCount();
                totalDonors += project.getDonationCount(); // Unique donors per project
            }
            unchecked {
                ++i;
            }
        }

        stats = PlatformStats({
            totalProjects: totalProjects,
            activeProjects: active,
            fundedProjects: funded,
            completedProjects: completed,
            totalFundsRaised: totalRaised,
            totalDonations: totalDonations,
            totalDonors: totalDonors
        });
    }

    /**
     * @dev Get all project IDs
     * @return Array of project IDs
     */
    function getAllProjectIds() external view returns (uint256[] memory) {
        return _allProjectIds;
    }

    /**
     * @dev Get project IDs by status
     * @param status Project status to filter by
     * @return projectIds Array of matching project IDs
     */
    function getProjectsByStatus(
        IAquaFundProject.ProjectStatus status
    ) external view returns (uint256[] memory projectIds) {
        uint256 totalProjects = _allProjectIds.length;
        uint256[] memory temp = new uint256[](totalProjects);
        uint256 count = 0;

        for (uint256 i = 0; i < totalProjects; ) {
            address projectAddr = factory.getProjectAddress(_allProjectIds[i]);
            if (projectAddr != address(0)) {
                AquaFundProject project = AquaFundProject(payable(projectAddr));
                IAquaFundProject.ProjectInfo memory info = project
                    .getProjectInfo();

                if (info.status == status) {
                    temp[count] = _allProjectIds[i];
                    count++;
                }
            }
            unchecked {
                ++i;
            }
        }

        // Resize array
        projectIds = new uint256[](count);
        for (uint256 i = 0; i < count; ) {
            projectIds[i] = temp[i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Get project details by ID
     * @param projectId Project ID
     * @return info Project information
     */
    function getProjectDetails(
        uint256 projectId
    )
        external
        view
        returns (IAquaFundProject.ProjectInfo memory info)
    {
        address projectAddr = factory.getProjectAddress(projectId);
        if (projectAddr == address(0)) revert ProjectNotFound();

        AquaFundProject project = AquaFundProject(payable(projectAddr));
        return project.getProjectInfo();
    }

    /**
     * @dev Get paginated project list
     * @param offset Starting index
     * @param limit Number of projects to return
     * @return projectIds Array of project IDs
     * @return addresses Array of project addresses
     */
    function getProjectsPaginated(
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (uint256[] memory projectIds, address[] memory addresses)
    {
        uint256 total = _allProjectIds.length;
        if (offset >= total) {
            return (new uint256[](0), new address[](0));
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 length = end - offset;
        projectIds = new uint256[](length);
        addresses = new address[](length);

        for (uint256 i = 0; i < length; ) {
            uint256 projectId = _allProjectIds[offset + i];
            projectIds[i] = projectId;
            addresses[i] = factory.getProjectAddress(projectId);
            unchecked {
                ++i;
            }
        }
    }
}

