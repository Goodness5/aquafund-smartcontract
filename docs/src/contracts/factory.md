# AquaFundFactory Contract

The `AquaFundFactory` is the main entry point for the AquaFund platform. It creates new projects, manages platform settings, and tracks global statistics.

## Overview

The Factory contract handles:
- Creating new funding projects
- Managing platform configuration (fees, treasury)
- Tracking global donation statistics
- Managing allowed tokens for donations
- Providing leaderboards and analytics

## Key Concepts

### Service Fee

The platform charges a **10% service fee** (1000 basis points) on all fund releases. This fee goes to the treasury address.

### Project Creation

Projects are created using the **minimal proxy pattern** (EIP-1167) for gas efficiency. Each project is a lightweight clone that delegates to a shared implementation.

### Roles

- `ADMIN_ROLE` - Can update fees, treasury, and platform settings
- `PROJECT_CREATOR_ROLE` - Can create new projects

## Reading Factory Data

### Get Platform Statistics

```javascript
const stats = await factory.getPlatformStats();

// Returns:
// {
//   totalProjects: BigNumber,
//   totalRaised: BigNumber,
//   totalDonors_: BigNumber,
//   totalDonations: BigNumber
// }

const formatted = {
  totalProjects: stats.totalProjects.toString(),
  totalRaised: ethers.formatEther(stats.totalRaised),
  totalDonors: stats.totalDonors_.toString(),
  totalDonations: stats.totalDonations.toString()
};
```

### Get Service Fee

```javascript
const fee = await factory.getServiceFee();
// Returns fee in basis points (1000 = 10%)
const feePercent = Number(fee) / 100;
console.log(`Service fee: ${feePercent}%`);
```

### Get Treasury Address

```javascript
const treasury = await factory.getTreasury();
console.log('Treasury address:', treasury);
```

### Get Total Projects

```javascript
const totalProjects = await factory.getTotalProjects();
console.log(`Total projects: ${totalProjects}`);
```

### Get Project Address

```javascript
const projectId = 1;
const projectAddress = await factory.getProjectAddress(projectId);
console.log(`Project ${projectId} address:`, projectAddress);
```

### Get Projects Range (Pagination)

```javascript
// Get projects 0-9
const { projectIds, addresses } = await factory.getProjectsRange(0, 10);

console.log('Projects:', projectIds.map((id, i) => ({
  id: id.toString(),
  address: addresses[i]
})));
```

## Creating Projects

### Create a New Project

**Note:** You need the `PROJECT_CREATOR_ROLE` to create projects.

```javascript
async function createProject(adminAddress, fundingGoalInEth, metadataIpfsHash) {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  
  try {
    // Convert IPFS hash to bytes32
    // You may need to convert your IPFS hash format
    const metadataUri = ethers.hexlify(ethers.toUtf8Bytes(metadataIpfsHash));
    
    const tx = await factory.createProject(
      adminAddress,
      ethers.parseEther(fundingGoalInEth.toString()),
      metadataUri
    );
    
    console.log('Transaction sent:', tx.hash);
    
    // Wait for confirmation
    const receipt = await tx.wait();
    
    // Find the ProjectCreated event
    const event = receipt.logs.find(
      log => log.topics[0] === ethers.id('ProjectCreated(uint256,address,address,uint256)')
    );
    
    if (event) {
      const decoded = factory.interface.parseLog(event);
      console.log('Project created:', {
        projectId: decoded.args.projectId.toString(),
        projectAddress: decoded.args.projectAddress,
        admin: decoded.args.admin,
        fundingGoal: ethers.formatEther(decoded.args.fundingGoal)
      });
    }
    
    return receipt;
  } catch (error) {
    if (error.message.includes('UnauthorizedAccess')) {
      throw new Error('You do not have permission to create projects');
    }
    throw error;
  }
}

// Usage
await createProject(
  '0x...', // Admin address
  10,      // 10 ETH funding goal
  'Qm...'  // IPFS hash of project metadata
);
```

## Token Management

### Check if Token is Allowed

```javascript
async function isTokenAllowed(tokenAddress) {
  const allowed = await factory.isTokenAllowed(tokenAddress);
  return allowed;
}

// Check before allowing token donations
const usdcAddress = '0x...';
if (await isTokenAllowed(usdcAddress)) {
  console.log('USDC donations are allowed');
} else {
  console.log('USDC donations are not allowed');
}
```

### Get All Allowed Tokens

```javascript
const allowedTokens = await factory.getAllowedTokens();
console.log('Allowed tokens:', allowedTokens);
```

### Add/Remove Tokens (Admin Only)

```javascript
// Add a token to allowlist
async function addToken(tokenAddress) {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  const tx = await factory.addAllowedToken(tokenAddress);
  await tx.wait();
  console.log('Token added to allowlist');
}

// Remove a token from allowlist
async function removeToken(tokenAddress) {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  const tx = await factory.removeAllowedToken(tokenAddress);
  await tx.wait();
  console.log('Token removed from allowlist');
}
```

## Donation Tracking

### Get User's Total Donations

```javascript
const userAddress = await signer.getAddress();
const totalDonated = await factory.getTotalDonated(userAddress);
const totalInEth = ethers.formatEther(totalDonated);
console.log(`Total donated across all projects: ${totalInEth} ETH`);
```

### Get Leaderboard

```javascript
async function getLeaderboard(start = 0, end = 10) {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, provider);
  
  // Note: This can be gas-intensive for large datasets
  // Consider using off-chain indexing for production
  const { donors, amounts } = await factory.getLeaderboard(start, end);
  
  return donors.map((donor, i) => ({
    address: donor,
    totalDonated: ethers.formatEther(amounts[i])
  }));
}

// Usage
const topDonors = await getLeaderboard(0, 10);
topDonors.forEach((donor, index) => {
  console.log(`${index + 1}. ${donor.address}: ${donor.totalDonated} ETH`);
});
```

