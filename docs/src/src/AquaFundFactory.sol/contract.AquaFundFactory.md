# AquaFundFactory
[Git Source](https://github.com/Goodness5/aquafund-smartcontract/blob/2730f0939dd1d28182cbb1f4ef5f036df4217246/src/AquaFundFactory.sol)

**Inherits:**
[IAquaFundFactory](/src/interfaces/IAquaFundFactory.sol/interface.IAquaFundFactory.md), Ownable, AccessControl, Pausable

Uses EIP-1167 minimal proxy (clone) pattern for gas-efficient project creation

*Factory contract for creating AquaFund projects using minimal proxy pattern*


## State Variables
### ADMIN_ROLE

```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
```


### PROJECT_CREATOR_ROLE

```solidity
bytes32 public constant PROJECT_CREATOR_ROLE = keccak256("PROJECT_CREATOR_ROLE");
```


### IMPLEMENTATION

```solidity
AquaFundProject public immutable IMPLEMENTATION;
```


### badgeContract

```solidity
IAquaFundBadge public badgeContract;
```


### registry

```solidity
AquaFundRegistry public registry;
```


### _projects

```solidity
mapping(uint256 => address) private _projects;
```


### isAdmin

```solidity
mapping(address => bool) public isAdmin;
```


### _projectCounter

```solidity
uint256 private _projectCounter;
```


### serviceFee

```solidity
uint256 public serviceFee;
```


### treasury

```solidity
address public treasury;
```


### totalDonated

```solidity
mapping(address => uint256) public totalDonated;
```


### _allDonors

```solidity
address[] private _allDonors;
```


### totalDonationsCount

```solidity
uint256 public totalDonationsCount;
```


### totalFundsRaised

```solidity
uint256 public totalFundsRaised;
```


### allowedTokens

```solidity
mapping(address => bool) public allowedTokens;
```


### _allowedTokensList

```solidity
address[] private _allowedTokensList;
```


### allowAllTokens

```solidity
bool public allowAllTokens;
```


## Functions
### constructor

*Constructor*


```solidity
constructor(address _implementation, address _treasury, uint256 _serviceFee) Ownable(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_implementation`|`address`|Implementation contract address for cloning|
|`_treasury`|`address`|Treasury address for service fees|
|`_serviceFee`|`uint256`|Service fee in basis points (1000 = 10%)|


### createProject

*Create a new project using minimal proxy*


```solidity
function createProject(address admin, uint256 fundingGoal, bytes32 metadataURI)
    external
    whenNotPaused
    onlyRole(PROJECT_CREATOR_ROLE)
    returns (address projectAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Project administrator address|
|`fundingGoal`|`uint256`|Funding goal in wei|
|`metadataURI`|`bytes32`|IPFS hash for project metadata|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`projectAddress`|`address`|Address of the created project|


### getProjectAddress

*Get project address by ID*


```solidity
function getProjectAddress(uint256 projectId) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|Project identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Project contract address|


### getTotalProjects

*Get total number of projects created*


```solidity
function getTotalProjects() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total project count|


### updateServiceFee

*Update service fee (only owner)*


```solidity
function updateServiceFee(uint256 _newFee) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newFee`|`uint256`|New service fee in basis points|


### updateTreasury

*Update treasury address (only owner)*


```solidity
function updateTreasury(address _newTreasury) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newTreasury`|`address`|New treasury address|


### setBadgeContract

*Set badge contract address and grant factory MINTER_ROLE*


```solidity
function setBadgeContract(address _badgeContract) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_badgeContract`|`address`|Badge contract address|


### setRegistry

*Set registry contract address*


```solidity
function setRegistry(address _registry) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_registry`|`address`|Registry contract address|


### updateAdminStatus

*Update admin verification status*


```solidity
function updateAdminStatus(address admin, bool status) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Admin address|
|`status`|`bool`|Verification status|


### grantProjectCreatorRole

*Grant project creator role*


```solidity
function grantProjectCreatorRole(address account) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to grant role|


### revokeProjectCreatorRole

*Revoke project creator role*


```solidity
function revokeProjectCreatorRole(address account) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to revoke role|


### pause

*Pause project creation*


```solidity
function pause() external onlyRole(ADMIN_ROLE);
```

### unpause

*Unpause project creation*


```solidity
function unpause() external onlyRole(ADMIN_ROLE);
```

### getServiceFee

*Get service fee*


```solidity
function getServiceFee() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Service fee in basis points|


### getTreasury

*Get treasury address*


```solidity
function getTreasury() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Treasury address|


### getProjectsRange

*Get all project IDs for a range (for pagination)*


```solidity
function getProjectsRange(uint256 start, uint256 end)
    external
    view
    returns (uint256[] memory projectIds, address[] memory addresses);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`start`|`uint256`|Starting index|
|`end`|`uint256`|Ending index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`projectIds`|`uint256[]`|Array of project IDs|
|`addresses`|`address[]`|Array of project addresses|


### recordDonation

*Record donation globally (called by project contracts)*


```solidity
function recordDonation(address donor, uint256 projectId, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`donor`|`address`|Donor address|
|`projectId`|`uint256`|Project ID|
|`amount`|`uint256`|Donation amount|


### getTotalDonated

*Get total amount donated by a specific donor*


```solidity
function getTotalDonated(address donor) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`donor`|`address`|Donor address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total amount donated across all projects|


### getLeaderboard

This is a view function but may be gas-intensive for large datasets

Consider using off-chain indexing for better performance

*Get leaderboard (sorted by total donations descending)*


```solidity
function getLeaderboard(uint256 start, uint256 end)
    external
    view
    returns (address[] memory donors, uint256[] memory amounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`start`|`uint256`|Starting index (0-based)|
|`end`|`uint256`|Ending index (exclusive)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`donors`|`address[]`|Array of donor addresses|
|`amounts`|`uint256[]`|Array of total donation amounts|


### getTotalDonors

*Get total number of unique donors*


```solidity
function getTotalDonors() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Number of unique donors|


### getPlatformStats

*Get platform-wide statistics*


```solidity
function getPlatformStats()
    external
    view
    returns (uint256 totalProjects, uint256 totalRaised, uint256 totalDonors_, uint256 totalDonations);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalProjects`|`uint256`|Total number of projects|
|`totalRaised`|`uint256`|Total funds raised|
|`totalDonors_`|`uint256`|Total unique donors|
|`totalDonations`|`uint256`|Total donation count|


### isTokenAllowed

*Check if a token is allowed for donations*


```solidity
function isTokenAllowed(address token) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address (address(0) for ETH is always allowed)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if token is allowed|


### addAllowedToken

*Add a token to the allowlist*


```solidity
function addAllowedToken(address token) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token contract address|


### removeAllowedToken

*Remove a token from the allowlist*


```solidity
function removeAllowedToken(address token) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token contract address|


### getAllowedTokens

*Get all allowed tokens*


```solidity
function getAllowedTokens() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of allowed token addresses|


### setAllowAllTokens

*Set whether to allow all tokens (use with extreme caution)*


```solidity
function setAllowAllTokens(bool _allowAllTokens) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_allowAllTokens`|`bool`|True to allow all tokens, false to use allowlist|


### mintBadgeForDonor

This should be called by backend after:
1. Listening to DonationReceived event
2. Generating badge metadata JSON
3. Uploading to IPFS
4. Getting IPFS URI

*Mint badge for donor (called by backend after IPFS upload)*


```solidity
function mintBadgeForDonor(address donor, uint256 projectId, uint256 donationAmount, string memory tokenURI) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`donor`|`address`|Donor address|
|`projectId`|`uint256`|Project ID|
|`donationAmount`|`uint256`|Total donation amount for tier calculation|
|`tokenURI`|`string`|IPFS URI for badge metadata (generated by backend)|


## Errors
### InvalidAddress

```solidity
error InvalidAddress();
```

### InvalidFee

```solidity
error InvalidFee();
```

### InvalidImplementation

```solidity
error InvalidImplementation();
```

### ProjectNotExists

```solidity
error ProjectNotExists();
```

### UnauthorizedAccess

```solidity
error UnauthorizedAccess();
```

### TokenNotAllowed

```solidity
error TokenNotAllowed();
```

