# IAquaFundFactory
[Git Source](https://github.com/Goodness5/aquafund-smartcontract/blob/2730f0939dd1d28182cbb1f4ef5f036df4217246/src/interfaces/IAquaFundFactory.sol)

*Interface for AquaFund Factory contract*


## Functions
### createProject


```solidity
function createProject(address admin, uint256 fundingGoal, bytes32 metadataUri)
    external
    returns (address projectAddress);
```

### recordDonation


```solidity
function recordDonation(address donor, uint256 projectId, uint256 amount) external;
```

### getTotalDonated


```solidity
function getTotalDonated(address donor) external view returns (uint256);
```

### getLeaderboard


```solidity
function getLeaderboard(uint256 start, uint256 end)
    external
    view
    returns (address[] memory donors, uint256[] memory amounts);
```

### getProjectAddress


```solidity
function getProjectAddress(uint256 projectId) external view returns (address);
```

### getTotalProjects


```solidity
function getTotalProjects() external view returns (uint256);
```

### isAdmin


```solidity
function isAdmin(address account) external view returns (bool);
```

### getServiceFee


```solidity
function getServiceFee() external view returns (uint256);
```

### getTreasury


```solidity
function getTreasury() external view returns (address);
```

### isTokenAllowed


```solidity
function isTokenAllowed(address token) external view returns (bool);
```

### addAllowedToken


```solidity
function addAllowedToken(address token) external;
```

### removeAllowedToken


```solidity
function removeAllowedToken(address token) external;
```

### getAllowedTokens


```solidity
function getAllowedTokens() external view returns (address[] memory);
```

## Events
### ProjectCreated

```solidity
event ProjectCreated(
    uint256 indexed projectId, address indexed projectAddress, address indexed admin, uint256 fundingGoal
);
```

### ServiceFeeUpdated

```solidity
event ServiceFeeUpdated(uint256 oldFee, uint256 newFee);
```

### TreasuryUpdated

```solidity
event TreasuryUpdated(address oldTreasury, address newTreasury);
```

### AdminStatusUpdated

```solidity
event AdminStatusUpdated(address indexed admin, bool status);
```

### TokenAllowed

```solidity
event TokenAllowed(address indexed token, bool allowed);
```

### GlobalDonationReceived

```solidity
event GlobalDonationReceived(
    address indexed donor, uint256 indexed projectId, uint256 amount, uint256 totalDonated, uint256 timestamp
);
```

