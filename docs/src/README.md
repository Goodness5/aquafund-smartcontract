# AquaFund Smart Contract Documentation

Welcome to the AquaFund Smart Contract documentation! This guide is designed for **frontend developers** who want to integrate with the AquaFund platform.

## What is AquaFund?

AquaFund is a decentralized crowdfunding platform built on BNB Smart Chain (BSC) that enables transparent, secure, and efficient funding for water-related projects. The platform uses smart contracts to manage donations, track project progress, and reward donors with NFT badges.

## Deployed Contracts (BSC Testnet)

All contracts are deployed on BSC Testnet (Chain ID: 97):

- **AquaFundProject (Implementation)**: [`0xAAf4D1d91D486a7C252B2e797e05fB3db8aedf8D`](https://testnet.bscscan.com/address/0xAAf4D1d91D486a7C252B2e797e05fB3db8aedf8D)
  - Implementation contract used as a template for creating project clones

- **AquaFundFactory**: [`0x76F348766973BD06ACf88977CFEEf317B39d2cC8`](https://testnet.bscscan.com/address/0x76F348766973BD06ACf88977CFEEf317B39d2cC8)
  - Main factory contract for creating and managing projects

- **AquaFundBadge**: [`0x102ea409d06cF3277BB9f3b96E9a3092C8D85fC5`](https://testnet.bscscan.com/address/0x102ea409d06cF3277BB9f3b96E9a3092C8D85fC5)
  - ERC721 NFT contract for donor badges

- **AquaFundRegistry**: [`0xa7923939F118C6C21B7174ccf6CA649f2C00cDBD`](https://testnet.bscscan.com/address/0xa7923939F118C6C21B7174ccf6CA649f2C00cDBD)
  - Centralized registry for project discovery and analytics

## Key Features

- 💧 **Project Funding**: Create and fund water-related projects
- 💰 **Multiple Payment Methods**: Donate with ETH or ERC20 tokens
- 🏆 **Badge Rewards**: Earn NFT badges based on donation tiers
- 📊 **Transparent Tracking**: All donations and project progress are on-chain
- 🔒 **Secure**: Built with security best practices and audited contracts
- ⚡ **Gas Efficient**: Uses minimal proxy pattern for low-cost project creation

## Quick Start

If you're new to AquaFund, start here:

1. **[Getting Started](./getting-started.md)** - Set up your development environment
2. **[Architecture Overview](./architecture.md)** - Understand how the system works
3. **[API Reference](./api-reference/)** - Detailed API documentation

## Documentation Structure

### For Frontend Developers

- **[Getting Started Guide](./getting-started.md)** - Setup and basic integration
- **[Contracts Overview](./contracts/)** - Detailed contract documentation with examples
- **[API Reference](./api-reference/)** - Complete function reference
- **[Events Guide](./events.md)** - How to listen to blockchain events
- **[Examples](./examples.md)** - Real-world integration examples

### Core Contracts

- **[AquaFundFactory](./contracts/factory.md)** - Create and manage projects
- **[AquaFundProject](./contracts/project.md)** - Individual project operations
- **[AquaFundBadge](./contracts/badge.md)** - NFT badge system
- **[AquaFundRegistry](./contracts/registry.md)** - Project discovery and analytics

## Understanding Roles

AquaFund has three main roles:

1. **Factory Admin** - Manages platform settings and grants permissions
2. **Project Creator** - NGOs/organizations that can create projects (must be granted `PROJECT_CREATOR_ROLE`)
3. **Project Admin** - Manages individual projects (releases funds, submits evidence)

When creating a project, the creator specifies a project admin who will manage that specific project.

## Prerequisites

Before you start, make sure you have:

- Basic knowledge of Ethereum and smart contracts
- Familiarity with JavaScript/TypeScript
- Experience with Web3 libraries (ethers.js or web3.js)
- A wallet like MetaMask installed

## Need Help?

- Check the [Examples](./examples.md) section for code samples
- Review the [Architecture](./architecture.md) document for system design
- See the [API Reference](./api-reference/) for detailed function documentation

---

**Ready to get started?** Head over to the [Getting Started Guide](./getting-started.md)!
