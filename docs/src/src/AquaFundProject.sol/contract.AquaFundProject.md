# AquaFundProject
[Git Source](https://github.com/Goodness5/aquafund-smartcontract/blob/2730f0939dd1d28182cbb1f4ef5f036df4217246/src/AquaFundProject.sol)

**Inherits:**
[IAquaFundProject](/src/interfaces/IAquaFundProject.sol/interface.IAquaFundProject.md), ReentrancyGuard, Ownable

This contract uses the minimal proxy pattern (EIP-1167) for gas efficiency

*Cloneable project contract for managing individual water funding projects*


## State Variables
### _projectInfo

```solidity
ProjectInfo private _projectInfo;
```


### factory

```solidity
IAquaFundFactory public factory;
```


### _donations

```solidity
mapping(address => uint256) private _donations;
```


### _ethDonations

```solidity
mapping(address => uint256) private _ethDonations;
```


### _tokenDonations

```solidity
mapping(address => uint256) private _tokenDonations;
```


### _donors

```solidity
address[] private _donors;
```


### _evidence

```solidity
Evidence[] private _evidence;
```


### _initialized

```solidity
bool private _initialized;
```


### MIN_DONATION

```solidity
uint256 public constant MIN_DONATION = 0.001 ether;
```


## Functions
### onlyFactory


```solidity
modifier onlyFactory();
```

### onlyAdmin


```solidity
modifier onlyAdmin();
```

### onlyWhenInitialized


```solidity
modifier onlyWhenInitialized();
```

### constructor


```solidity
constructor() Ownable(msg.sender);
```

### initialize

*Initialize the project (called by factory)*


```solidity
function initialize(uint256 _projectId, address _admin, uint256 _fundingGoal, bytes32 _metadataUri) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_projectId`|`uint256`|Unique project identifier|
|`_admin`|`address`|Project administrator address|
|`_fundingGoal`|`uint256`|Funding goal in wei|
|`_metadataUri`|`bytes32`|IPFS hash for project metadata|


### donate

*Accept ETH donations*


```solidity
function donate() external payable nonReentrant onlyWhenInitialized;
```

### _handleEthDonation

*Internal function to handle ETH donations*


```solidity
function _handleEthDonation() internal;
```

### donateToken

*Accept ERC20 token donations*


```solidity
function donateToken(address token, uint256 amount) external nonReentrant onlyWhenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token contract address|
|`amount`|`uint256`|Amount to donate|


### _processDonation

*Process donation internally (gas optimization)*


```solidity
function _processDonation(address donor, uint256 amount, bool isEth) private;
```

### releaseFunds

*Release funds to project admin (10% service fee deducted)*


```solidity
function releaseFunds() external nonReentrant onlyAdmin onlyWhenInitialized;
```

### submitEvidence

*Submit evidence for project completion*


```solidity
function submitEvidence(bytes32 _evidenceHash) external onlyAdmin onlyWhenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_evidenceHash`|`bytes32`|IPFS hash of evidence (bytes32)|


### updateStatus

*Update project status*


```solidity
function updateStatus(ProjectStatus _newStatus) external onlyAdmin onlyWhenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newStatus`|`ProjectStatus`|New status to set|


### refundDonor

*Refund a specific donor*


```solidity
function refundDonor(address donor) external nonReentrant onlyAdmin onlyWhenInitialized;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`donor`|`address`|Address of donor to refund|


### refundAllDonors

*Refund all donors (emergency function)*


```solidity
function refundAllDonors() external nonReentrant onlyAdmin onlyWhenInitialized;
```

### getProjectInfo

*Get project information*


```solidity
function getProjectInfo() external view onlyWhenInitialized returns (ProjectInfo memory);
```

### getTotalDonations

*Get total donations received*


```solidity
function getTotalDonations() external view onlyWhenInitialized returns (uint256);
```

### getDonationCount

*Get number of unique donors*


```solidity
function getDonationCount() external view onlyWhenInitialized returns (uint256);
```

### getDonation

*Get donation amount for a specific donor*


```solidity
function getDonation(address donor) external view onlyWhenInitialized returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`donor`|`address`|Address of donor|


### getEvidenceCount

*Get number of evidence submissions*


```solidity
function getEvidenceCount() external view onlyWhenInitialized returns (uint256);
```

### getDonors

*Get all donors*


```solidity
function getDonors() external view onlyWhenInitialized returns (address[] memory);
```

### getEvidence

*Get evidence at index*


```solidity
function getEvidence(uint256 index) external view onlyWhenInitialized returns (Evidence memory);
```

### receive

*Receive ETH - automatically processes donation*


```solidity
receive() external payable nonReentrant;
```

## Errors
### AlreadyInitialized

```solidity
error AlreadyInitialized();
```

### NotInitialized

```solidity
error NotInitialized();
```

### InvalidProjectId

```solidity
error InvalidProjectId();
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidAddress

```solidity
error InvalidAddress();
```

### FundingGoalNotReached

```solidity
error FundingGoalNotReached();
```

### FundsAlreadyReleased

```solidity
error FundsAlreadyReleased();
```

### UnauthorizedAccess

```solidity
error UnauthorizedAccess();
```

### InvalidStatusTransition

```solidity
error InvalidStatusTransition();
```

### NoDonationsToRefund

```solidity
error NoDonationsToRefund();
```

### TransferFailed

```solidity
error TransferFailed();
```

### TokenNotAllowed

```solidity
error TokenNotAllowed();
```

