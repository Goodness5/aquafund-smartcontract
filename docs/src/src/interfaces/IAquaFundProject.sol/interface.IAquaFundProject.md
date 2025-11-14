# IAquaFundProject
[Git Source](https://github.com/Goodness5/aquafund-smartcontract/blob/2730f0939dd1d28182cbb1f4ef5f036df4217246/src/interfaces/IAquaFundProject.sol)

*Interface for AquaFund Project contracts*


## Functions
### initialize


```solidity
function initialize(uint256 _projectId, address _admin, uint256 _fundingGoal, bytes32 _metadataUri) external;
```

### donate


```solidity
function donate() external payable;
```

### donateToken


```solidity
function donateToken(address token, uint256 amount) external;
```

### releaseFunds


```solidity
function releaseFunds() external;
```

### submitEvidence


```solidity
function submitEvidence(bytes32 _evidenceHash) external;
```

### updateStatus


```solidity
function updateStatus(ProjectStatus _newStatus) external;
```

### refundDonor


```solidity
function refundDonor(address donor) external;
```

### refundAllDonors


```solidity
function refundAllDonors() external;
```

### getProjectInfo


```solidity
function getProjectInfo() external view returns (ProjectInfo memory);
```

### getTotalDonations


```solidity
function getTotalDonations() external view returns (uint256);
```

### getDonationCount


```solidity
function getDonationCount() external view returns (uint256);
```

### getDonation


```solidity
function getDonation(address donor) external view returns (uint256);
```

### getEvidenceCount


```solidity
function getEvidenceCount() external view returns (uint256);
```

## Events
### ProjectInitialized

```solidity
event ProjectInitialized(uint256 indexed projectId, address indexed admin, uint256 fundingGoal, bytes32 metadataUri);
```

### DonationReceived

```solidity
event DonationReceived(uint256 indexed projectId, address indexed donor, uint256 amount, bool inEth, uint256 timestamp);
```

### FundsReleased

```solidity
event FundsReleased(uint256 indexed projectId, address indexed recipient, uint256 amount, uint256 serviceFee);
```

### EvidenceSubmitted

```solidity
event EvidenceSubmitted(
    uint256 indexed projectId, bytes32 indexed evidenceHash, address indexed submitter, uint256 timestamp
);
```

### ProjectStatusChanged

```solidity
event ProjectStatusChanged(uint256 indexed projectId, ProjectStatus oldStatus, ProjectStatus newStatus);
```

### RefundIssued

```solidity
event RefundIssued(uint256 indexed projectId, address indexed donor, uint256 amount);
```

## Structs
### ProjectInfo

```solidity
struct ProjectInfo {
    uint128 projectId;
    address admin;
    uint256 fundingGoal;
    uint256 fundsRaised;
    ProjectStatus status;
    bytes32 metadataUri;
}
```

### Donation

```solidity
struct Donation {
    address donor;
    uint128 amount;
    uint64 timestamp;
    bool inEth;
}
```

### Evidence

```solidity
struct Evidence {
    bytes32 evidenceHash;
    uint64 timestamp;
    address submitter;
}
```

## Enums
### ProjectStatus

```solidity
enum ProjectStatus {
    Active,
    Funded,
    Completed,
    Cancelled,
    Refunded
}
```

