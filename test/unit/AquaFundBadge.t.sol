// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AquaFundBadge} from "../../src/AquaFundBadge.sol";
import {AquaFundFactory} from "../../src/AquaFundFactory.sol";
import {IAquaFundBadge} from "../../src/interfaces/IAquaFundBadge.sol";

contract AquaFundBadgeTest is Test {
    AquaFundBadge public badge;
    AquaFundFactory public factory;

    address public admin = address(0x1);
    address public minter = address(0x2);
    address public recipient = address(0x3);

    function setUp() public {
        factory = AquaFundFactory(address(0x100)); // Mock factory
        
        badge = new AquaFundBadge(
            "AquaFund Badge",
            "AFB",
            "https://api.aquafund.io/badges/",
            minter
        );
    }

    function test_MintBadge() public {
        string memory tokenUri = "ipfs://QmTestHash";
        uint256 projectId = 1;
        uint256 donationAmount = 5 ether;

        vm.prank(minter);
        uint256 tokenId = badge.mintBadge(recipient, projectId, donationAmount, tokenUri);

        assertEq(badge.balanceOf(recipient), 1);
        assertEq(badge.ownerOf(tokenId), recipient);
        assertEq(badge.tokenURI(tokenId), tokenUri);
    }

    function test_MintBadge_TierClassification() public {
        vm.startPrank(minter);

        // Bronze tier (< 0.1 ETH)
        uint256 tokenId1 = badge.mintBadge(recipient, 1, 0.05 ether, "ipfs://bronze");
        IAquaFundBadge.BadgeMetadata memory meta1 = badge.getBadgeMetadata(tokenId1);
        assertEq(meta1.tier, bytes4("BRNZ"));

        // Silver tier (>= 0.1 ETH, < 1 ETH)
        uint256 tokenId2 = badge.mintBadge(recipient, 1, 0.5 ether, "ipfs://silver");
        IAquaFundBadge.BadgeMetadata memory meta2 = badge.getBadgeMetadata(tokenId2);
        assertEq(meta2.tier, bytes4("SILV"));

        // Gold tier (>= 1 ETH, < 100 ETH)
        uint256 tokenId3 = badge.mintBadge(recipient, 1, 5 ether, "ipfs://gold");
        IAquaFundBadge.BadgeMetadata memory meta3 = badge.getBadgeMetadata(tokenId3);
        assertEq(meta3.tier, bytes4("GOLD"));

        // Platinum tier (>= 100 ETH)
        uint256 tokenId4 = badge.mintBadge(recipient, 1, 100 ether, "ipfs://platinum");
        IAquaFundBadge.BadgeMetadata memory meta4 = badge.getBadgeMetadata(tokenId4);
        assertEq(meta4.tier, bytes4("PLAT"));

        vm.stopPrank();
    }

    function test_MintBadge_Unauthorized() public {
        vm.prank(address(0x999));
        vm.expectRevert();
        badge.mintBadge(recipient, 1, 1 ether, "ipfs://test");
    }

    function test_GetUserBadges() public {
        vm.startPrank(minter);

        badge.mintBadge(recipient, 1, 1 ether, "ipfs://1");
        badge.mintBadge(recipient, 2, 2 ether, "ipfs://2");
        badge.mintBadge(recipient, 3, 3 ether, "ipfs://3");

        vm.stopPrank();

        uint256[] memory badges = badge.getUserBadges(recipient);
        assertEq(badges.length, 3);
        assertEq(badge.getUserBadgeCount(recipient), 3);
    }

    function test_TransferBadge() public {
        address newOwner = address(0x4);

        vm.prank(minter);
        uint256 tokenId = badge.mintBadge(recipient, 1, 1 ether, "ipfs://test");

        vm.prank(recipient);
        badge.safeTransferFrom(recipient, newOwner, tokenId);

        assertEq(badge.ownerOf(tokenId), newOwner);
        assertEq(badge.balanceOf(recipient), 0);
        assertEq(badge.balanceOf(newOwner), 1);

        // Check badge tracking updated
        uint256[] memory recipientBadges = badge.getUserBadges(recipient);
        assertEq(recipientBadges.length, 0);

        uint256[] memory newOwnerBadges = badge.getUserBadges(newOwner);
        assertEq(newOwnerBadges.length, 1);
    }

    function test_GetBadgeMetadata() public {
        uint256 projectId = 5;
        uint256 donationAmount = 10 ether;
        string memory tokenUri = "ipfs://QmMetadataHash";

        vm.prank(minter);
        uint256 tokenId = badge.mintBadge(recipient, projectId, donationAmount, tokenUri);

        IAquaFundBadge.BadgeMetadata memory metadata = badge.getBadgeMetadata(tokenId);

        assertEq(metadata.projectId, projectId);
        assertEq(metadata.donationAmount, donationAmount);
        assertEq(metadata.tier, bytes4("GOLD"));
        assertTrue(metadata.timestamp > 0);
    }
}

