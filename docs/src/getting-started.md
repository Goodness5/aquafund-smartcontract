# Getting Started

This guide will help you set up your development environment and make your first integration with AquaFund.

## Installation

### 1. Install Dependencies

```bash
npm install ethers
# or
npm install web3
```

### 2. Get Contract Addresses

You'll need the deployed contract addresses. Contact your team or check the deployment configuration.

**Required Contracts:**
- `AquaFundFactory` - Main factory contract
- `AquaFundBadge` - Badge NFT contract
- `AquaFundRegistry` - Registry contract

### 3. Get Contract ABIs

The ABIs are located in the `abis/` directory:
- `abis/AquaFundFactory.json`
- `abis/AquaFundProject.json`
- `abis/AquaFundBadge.json`
- `abis/AquaFundRegistry.json`

## Basic Setup

### Using ethers.js

```javascript
import { ethers } from 'ethers';
import FactoryABI from './abis/AquaFundFactory.json';
import ProjectABI from './abis/AquaFundProject.json';

// Connect to provider (MetaMask, Infura, etc.)
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

// Initialize contracts
const factoryAddress = '0x...'; // Your factory address
const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
```

### Using web3.js

```javascript
import Web3 from 'web3';
import FactoryABI from './abis/AquaFundFactory.json';

// Connect to provider
const web3 = new Web3(window.ethereum);
const accounts = await web3.eth.getAccounts();

// Initialize contract
const factoryAddress = '0x...';
const factory = new web3.eth.Contract(FactoryABI, factoryAddress);
```

## Common Tasks

### 1. Connect Wallet

```javascript
// ethers.js
async function connectWallet() {
  if (window.ethereum) {
    await window.ethereum.request({ method: 'eth_requestAccounts' });
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const address = await signer.getAddress();
    console.log('Connected:', address);
    return { provider, signer, address };
  } else {
    throw new Error('Please install MetaMask');
  }
}
```

### 2. Read Project Information

```javascript
// Get project address from factory
const projectId = 1;
const projectAddress = await factory.getProjectAddress(projectId);

// Connect to project contract
const project = new ethers.Contract(projectAddress, ProjectABI, provider);

// Get project info
const projectInfo = await project.getProjectInfo();
console.log('Project Info:', {
  projectId: projectInfo.projectId.toString(),
  admin: projectInfo.admin,
  fundingGoal: ethers.formatEther(projectInfo.fundingGoal),
  fundsRaised: ethers.formatEther(projectInfo.fundsRaised),
  status: projectInfo.status
});
```

### 3. Make a Donation

```javascript
// Donate ETH
async function donateETH(projectAddress, amount) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  const tx = await project.donate({
    value: ethers.parseEther(amount.toString())
  });
  await tx.wait();
  console.log('Donation successful!', tx.hash);
}

// Donate ERC20 Token
async function donateToken(projectAddress, tokenAddress, amount) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  
  // First, approve the token
  const token = new ethers.Contract(tokenAddress, ERC20ABI, signer);
  await token.approve(projectAddress, ethers.parseUnits(amount.toString(), 18));
  
  // Then donate
  const tx = await project.donateToken(tokenAddress, ethers.parseUnits(amount.toString(), 18));
  await tx.wait();
  console.log('Token donation successful!', tx.hash);
}
```

### 4. Listen to Events

```javascript
// Listen for new donations
project.on('DonationReceived', (projectId, donor, amount, inEth, timestamp) => {
  console.log('New donation:', {
    projectId: projectId.toString(),
    donor,
    amount: ethers.formatEther(amount),
    inEth,
    timestamp: new Date(Number(timestamp) * 1000)
  });
});

// Listen for project creation
factory.on('ProjectCreated', (projectId, projectAddress, admin, fundingGoal) => {
  console.log('New project created:', {
    projectId: projectId.toString(),
    projectAddress,
    admin,
    fundingGoal: ethers.formatEther(fundingGoal)
  });
});
```

## Next Steps

- Read the [Contracts Documentation](./contracts/) for detailed API reference
- Check out [Examples](./examples.md) for more code samples
- Review the [Architecture](./architecture.md) to understand the system design

## Tips

1. **Always handle errors**: Smart contract calls can fail. Wrap them in try-catch blocks.
2. **Show transaction status**: Display loading states while transactions are pending.
3. **Listen to events**: Use events for real-time updates instead of polling.
4. **Format values**: Use `ethers.formatEther()` to convert wei to ETH for display.
5. **Check allowances**: For token donations, always check and request approval first.

## Common Issues

### "User rejected the transaction"
- User clicked "Reject" in MetaMask. Handle gracefully.

### "Insufficient funds"
- Check user's balance before attempting transactions.

### "Token not allowed"
- Verify the token is in the allowed list using `factory.isTokenAllowed(tokenAddress)`.

### "Project not initialized"
- Ensure the project has been properly initialized by the factory.

---

Ready to dive deeper? Check out the [Contracts Documentation](./contracts/)!

