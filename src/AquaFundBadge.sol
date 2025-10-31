// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAquaFundBadge} from "./interfaces/IAquaFundBadge.sol";

/**
 * @title AquaFundBadge
 * @dev ERC721 NFT contract for donor badges/rewards
 * @notice Mints badges to donors based on donation tiers
 */
contract AquaFundBadge is
    ERC721,
    ERC721URIStorage,
    AccessControl,
    Ownable,
    IAquaFundBadge
{
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Token tracking
    uint256 private _tokenIdCounter;
    mapping(uint256 => BadgeMetadata) private _badgeMetadata;
    mapping(address => uint256[]) private _userBadges;

    // Tier thresholds (in wei)
    uint256 public constant BRONZE_THRESHOLD = 0.1 ether;
    uint256 public constant SILVER_THRESHOLD = 1 ether;
    uint256 public constant GOLD_THRESHOLD = 10 ether;
    uint256 public constant PLATINUM_THRESHOLD = 100 ether;

    // Base URI for metadata
    string private _baseTokenUri;

    // Custom errors
    error UnauthorizedMinter();
    error InvalidTokenId();
    error InvalidAddress();

    /**
     * @dev Constructor
     * @param name Token name
     * @param symbol Token symbol
     * @param baseTokenURI Base URI for token metadata
     * @param minter Address with minting permissions (usually factory)
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        address minter
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenUri = baseTokenURI;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, minter);
    }

    /**
     * @dev Mint a badge to a donor
     * @param to Recipient address
     * @param projectId Project ID associated with donation
     * @param donationAmount Donation amount (determines tier)
     * @param uri IPFS URI for the badge metadata (set externally)
     * @return tokenId Minted token ID
     */
    function mintBadge(
        address to,
        uint256 projectId,
        uint256 donationAmount,
        string memory uri
    ) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        if (to == address(0)) revert InvalidAddress();

        tokenId = ++_tokenIdCounter;

        // Determine tier based on donation amount
        bytes4 tierBytes = _getTierBytes(donationAmount);

        // Store metadata (use packed struct)
        _badgeMetadata[tokenId] = BadgeMetadata({
            projectId: uint128(projectId),
            donationAmount: uint128(donationAmount > type(uint128).max ? type(uint128).max : donationAmount),
            timestamp: uint64(block.timestamp),
            tier: tierBytes
        });

        // Mint token
        _safeMint(to, tokenId);

        // Track user badges
        _userBadges[to].push(tokenId);

        // Set token URI (provided externally, typically from IPFS)
        _setTokenURI(tokenId, uri);

        emit BadgeMinted(to, tokenId, projectId, tierBytes, donationAmount);

        return tokenId;
    }

    /**
     * @dev Get badge metadata
     * @param tokenId Token ID
     * @return Badge metadata
     */
    function getBadgeMetadata(
        uint256 tokenId
    ) external view returns (BadgeMetadata memory) {
        // ownerOf will revert if token doesn't exist
        ownerOf(tokenId);
        return _badgeMetadata[tokenId];
    }

    /**
     * @dev Get all badges for a user
     * @param user User address
     * @return Array of token IDs
     */
    function getUserBadges(
        address user
    ) external view returns (uint256[] memory) {
        return _userBadges[user];
    }

    /**
     * @dev Get user badge count
     * @param user User address
     * @return Badge count
     */
    function getUserBadgeCount(address user) external view returns (uint256) {
        return _userBadges[user].length;
    }

    /**
     * @dev Get tier bytes4 encoding based on donation amount
     * @param amount Donation amount
     * @return Tier as bytes4
     */
    function _getTierBytes(uint256 amount) internal pure returns (bytes4) {
        if (amount >= PLATINUM_THRESHOLD) {
            return bytes4("PLAT");
        } else if (amount >= GOLD_THRESHOLD) {
            return bytes4("GOLD");
        } else if (amount >= SILVER_THRESHOLD) {
            return bytes4("SILV");
        } else {
            return bytes4("BRNZ");
        }
    }

    /**
     * @dev Get tier string based on donation amount
     * @param amount Donation amount
     * @return Tier name
     */
    function _getTier(uint256 amount) internal pure returns (string memory) {
        if (amount >= PLATINUM_THRESHOLD) {
            return "Platinum";
        } else if (amount >= GOLD_THRESHOLD) {
            return "Gold";
        } else if (amount >= SILVER_THRESHOLD) {
            return "Silver";
        } else {
            return "Bronze";
        }
    }

    /**
     * @dev Update base token URI
     * @param baseUri New base URI
     */
    function setBaseURI(string memory baseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenUri = baseUri;
    }

    /**
     * @dev Override base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenUri;
    }

    /**
     * @dev Token URI override
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Support interface override
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Override transfer to update user badges tracking
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);

        if (previousOwner != address(0) && previousOwner != to) {
            // Remove from previous owner's list
            uint256[] storage prevBadges = _userBadges[previousOwner];
            uint256 length = prevBadges.length;
            for (uint256 i = 0; i < length; ) {
                if (prevBadges[i] == tokenId) {
                    prevBadges[i] = prevBadges[length - 1];
                    prevBadges.pop();
                    break;
                }
                unchecked {
                    ++i;
                }
            }

            // Add to new owner's list
            _userBadges[to].push(tokenId);
        }

        return previousOwner;
    }

    /**
     * @dev Convert uint256 to string (helper)
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

