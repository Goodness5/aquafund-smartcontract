# AquaFund Smart Contracts

Production-ready smart contracts for AquaFund - A Decentralized Water Crowdfunding Platform.

## Overview

AquaFund is a blockchain-based crowdfunding platform designed to address the global water crisis by connecting donors directly to communities in need of clean and accessible water. The platform ensures transparency, traceability, and impact verification through on-chain donations and project tracking.

## Architecture

### Core Contracts

1. **AquaFundProject** - Cloneable project contract managing individual water funding projects
2. **AquaFundFactory** - Factory contract using minimal proxy pattern (EIP-1167) for gas-efficient project creation
3. **AquaFundBadge** - ERC721 NFT contract for donor rewards and recognition
4. **AquaFundRegistry** - Centralized registry for project management and analytics

### Key Features

- ✅ **Gas Optimized**: Uses minimal proxy pattern (EIP-1167) for project creation
- ✅ **Production Ready**: OpenZeppelin security standards, reentrancy guards, access control
- ✅ **Multi-token Support**: Accepts ETH and ERC20 tokens (USDC, etc.)
- ✅ **Donor Rewards**: Automatic badge/NFT minting based on donation tiers
- ✅ **Transparency**: All transactions and project updates on-chain
- ✅ **Flexible Fees**: Configurable service fee (default 10%)
- ✅ **Evidence Tracking**: On-chain evidence submission for project verification

## Contract Details

### AquaFundProject

Cloneable contract for individual projects with:
- Donation handling (ETH and ERC20 tokens)
- Fund escrow until funding goal reached
- Automatic status updates
- Evidence submission
- Refund mechanisms for cancelled projects

### AquaFundFactory

Factory contract that:
- Creates project clones using minimal proxy pattern
- Manages project creator roles
- Configures service fees and treasury
- Integrates with badge and registry contracts

### AquaFundBadge

ERC721 NFT contract that:
- Mints badges automatically on donations
- Supports tier-based badges (Bronze, Silver, Gold, Platinum)
- Stores donation metadata on-chain
- Tracks user badge collections

### AquaFundRegistry

Analytics and discovery contract providing:
- Platform-wide statistics
- Project filtering and search
- Aggregated donation data
- Project listing with pagination

## Gas Optimizations

1. **Minimal Proxy Pattern**: Each project is a clone, saving ~95% gas on deployment
2. **Packed Structs**: Efficient storage layout
3. **Custom Errors**: Gas-efficient error handling (instead of strings)
4. **Events**: Optimized event emission with indexed parameters
5. **Unchecked Arithmetic**: Safe unchecked operations where overflow is impossible

## Security Features

- ✅ ReentrancyGuard on all state-changing functions
- ✅ AccessControl for role-based permissions
- ✅ Ownable for admin functions
- ✅ SafeERC20 for token transfers
- ✅ Input validation on all external functions
- ✅ Pausable factory for emergency stops

## Installation

```bash
# Install dependencies (OpenZeppelin should already be installed)
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2

# Build contracts
forge build

# Run tests
forge test

# Generate coverage report
forge coverage
```

## Deployment

### Prerequisites

1. Set environment variables:
```bash
export PRIVATE_KEY=your_deployer_private_key
export TREASURY=treasury_address  # Optional, defaults to deployer
export SERVICE_FEE=1000  # Optional, defaults to 1000 (10%)
export RPC_URL=your_rpc_url  # For testnet/mainnet
```

### Deploy Scripts

```bash
# Deploy to local network
forge script script/DeployAquaFund.s.sol:DeployAquaFund --rpc-url http://127.0.0.1:8545 --broadcast

# Deploy to Sepolia testnet
forge script script/DeployAquaFund.s.sol:DeployAquaFund --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Deploy to mainnet (use with caution)
forge script script/DeployAquaFund.s.sol:DeployAquaFund --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## Usage Examples

### Creating a Project

```solidity
// Via Factory (requires PROJECT_CREATOR_ROLE)
factory.createProject(
    adminAddress,
    fundingGoal, // in wei
    metadataURI // IPFS hash
);
```

### Donating to a Project

```solidity
// Donate ETH
project.donate{value: amount}();

// Donate ERC20 tokens
project.donateToken(tokenAddress, amount);
```

### Releasing Funds

```solidity
// Once funding goal is reached
project.releaseFunds(); // 10% service fee deducted automatically
```

### Submitting Evidence

```solidity
// Project admin submits evidence
project.submitEvidence(ipfsHash);
```

## Badge Tiers

- **Bronze**: 0.1 ETH or more
- **Silver**: 1 ETH or more
- **Gold**: 10 ETH or more
- **Platinum**: 100 ETH or more

## Service Fee

Default service fee is **10%** (1000 basis points). This can be updated by the factory admin up to a maximum of 50% (5000 basis points).

## Events

All major actions emit events for off-chain indexing:

- `ProjectCreated` - New project created
- `DonationReceived` - Donation made to project
- `FundsReleased` - Funds released to project admin
- `EvidenceSubmitted` - Evidence submitted for verification
- `BadgeMinted` - Badge minted to donor
- `ProjectStatusChanged` - Project status updated

## Testing

```bash
# Run all tests
forge test

# Run with gas report
forge test --gas-report

# Run specific test
forge test --match-test testDonation

# Run with verbosity
forge test -vvv
```

## Audit & Security

Before deploying to mainnet:
1. Run comprehensive test suite
2. Conduct formal verification if needed
3. Schedule third-party security audit
4. Test on testnets thoroughly
5. Review and update access control roles

## License

MIT License - See LICENSE file for details

## Support

For issues, questions, or contributions, please open an issue on GitHub.

---

**⚠️ WARNING**: These contracts handle real funds. Always test thoroughly on testnets before mainnet deployment. Conduct security audits before handling production funds.
