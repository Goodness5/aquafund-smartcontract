// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAquaFundProject
 * @dev Interface for AquaFund Project contracts
 */
interface IAquaFundProject {
    enum ProjectStatus {
        Active,
        Funded,
        Completed,
        Cancelled,
        Refunded
    }

    struct ProjectInfo {
        uint128 projectId;        // slot 0 (16 bytes)
        address admin;            // slot 0 (20 bytes) - fits with uint128 (36 bytes total, uses 2 slots)
        uint256 fundingGoal;      // slot 1 (32 bytes)
        uint256 fundsRaised;      // slot 2 (32 bytes)
        ProjectStatus status;     // slot 3 (1 byte)
        bytes32 metadataUri;      // slot 4 (32 bytes) - IPFS hash as bytes32
        // Note: projectId could be uint256 if > 2^128 projects needed
        // Current packing: 5 slots total (can't pack status with bytes32 as they're different types in storage)
    }

    struct Donation {
        address donor;            // slot 0 (20 bytes)
        uint128 amount;           // slot 0 (16 bytes, fits with address)
        uint64 timestamp;         // slot 0 (8 bytes, fits with above)
        bool inEth;               // slot 0 (1 byte)
        // Packed into single slot!
    }

    struct Evidence {
        bytes32 evidenceHash;     // slot 0 (IPFS hash as bytes32)
        uint64 timestamp;         // slot 1 (8 bytes)
        address submitter;        // slot 1 (20 bytes, fits with uint64)
        // Packed into 2 slots instead of 3+
    }

    event ProjectInitialized(
        uint256 indexed projectId,
        address indexed admin,
        uint256 fundingGoal,
        bytes32 metadataUri
    );

    event DonationReceived(
        uint256 indexed projectId,
        address indexed donor,
        uint256 amount,
        bool inEth,
        uint256 timestamp
    );

    event FundsReleased(
        uint256 indexed projectId,
        address indexed recipient,
        uint256 amount,
        uint256 serviceFee
    );

    event EvidenceSubmitted(
        uint256 indexed projectId,
        bytes32 indexed evidenceHash,
        address indexed submitter,
        uint256 timestamp
    );

    event ProjectStatusChanged(
        uint256 indexed projectId,
        ProjectStatus oldStatus,
        ProjectStatus newStatus
    );

    event RefundIssued(
        uint256 indexed projectId,
        address indexed donor,
        uint256 amount
    );

    function initialize(
        uint256 _projectId,
        address _admin,
        uint256 _fundingGoal,
        bytes32 _metadataUri
    ) external;

    function donate() external payable;

    function donateToken(address token, uint256 amount) external;

    function releaseFunds() external;

    function submitEvidence(bytes32 _evidenceHash) external;

    function updateStatus(ProjectStatus _newStatus) external;

    function refundDonor(address donor) external;

    function refundAllDonors() external;

    function getProjectInfo() external view returns (ProjectInfo memory);

    function getTotalDonations() external view returns (uint256);

    function getDonationCount() external view returns (uint256);

    function getDonation(address donor) external view returns (uint256);

    function getEvidenceCount() external view returns (uint256);
}

