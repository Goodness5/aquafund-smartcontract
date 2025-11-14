# IAquaFundBadge
[Git Source](https://github.com/Goodness5/aquafund-smartcontract/blob/2730f0939dd1d28182cbb1f4ef5f036df4217246/src/interfaces/IAquaFundBadge.sol)

*Interface for AquaFund Badge (NFT) contract*


## Functions
### mintBadge


```solidity
function mintBadge(address to, uint256 projectId, uint256 donationAmount, string memory uri)
    external
    returns (uint256 tokenId);
```

### getBadgeMetadata


```solidity
function getBadgeMetadata(uint256 tokenId) external view returns (BadgeMetadata memory);
```

### getUserBadges


```solidity
function getUserBadges(address user) external view returns (uint256[] memory);
```

## Events
### BadgeMinted

```solidity
event BadgeMinted(
    address indexed to, uint256 indexed tokenId, uint256 indexed projectId, bytes4 tier, uint256 donationAmount
);
```

## Structs
### BadgeMetadata

```solidity
struct BadgeMetadata {
    uint128 projectId;
    uint128 donationAmount;
    uint64 timestamp;
    bytes4 tier;
}
```

