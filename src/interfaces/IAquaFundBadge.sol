// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAquaFundBadge
 * @dev Interface for AquaFund Badge (NFT) contract
 */
interface IAquaFundBadge {
    struct BadgeMetadata {
        uint128 projectId;        // slot 0 (16 bytes)
        uint128 donationAmount;   // slot 0 (16 bytes) - fits with projectId
        uint64 timestamp;         // slot 1 (8 bytes)
        bytes4 tier;             // slot 1 (4 bytes) - encoded tier (fits with timestamp)
        // Packed into 2 slots instead of 4+
    }

    event BadgeMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 indexed projectId,
        bytes4 tier,
        uint256 donationAmount
    );

    function mintBadge(
        address to,
        uint256 projectId,
        uint256 donationAmount,
        string memory uri
    ) external returns (uint256 tokenId);

    function getBadgeMetadata(
        uint256 tokenId
    ) external view returns (BadgeMetadata memory);

    function getUserBadges(
        address user
    ) external view returns (uint256[] memory);
}

