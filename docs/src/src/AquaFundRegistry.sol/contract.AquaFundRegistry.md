# AquaFundRegistry
[Git Source](https://github.com/Goodness5/aquafund-smartcontract/blob/2730f0939dd1d28182cbb1f4ef5f036df4217246/src/AquaFundRegistry.sol)

**Inherits:**
Ownable, AccessControl

Provides aggregated data and project discovery functionality

*Centralized registry for project management and analytics*


## State Variables
### VIEWER_ROLE

```solidity
bytes32 public constant VIEWER_ROLE = keccak256("VIEWER_ROLE");
```


### factory

```solidity
IAquaFundFactory public factory;
```


### _indexedProjects

```solidity
mapping(uint256 => bool) private _indexedProjects;
```


### _allProjectIds

```solidity
uint256[] private _allProjectIds;
```


## Functions
### constructor

*Constructor*


```solidity
constructor() Ownable(msg.sender);
```

### setFactory

*Set factory contract address*


```solidity
function setFactory(address _factory) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_factory`|`address`|Factory contract address|


### registerProject

*Register a new project (called by factory)*


```solidity
function registerProject(uint256 projectId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|Project ID|


### getPlatformStats

*Get platform statistics*


```solidity
function getPlatformStats() external view returns (PlatformStats memory stats);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stats`|`PlatformStats`|Platform statistics|


### getAllProjectIds

*Get all project IDs*


```solidity
function getAllProjectIds() external view returns (uint256[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|Array of project IDs|


### getProjectsByStatus

*Get project IDs by status*


```solidity
function getProjectsByStatus(IAquaFundProject.ProjectStatus status)
    external
    view
    returns (uint256[] memory projectIds);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`status`|`IAquaFundProject.ProjectStatus`|Project status to filter by|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`projectIds`|`uint256[]`|Array of matching project IDs|


### getProjectDetails

*Get project details by ID*


```solidity
function getProjectDetails(uint256 projectId) external view returns (IAquaFundProject.ProjectInfo memory info);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|Project ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`info`|`IAquaFundProject.ProjectInfo`|Project information|


### getProjectsPaginated

*Get paginated project list*


```solidity
function getProjectsPaginated(uint256 offset, uint256 limit)
    external
    view
    returns (uint256[] memory projectIds, address[] memory addresses);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`offset`|`uint256`|Starting index|
|`limit`|`uint256`|Number of projects to return|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`projectIds`|`uint256[]`|Array of project IDs|
|`addresses`|`address[]`|Array of project addresses|


## Errors
### InvalidAddress

```solidity
error InvalidAddress();
```

### ProjectNotFound

```solidity
error ProjectNotFound();
```

### UnauthorizedAccess

```solidity
error UnauthorizedAccess();
```

## Structs
### PlatformStats

```solidity
struct PlatformStats {
    uint256 totalProjects;
    uint256 activeProjects;
    uint256 fundedProjects;
    uint256 completedProjects;
    uint256 totalFundsRaised;
    uint256 totalDonations;
    uint256 totalDonors;
}
```

