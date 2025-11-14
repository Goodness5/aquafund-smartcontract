# AquaFundProject Contract

The `AquaFundProject` contract represents an individual funding project. Each project is created as a minimal proxy (clone) for gas efficiency.

## Overview

This contract handles:
- Accepting donations (ETH and ERC20 tokens)
- Tracking project status and funds
- Managing evidence submissions
- Releasing funds to project admins
- Handling refunds

## Key Concepts

### Project Status

Projects can be in one of these states:

- `Active` (0) - Accepting donations, goal not reached
- `Funded` (1) - Goal reached, ready to release funds
- `Completed` (2) - Funds released, project completed
- `Cancelled` (3) - Project cancelled, refunds available
- `Refunded` (4) - Refunds have been issued

### Minimum Donation

The minimum donation amount is **0.001 ETH** (or equivalent in tokens).

## Reading Project Data

### Get Project Information

```javascript
const projectInfo = await project.getProjectInfo();

// Returns:
// {
//   projectId: BigNumber,
//   admin: string (address),
//   fundingGoal: BigNumber (in wei),
//   fundsRaised: BigNumber (in wei),
//   status: number (0-4),
//   metadataUri: string (bytes32 as hex)
// }

// Format for display
const formatted = {
  projectId: projectInfo.projectId.toString(),
  admin: projectInfo.admin,
  fundingGoal: ethers.formatEther(projectInfo.fundingGoal),
  fundsRaised: ethers.formatEther(projectInfo.fundsRaised),
  status: ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'][projectInfo.status],
  progress: (Number(projectInfo.fundsRaised) / Number(projectInfo.fundingGoal) * 100).toFixed(2) + '%'
};
```

### Get Total Donations

```javascript
const totalDonations = await project.getTotalDonations();
const totalInEth = ethers.formatEther(totalDonations);
console.log(`Total raised: ${totalInEth} ETH`);
```

### Get Donation Count

```javascript
const donorCount = await project.getDonationCount();
console.log(`Number of donors: ${donorCount}`);
```

### Get User's Donation

```javascript
const userAddress = await signer.getAddress();
const userDonation = await project.getDonation(userAddress);
const userDonationEth = ethers.formatEther(userDonation);
console.log(`You donated: ${userDonationEth} ETH`);
```

### Get All Donors

```javascript
const donors = await project.getDonors();
console.log(`Donors: ${donors.length}`);
// Note: This can be gas-intensive for projects with many donors
```

### Get Evidence

```javascript
const evidenceCount = await project.getEvidenceCount();

// Get specific evidence
const evidence = await project.getEvidence(0);
// Returns: { evidenceHash, timestamp, submitter }
```

## Making Donations

### Donate ETH

```javascript
async function donateETH(projectAddress, amountInEth) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  
  try {
    const tx = await project.donate({
      value: ethers.parseEther(amountInEth.toString())
    });
    
    console.log('Transaction sent:', tx.hash);
    
    // Wait for confirmation
    const receipt = await tx.wait();
    console.log('Donation confirmed!', receipt);
    
    return receipt;
  } catch (error) {
    console.error('Donation failed:', error);
    throw error;
  }
}

// Usage
await donateETH(projectAddress, 0.1); // Donate 0.1 ETH
```

### Donate ERC20 Token

```javascript
async function donateToken(projectAddress, tokenAddress, amount, decimals = 18) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  const token = new ethers.Contract(tokenAddress, ERC20ABI, signer);
  
  try {
    const amountWei = ethers.parseUnits(amount.toString(), decimals);
    
    // Step 1: Check current allowance
    const currentAllowance = await token.allowance(
      await signer.getAddress(),
      projectAddress
    );
    
    // Step 2: Approve if needed
    if (currentAllowance < amountWei) {
      console.log('Approving token...');
      const approveTx = await token.approve(projectAddress, amountWei);
      await approveTx.wait();
      console.log('Token approved');
    }
    
    // Step 3: Donate
    const tx = await project.donateToken(tokenAddress, amountWei);
    console.log('Transaction sent:', tx.hash);
    
    const receipt = await tx.wait();
    console.log('Token donation confirmed!', receipt);
    
    return receipt;
  } catch (error) {
    console.error('Token donation failed:', error);
    throw error;
  }
}

// Usage
await donateToken(
  projectAddress,
  '0x...', // USDC address
  100,     // 100 USDC
  6         // USDC has 6 decimals
);
```

### Check if Donation is Valid

```javascript
async function validateDonation(projectAddress, amountInEth) {
  const project = new ethers.Contract(projectAddress, ProjectABI, provider);
  
  // Check minimum donation
  const minDonation = await project.MIN_DONATION();
  const amountWei = ethers.parseEther(amountInEth.toString());
  
  if (amountWei < minDonation) {
    throw new Error(`Minimum donation is ${ethers.formatEther(minDonation)} ETH`);
  }
  
  // Check project status
  const projectInfo = await project.getProjectInfo();
  if (projectInfo.status !== 0) { // Not Active
    throw new Error('Project is not accepting donations');
  }
  
  // Check if goal already reached
  if (projectInfo.fundsRaised >= projectInfo.fundingGoal) {
    console.warn('Goal already reached, but donations may still be accepted');
  }
  
  return true;
}
```

## Admin Functions

**Important:** These functions can only be called by the **project admin** - the address that was specified when the project was created via `factory.createProject(adminAddress, ...)`.

### Release Funds

Only the project admin can release funds. A 10% service fee is automatically deducted.

