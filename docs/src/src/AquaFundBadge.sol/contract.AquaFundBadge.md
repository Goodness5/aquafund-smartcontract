# AquaFundBadge
[Git Source](https://github.com/Goodness5/aquafund-smartcontract/blob/2730f0939dd1d28182cbb1f4ef5f036df4217246/src/AquaFundBadge.sol)

**Inherits:**
ERC721, ERC721URIStorage, AccessControl, Ownable, [IAquaFundBadge](/src/interfaces/IAquaFundBadge.sol/interface.IAquaFundBadge.md)

Mints badges to donors based on donation tiers

*ERC721 NFT contract for donor badges/rewards*


## State Variables
### MINTER_ROLE

```solidity
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
```


### _tokenIdCounter

```solidity
uint256 private _tokenIdCounter;
```


### _badgeMetadata

```solidity
mapping(uint256 => BadgeMetadata) private _badgeMetadata;
```


### _userBadges

```solidity
mapping(address => uint256[]) private _userBadges;
```


### BRONZE_THRESHOLD

```solidity
uint256 public constant BRONZE_THRESHOLD = 0.1 ether;
```


### SILVER_THRESHOLD

```solidity
uint256 public constant SILVER_THRESHOLD = 1 ether;
```


### GOLD_THRESHOLD

```solidity
uint256 public constant GOLD_THRESHOLD = 10 ether;
```


### PLATINUM_THRESHOLD

```solidity
uint256 public constant PLATINUM_THRESHOLD = 100 ether;
```


### _baseTokenUri

```solidity
string private _baseTokenUri;
```


## Functions
### constructor

*Constructor*


```solidity
constructor(string memory name, string memory symbol, string memory baseTokenURI, address minter)
    ERC721(name, symbol)
    Ownable(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|Token name|
|`symbol`|`string`|Token symbol|
|`baseTokenURI`|`string`|Base URI for token metadata|
|`minter`|`address`|Address with minting permissions (usually factory)|


### mintBadge

*Mint a badge to a donor*


```solidity
function mintBadge(address to, uint256 projectId, uint256 donationAmount, string memory uri)
    external
    onlyRole(MINTER_ROLE)
    returns (uint256 tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient address|
|`projectId`|`uint256`|Project ID associated with donation|
|`donationAmount`|`uint256`|Donation amount (determines tier)|
|`uri`|`string`|IPFS URI for the badge metadata (set externally)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|Minted token ID|


### getBadgeMetadata

*Get badge metadata*


```solidity
function getBadgeMetadata(uint256 tokenId) external view returns (BadgeMetadata memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|Token ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BadgeMetadata`|Badge metadata|


### getUserBadges

*Get all badges for a user*


```solidity
function getUserBadges(address user) external view returns (uint256[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|Array of token IDs|


### getUserBadgeCount

*Get user badge count*


```solidity
function getUserBadgeCount(address user) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Badge count|


### _getTierBytes

*Get tier bytes4 encoding based on donation amount*


```solidity
function _getTierBytes(uint256 amount) internal pure returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Donation amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|Tier as bytes4|


### _getTier

*Get tier string based on donation amount*


```solidity
function _getTier(uint256 amount) internal pure returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Donation amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Tier name|


### setBaseURI

*Update base token URI*


```solidity
function setBaseURI(string memory baseUri) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseUri`|`string`|New base URI|


### _baseURI

*Override base URI*


```solidity
function _baseURI() internal view override returns (string memory);
```

### tokenURI

*Token URI override*


```solidity
function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory);
```

### supportsInterface

*Support interface override*


```solidity
function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721URIStorage, AccessControl)
    returns (bool);
```

### _update

*Override transfer to update user badges tracking*


```solidity
function _update(address to, uint256 tokenId, address auth) internal override returns (address);
```

### _toString

*Convert uint256 to string (helper)*


```solidity
function _toString(uint256 value) internal pure returns (string memory);
```

## Errors
### UnauthorizedMinter

```solidity
error UnauthorizedMinter();
```

### InvalidTokenId

```solidity
error InvalidTokenId();
```

### InvalidAddress

```solidity
error InvalidAddress();
```

