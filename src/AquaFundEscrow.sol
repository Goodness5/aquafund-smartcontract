// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AquaFundEscrow
 * @dev Dedicated escrow contract for holding project funds
 * @notice Tracks all donations and ownership, separate from project logic
 */
contract AquaFundEscrow is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Project information
    uint256 public projectId;
    address public projectContract; // The project contract that owns this escrow
    address public projectAdmin; // NGO admin for the project
    address public platformAdmin; // Platform admin with oversight
    address public treasury; // Treasury address for service fees
    uint256 public serviceFeeBps; // Service fee in basis points

    // Donation tracking
    mapping(address => uint256) public ethDonations; // donor => ETH amount
    mapping(address => mapping(address => uint256)) public tokenDonations; // donor => token => amount
    mapping(address => uint256) public tokenBalances; // token => total balance
    address[] public donors; // Array of unique donors
    address[] public donatedTokens; // Array of token addresses that received donations

    // State
    bool public fundsReleased;
    bool public initialized;

    // Custom errors
    error NotInitialized();
    error AlreadyInitialized();
    error UnauthorizedAccess();
    error FundsAlreadyReleased();
    error InvalidAddress();
    error InvalidAmount();
    error TransferFailed();

    // Events
    event EscrowInitialized(
        uint256 indexed projectId,
        address indexed projectContract,
        address indexed projectAdmin,
        address platformAdmin
    );
    event EthDeposited(address indexed donor, uint256 amount);
    event TokenDeposited(address indexed donor, address indexed token, uint256 amount);
    event FundsReleased(
        address indexed recipient,
        uint256 ethAmount,
        uint256 serviceFee,
        address[] tokens,
        uint256[] tokenAmounts
    );
    event RefundIssued(address indexed donor, uint256 ethAmount, address[] tokens, uint256[] amounts);

    modifier onlyProjectOrAdmin() {
        if (msg.sender != projectContract && msg.sender != projectAdmin && msg.sender != platformAdmin) {
            revert UnauthorizedAccess();
        }
        _;
    }

    modifier onlyWhenInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Initialize the escrow contract
     * @param _projectId Project ID
     * @param _projectContract Address of the project contract (can be set later)
     * @param _projectAdmin NGO admin address
     * @param _platformAdmin Platform admin address with oversight
     * @param _treasury Treasury address for service fees
     * @param _serviceFeeBps Service fee in basis points
     */
    function initialize(
        uint256 _projectId,
        address _projectContract,
        address _projectAdmin,
        address _platformAdmin,
        address _treasury,
        uint256 _serviceFeeBps
    ) external {
        if (initialized) revert AlreadyInitialized();
        if (_projectAdmin == address(0)) revert InvalidAddress();
        if (_platformAdmin == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();

        projectId = _projectId;
        projectContract = _projectContract; // Can be address(0) initially, set later
        projectAdmin = _projectAdmin;
        platformAdmin = _platformAdmin;
        treasury = _treasury;
        serviceFeeBps = _serviceFeeBps;

        initialized = true;
        _transferOwnership(_projectAdmin); // Project admin is owner, but platform admin has oversight

        emit EscrowInitialized(_projectId, _projectContract, _projectAdmin, _platformAdmin);
    }

    /**
     * @dev Set project contract address (called after project creation)
     * @param _projectContract Address of the project contract
     */
    function setProjectContract(address _projectContract) external onlyOwner {
        if (_projectContract == address(0)) revert InvalidAddress();
        if (projectContract != address(0)) revert AlreadyInitialized(); // Can only set once
        projectContract = _projectContract;
    }

    /**
     * @dev Deposit ETH into escrow
     * @param donor Address of the donor
     */
    function depositEth(address donor) external payable nonReentrant onlyWhenInitialized {
        if (msg.value == 0) revert InvalidAmount();
        if (fundsReleased) revert FundsAlreadyReleased();
        if (msg.sender != projectContract) revert UnauthorizedAccess();

        bool isNewDonor = ethDonations[donor] == 0 && 
                          (donatedTokens.length == 0 || tokenDonations[donor][donatedTokens[0]] == 0);
        
        if (isNewDonor) {
            donors.push(donor);
        }

        ethDonations[donor] += msg.value;

        emit EthDeposited(donor, msg.value);
    }

    /**
     * @dev Deposit ERC20 tokens into escrow
     * @param donor Address of the donor
     * @param token Token contract address
     * @param amount Amount to deposit
     */
    function depositToken(
        address donor,
        address token,
        uint256 amount
    ) external nonReentrant onlyWhenInitialized {
        if (token == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (fundsReleased) revert FundsAlreadyReleased();
        if (msg.sender != projectContract) revert UnauthorizedAccess();

        // Transfer tokens from project contract (which received them from donor)
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        bool isNewDonor = ethDonations[donor] == 0 && tokenDonations[donor][token] == 0;
        bool isNewToken = tokenBalances[token] == 0;

        if (isNewDonor) {
            donors.push(donor);
        }
        if (isNewToken) {
            donatedTokens.push(token);
        }

        tokenDonations[donor][token] += amount;
        tokenBalances[token] += amount;

        emit TokenDeposited(donor, token, amount);
    }

    /**
     * @dev Release funds to project admin (with service fee to treasury)
     * Can be called by project admin or platform admin
     */
    function releaseFunds() external nonReentrant onlyWhenInitialized onlyProjectOrAdmin {
        if (fundsReleased) revert FundsAlreadyReleased();

        fundsReleased = true;

        uint256 ethBalance = address(this).balance;
        uint256 ethServiceFee = 0;
        uint256 ethNetAmount = 0;

        // Process ETH
        if (ethBalance > 0) {
            ethServiceFee = (ethBalance * serviceFeeBps) / 10000;
            ethNetAmount = ethBalance - ethServiceFee;

            // Transfer service fee to treasury
            if (ethServiceFee > 0 && treasury != address(0)) {
                (bool success, ) = payable(treasury).call{value: ethServiceFee}("");
                if (!success) revert TransferFailed();
            }

            // Transfer remaining to project admin
            if (ethNetAmount > 0) {
                (bool success, ) = payable(projectAdmin).call{value: ethNetAmount}("");
                if (!success) revert TransferFailed();
            }
        }

        // Process all tokens
        uint256 tokenCount = donatedTokens.length;
        address[] memory tokens = new address[](tokenCount);
        uint256[] memory tokenAmounts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; ) {
            address token = donatedTokens[i];
            uint256 tokenBalance = tokenBalances[token];
            
            if (tokenBalance > 0) {
                uint256 tokenServiceFee = (tokenBalance * serviceFeeBps) / 10000;
                uint256 tokenNetAmount = tokenBalance - tokenServiceFee;

                // Transfer service fee to treasury
                if (tokenServiceFee > 0 && treasury != address(0)) {
                    IERC20(token).safeTransfer(treasury, tokenServiceFee);
                }

                // Transfer remaining to project admin
                if (tokenNetAmount > 0) {
                    IERC20(token).safeTransfer(projectAdmin, tokenNetAmount);
                }

                tokens[i] = token;
                tokenAmounts[i] = tokenNetAmount;
            }

            unchecked {
                ++i;
            }
        }

        emit FundsReleased(projectAdmin, ethNetAmount, ethServiceFee, tokens, tokenAmounts);
    }

    /**
     * @dev Refund a specific donor
     * Can be called by project admin or platform admin
     */
    function refundDonor(address donor) external nonReentrant onlyWhenInitialized onlyProjectOrAdmin {
        if (fundsReleased) revert FundsAlreadyReleased();

        uint256 ethAmount = ethDonations[donor];
        if (ethAmount == 0 && tokenDonations[donor][donatedTokens.length > 0 ? donatedTokens[0] : address(0)] == 0) {
            revert InvalidAmount();
        }

        // Refund ETH
        if (ethAmount > 0) {
            ethDonations[donor] = 0;
            (bool success, ) = payable(donor).call{value: ethAmount}("");
            if (!success) revert TransferFailed();
        }

        // Refund tokens
        uint256 tokenCount = donatedTokens.length;
        address[] memory refundTokens = new address[](tokenCount);
        uint256[] memory refundAmounts = new uint256[](tokenCount);
        uint256 refundCount = 0;

        for (uint256 i = 0; i < tokenCount; ) {
            address token = donatedTokens[i];
            uint256 tokenAmount = tokenDonations[donor][token];
            
            if (tokenAmount > 0) {
                tokenDonations[donor][token] = 0;
                tokenBalances[token] -= tokenAmount;
                
                IERC20(token).safeTransfer(donor, tokenAmount);
                
                refundTokens[refundCount] = token;
                refundAmounts[refundCount] = tokenAmount;
                refundCount++;

                // Remove token if balance is zero
                if (tokenBalances[token] == 0) {
                    donatedTokens[i] = donatedTokens[tokenCount - 1];
                    donatedTokens.pop();
                    tokenCount--;
                    i--;
                }
            }

            unchecked {
                ++i;
            }
        }

        // Resize arrays
        assembly {
            mstore(refundTokens, refundCount)
            mstore(refundAmounts, refundCount)
        }

        emit RefundIssued(donor, ethAmount, refundTokens, refundAmounts);
    }

    /**
     * @dev Refund all donors
     * Can be called by project admin or platform admin
     */
    function refundAllDonors() external nonReentrant onlyWhenInitialized onlyProjectOrAdmin {
        if (fundsReleased) revert FundsAlreadyReleased();

        uint256 donorCount = donors.length;
        for (uint256 i = 0; i < donorCount; ) {
            address donor = donors[i];
            
            // Refund ETH
            uint256 ethAmount = ethDonations[donor];
            if (ethAmount > 0) {
                ethDonations[donor] = 0;
                (bool success, ) = payable(donor).call{value: ethAmount}("");
                if (!success) revert TransferFailed();
            }

            // Refund all tokens
            uint256 tokenCount = donatedTokens.length;
            for (uint256 j = 0; j < tokenCount; ) {
                address token = donatedTokens[j];
                uint256 tokenAmount = tokenDonations[donor][token];
                
                if (tokenAmount > 0) {
                    tokenDonations[donor][token] = 0;
                    tokenBalances[token] -= tokenAmount;
                    IERC20(token).safeTransfer(donor, tokenAmount);
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        // Clear all tracking
        delete donors;
        
        // Clear token balances
        uint256 remainingTokenCount = donatedTokens.length;
        for (uint256 i = 0; i < remainingTokenCount; ) {
            delete tokenBalances[donatedTokens[i]];
            unchecked {
                ++i;
            }
        }
        delete donatedTokens;
    }

    /**
     * @dev Get total ETH balance
     */
    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Get token balance
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    /**
     * @dev Get all donated tokens
     */
    function getDonatedTokens() external view returns (address[] memory) {
        return donatedTokens;
    }

    /**
     * @dev Get ETH donation for a donor
     */
    function getEthDonation(address donor) external view returns (uint256) {
        return ethDonations[donor];
    }

    /**
     * @dev Get token donation for a donor
     */
    function getTokenDonation(address donor, address token) external view returns (uint256) {
        return tokenDonations[donor][token];
    }

    /**
     * @dev Get all donors
     */
    function getDonors() external view returns (address[] memory) {
        return donors;
    }

    /**
     * @dev Receive ETH
     */
    receive() external payable {
        // Only accept ETH from project contract
        if (msg.sender != projectContract) {
            revert UnauthorizedAccess();
        }
    }
}