### Get Total Donors

```javascript
const totalDonors = await factory.getTotalDonors();
console.log(`Total unique donors: ${totalDonors}`);
```

## Admin Functions

### Update Service Fee (Admin Only)

```javascript
async function updateServiceFee(newFeePercent) {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  
  // Convert percentage to basis points (10% = 1000 basis points)
  const feeInBasisPoints = newFeePercent * 100;
  
  const tx = await factory.updateServiceFee(feeInBasisPoints);
  await tx.wait();
  console.log('Service fee updated');
}
```

### Update Treasury Address (Admin Only)

```javascript
async function updateTreasury(newTreasuryAddress) {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  const tx = await factory.updateTreasury(newTreasuryAddress);
  await tx.wait();
  console.log('Treasury address updated');
}
```

### Set Badge Contract (Admin Only)

```javascript
async function setBadgeContract(badgeContractAddress) {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  const tx = await factory.setBadgeContract(badgeContractAddress);
  await tx.wait();
  console.log('Badge contract set');
}
```

### Set Registry Contract (Admin Only)

```javascript
async function setRegistry(registryAddress) {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  const tx = await factory.setRegistry(registryAddress);
  await tx.wait();
  console.log('Registry contract set');
}
```

### Pause/Unpause Project Creation

```javascript
// Pause project creation (emergency)
async function pauseFactory() {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  const tx = await factory.pause();
  await tx.wait();
  console.log('Factory paused');
}

// Resume project creation
async function unpauseFactory() {
  const factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
  const tx = await factory.unpause();
  await tx.wait();
  console.log('Factory unpaused');
}
```

## Events

### Listen to Project Creation

```javascript
factory.on('ProjectCreated', (projectId, projectAddress, admin, fundingGoal) => {
  console.log('New project created:', {
    projectId: projectId.toString(),
    projectAddress,
    admin,
    fundingGoal: ethers.formatEther(fundingGoal)
  });
  
  // Update UI with new project
  refreshProjectList();
});
```

### Listen to Global Donations

```javascript
factory.on('GlobalDonationReceived', (donor, projectId, amount, totalDonated, timestamp) => {
  console.log('Global donation:', {
    donor,
    projectId: projectId.toString(),
    amount: ethers.formatEther(amount),
    totalDonated: ethers.formatEther(totalDonated),
    timestamp: new Date(Number(timestamp) * 1000)
  });
  
  // Update leaderboard
  updateLeaderboard();
});
```

### Listen to Fee Updates

```javascript
factory.on('ServiceFeeUpdated', (oldFee, newFee) => {
  console.log('Service fee updated:', {
    oldFee: Number(oldFee) / 100 + '%',
    newFee: Number(newFee) / 100 + '%'
  });
});
```

## Complete Example

```javascript
import { ethers } from 'ethers';
import FactoryABI from './abis/AquaFundFactory.json';

class AquaFundFactoryClient {
  constructor(factoryAddress, signer) {
    this.factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
    this.provider = signer.provider;
  }
  
  async getStats() {
    const stats = await this.factory.getPlatformStats();
    return {
      totalProjects: stats.totalProjects.toString(),
      totalRaised: ethers.formatEther(stats.totalRaised),
      totalDonors: stats.totalDonors_.toString(),
      totalDonations: stats.totalDonations.toString()
    };
  }
  
  async createProject(admin, fundingGoal, metadataHash) {
    const metadataUri = ethers.hexlify(ethers.toUtf8Bytes(metadataHash));
    const tx = await this.factory.createProject(
      admin,
      ethers.parseEther(fundingGoal.toString()),
      metadataUri
    );
    const receipt = await tx.wait();
    
    // Extract project address from event
    const event = receipt.logs.find(
      log => log.topics[0] === ethers.id('ProjectCreated(uint256,address,address,uint256)')
    );
    const decoded = this.factory.interface.parseLog(event);
    
    return {
      projectId: decoded.args.projectId.toString(),
      projectAddress: decoded.args.projectAddress
    };
  }
  
  async getProjects(page = 0, pageSize = 10) {
    const start = page * pageSize;
    const end = start + pageSize;
    const { projectIds, addresses } = await this.factory.getProjectsRange(start, end);
    
    return projectIds.map((id, i) => ({
      id: id.toString(),
      address: addresses[i]
    }));
  }
  
  async getLeaderboard(limit = 10) {
    const { donors, amounts } = await this.factory.getLeaderboard(0, limit);
    return donors.map((donor, i) => ({
      address: donor,
      totalDonated: ethers.formatEther(amounts[i])
    }));
  }
}

// Usage
const factory = new AquaFundFactoryClient(factoryAddress, signer);
const stats = await factory.getStats();
const projects = await factory.getProjects(0, 10);
const leaderboard = await factory.getLeaderboard(10);
```

## Best Practices

1. **Cache platform stats** - Don't call `getPlatformStats()` on every page load
2. **Use pagination** - Use `getProjectsRange()` instead of fetching all projects
3. **Index events off-chain** - For leaderboards and analytics, use The Graph or similar
4. **Check permissions** - Verify user has `PROJECT_CREATOR_ROLE` before showing create button
5. **Handle pauses** - Check if factory is paused before allowing project creation
6. **Validate token addresses** - Always verify token is allowed before donation UI

---

**Next:** Learn about the [Badge Contract](./badge.md) for NFT rewards.