```javascript
async function releaseFunds(projectAddress) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  
  try {
    const tx = await project.releaseFunds();
    console.log('Release transaction sent:', tx.hash);
    
    const receipt = await tx.wait();
    console.log('Funds released!', receipt);
    
    return receipt;
  } catch (error) {
    if (error.message.includes('FundingGoalNotReached')) {
      throw new Error('Funding goal has not been reached yet');
    }
    if (error.message.includes('FundsAlreadyReleased')) {
      throw new Error('Funds have already been released');
    }
    throw error;
  }
}
```

### Submit Evidence

Project admins can submit evidence (IPFS hashes) to prove project completion.

```javascript
async function submitEvidence(projectAddress, ipfsHash) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  
  // Convert IPFS hash to bytes32
  // IPFS hashes are typically base58 encoded, you may need to convert
  const evidenceHash = ethers.hexlify(ethers.toUtf8Bytes(ipfsHash));
  
  try {
    const tx = await project.submitEvidence(evidenceHash);
    await tx.wait();
    console.log('Evidence submitted!', tx.hash);
  } catch (error) {
    console.error('Failed to submit evidence:', error);
    throw error;
  }
}
```

### Update Project Status

```javascript
async function updateStatus(projectAddress, newStatus) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  
  // Status: 0=Active, 1=Funded, 2=Completed, 3=Cancelled, 4=Refunded
  const tx = await project.updateStatus(newStatus);
  await tx.wait();
  console.log('Status updated!');
}
```

### Refund Donors

```javascript
// Refund a specific donor
async function refundDonor(projectAddress, donorAddress) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  const tx = await project.refundDonor(donorAddress);
  await tx.wait();
  console.log('Donor refunded!');
}

// Refund all donors
async function refundAllDonors(projectAddress) {
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  const tx = await project.refundAllDonors();
  await tx.wait();
  console.log('All donors refunded!');
}
```

## Events

### Listen to Donation Events

```javascript
// Listen for donations
project.on('DonationReceived', (projectId, donor, amount, inEth, timestamp) => {
  console.log('New donation:', {
    projectId: projectId.toString(),
    donor,
    amount: ethers.formatEther(amount),
    inEth,
    timestamp: new Date(Number(timestamp) * 1000)
  });
  
  // Update UI
  updateDonationDisplay();
});

// Listen for fund releases
project.on('FundsReleased', (projectId, recipient, amount, serviceFee) => {
  console.log('Funds released:', {
    projectId: projectId.toString(),
    recipient,
    amount: ethers.formatEther(amount),
    serviceFee: ethers.formatEther(serviceFee)
  });
});

// Listen for evidence submissions
project.on('EvidenceSubmitted', (projectId, evidenceHash, submitter, timestamp) => {
  console.log('Evidence submitted:', {
    projectId: projectId.toString(),
    evidenceHash,
    submitter,
    timestamp: new Date(Number(timestamp) * 1000)
  });
});
```

## Error Handling

```javascript
async function safeDonate(projectAddress, amount) {
  try {
    await donateETH(projectAddress, amount);
  } catch (error) {
    if (error.code === 'ACTION_REJECTED') {
      alert('Transaction was rejected');
    } else if (error.message.includes('InvalidAmount')) {
      alert('Donation amount is too small (minimum 0.001 ETH)');
    } else if (error.message.includes('NotInitialized')) {
      alert('Project has not been initialized');
    } else {
      console.error('Unexpected error:', error);
      alert('Donation failed. Please try again.');
    }
  }
}
```

## Best Practices

1. **Always check project status** before allowing donations
2. **Validate amounts** against minimum donation requirement
3. **Show loading states** during transactions
4. **Listen to events** for real-time updates
5. **Handle errors gracefully** with user-friendly messages
6. **Format values** properly (wei to ETH conversion)
7. **Check token allowances** before token donations

## Complete Example

```javascript
import { ethers } from 'ethers';
import ProjectABI from './abis/AquaFundProject.json';

class AquaFundProjectClient {
  constructor(projectAddress, signer) {
    this.project = new ethers.Contract(projectAddress, ProjectABI, signer);
    this.provider = signer.provider;
  }
  
  async getInfo() {
    const info = await this.project.getProjectInfo();
    return {
      projectId: info.projectId.toString(),
      admin: info.admin,
      fundingGoal: ethers.formatEther(info.fundingGoal),
      fundsRaised: ethers.formatEther(info.fundsRaised),
      status: ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'][info.status],
      progress: (Number(info.fundsRaised) / Number(info.fundingGoal) * 100).toFixed(2)
    };
  }
  
  async donate(amountInEth) {
    const tx = await this.project.donate({
      value: ethers.parseEther(amountInEth.toString())
    });
    return await tx.wait();
  }
  
  async getMyDonation() {
    const address = await this.project.signer.getAddress();
    const donation = await this.project.getDonation(address);
    return ethers.formatEther(donation);
  }
  
  setupEventListeners(callbacks) {
    this.project.on('DonationReceived', (projectId, donor, amount, inEth, timestamp) => {
      callbacks.onDonation?.({
        projectId: projectId.toString(),
        donor,
        amount: ethers.formatEther(amount),
        inEth,
        timestamp: new Date(Number(timestamp) * 1000)
      });
    });
  }
}

// Usage
const client = new AquaFundProjectClient(projectAddress, signer);
const info = await client.getInfo();
await client.donate(0.1);
```

---

**Next:** Learn about the [Factory Contract](./factory.md) for creating projects.

