# Events Guide

Smart contracts emit events that your frontend can listen to for real-time updates. This guide shows you how to listen to and handle AquaFund events.

## Why Use Events?

- **Real-time updates**: Get notified immediately when something happens
- **Efficient**: No need to poll the blockchain
- **Decentralized**: Events are part of the blockchain state
- **Historical data**: Query past events for analytics

## Event Listening Basics

### Using ethers.js

```javascript
import { ethers } from 'ethers';

// Connect to contract
const provider = new ethers.BrowserProvider(window.ethereum);
const project = new ethers.Contract(projectAddress, ProjectABI, provider);

// Listen to events
project.on('DonationReceived', (projectId, donor, amount, inEth, timestamp) => {
  console.log('New donation!', {
    projectId: projectId.toString(),
    donor,
    amount: ethers.formatEther(amount),
    inEth,
    timestamp: new Date(Number(timestamp) * 1000)
  });
});

// Remove listener
project.off('DonationReceived');
```

### Using web3.js

```javascript
import Web3 from 'web3';

const web3 = new Web3(window.ethereum);
const project = new web3.eth.Contract(ProjectABI, projectAddress);

// Listen to events
project.events.DonationReceived({
  fromBlock: 'latest'
})
.on('data', (event) => {
  console.log('New donation!', {
    projectId: event.returnValues.projectId,
    donor: event.returnValues.donor,
    amount: web3.utils.fromWei(event.returnValues.amount, 'ether'),
    inEth: event.returnValues.inEth
  });
})
.on('error', (error) => {
  console.error('Event error:', error);
});
```

## AquaFundProject Events

### DonationReceived

Emitted when a donation is received (ETH or token).

```javascript
project.on('DonationReceived', (projectId, donor, amount, inEth, timestamp) => {
  // Update UI
  updateDonationDisplay({
    projectId: projectId.toString(),
    donor,
    amount: ethers.formatEther(amount),
    inEth,
    timestamp: new Date(Number(timestamp) * 1000)
  });
  
  // Show notification
  showNotification(`New donation of ${ethers.formatEther(amount)} ETH!`);
});
```

**Event Parameters:**
- `projectId` (uint256, indexed) - Project ID
- `donor` (address, indexed) - Donor address
- `amount` (uint256) - Donation amount in wei
- `inEth` (bool) - True if ETH, false if token
- `timestamp` (uint256) - Block timestamp

### FundsReleased

Emitted when funds are released to the project admin.

```javascript
project.on('FundsReleased', (projectId, recipient, amount, serviceFee) => {
  console.log('Funds released:', {
    projectId: projectId.toString(),
    recipient,
    amount: ethers.formatEther(amount),
    serviceFee: ethers.formatEther(serviceFee)
  });
  
  // Update project status
  updateProjectStatus(projectId, 'Completed');
});
```

**Event Parameters:**
- `projectId` (uint256, indexed) - Project ID
- `recipient` (address, indexed) - Recipient address
- `amount` (uint256) - Amount released (after fee)
- `serviceFee` (uint256) - Service fee deducted

### EvidenceSubmitted

Emitted when project admin submits evidence.

```javascript
project.on('EvidenceSubmitted', (projectId, evidenceHash, submitter, timestamp) => {
  console.log('Evidence submitted:', {
    projectId: projectId.toString(),
    evidenceHash,
    submitter,
    timestamp: new Date(Number(timestamp) * 1000)
  });
  
  // Fetch evidence from IPFS
  fetchEvidenceFromIPFS(evidenceHash);
});
```

**Event Parameters:**
- `projectId` (uint256, indexed) - Project ID
- `evidenceHash` (bytes32, indexed) - IPFS hash
- `submitter` (address, indexed) - Submitter address
- `timestamp` (uint256) - Block timestamp

### ProjectStatusChanged

Emitted when project status changes.

```javascript
project.on('ProjectStatusChanged', (projectId, oldStatus, newStatus) => {
  const statusNames = ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'];
  
  console.log('Status changed:', {
    projectId: projectId.toString(),
    oldStatus: statusNames[oldStatus],
    newStatus: statusNames[newStatus]
  });
  
  // Update UI
  updateProjectStatus(projectId, statusNames[newStatus]);
});
```

**Event Parameters:**
- `projectId` (uint256, indexed) - Project ID
- `oldStatus` (ProjectStatus) - Previous status
- `newStatus` (ProjectStatus) - New status

### RefundIssued

Emitted when a refund is issued to a donor.

```javascript
project.on('RefundIssued', (projectId, donor, amount) => {
  console.log('Refund issued:', {
    projectId: projectId.toString(),
    donor,
    amount: ethers.formatEther(amount)
  });
});
```

**Event Parameters:**
- `projectId` (uint256, indexed) - Project ID
- `donor` (address, indexed) - Donor address
- `amount` (uint256) - Refund amount

## AquaFundFactory Events

### ProjectCreated

Emitted when a new project is created.

```javascript
factory.on('ProjectCreated', (projectId, projectAddress, admin, fundingGoal) => {
  console.log('New project created:', {
    projectId: projectId.toString(),
    projectAddress,
    admin,
    fundingGoal: ethers.formatEther(fundingGoal)
  });
  
  // Add to project list
  addProjectToList({
    id: projectId.toString(),
    address: projectAddress,
    admin,
    goal: ethers.formatEther(fundingGoal)
  });
});
```

### GlobalDonationReceived

Emitted for every donation across all projects.

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

### ServiceFeeUpdated

Emitted when service fee is updated.

```javascript
factory.on('ServiceFeeUpdated', (oldFee, newFee) => {
  console.log('Service fee updated:', {
    oldFee: Number(oldFee) / 100 + '%',
    newFee: Number(newFee) / 100 + '%'
  });
});
```

## AquaFundBadge Events

### BadgeMinted

Emitted when a badge is minted.

```javascript
badge.on('BadgeMinted', (to, tokenId, projectId, tier, donationAmount) => {
  console.log('Badge minted:', {
    to,
    tokenId: tokenId.toString(),
    projectId: projectId.toString(),
    tier: getTierName(tier),
    donationAmount: ethers.formatEther(donationAmount)
  });
  
  // Show congratulations
  if (to.toLowerCase() === userAddress.toLowerCase()) {
    showBadgeNotification(getTierName(tier));
  }
});
```

## Querying Past Events

### Get Historical Events

```javascript
// Get all donations for a project in the last 24 hours
async function getRecentDonations(projectAddress, hours = 24) {
  const project = new ethers.Contract(projectAddress, ProjectABI, provider);
  
  const fromBlock = await provider.getBlockNumber() - Math.floor(hours * 60 * 60 / 12); // Approximate
  
  const filter = project.filters.DonationReceived();
  const events = await project.queryFilter(filter, fromBlock);
  
  return events.map(event => ({
    projectId: event.args.projectId.toString(),
    donor: event.args.donor,
    amount: ethers.formatEther(event.args.amount),
    inEth: event.args.inEth,
    timestamp: new Date(Number(event.args.timestamp) * 1000),
    txHash: event.transactionHash
  }));
}
```

### Get Events for Specific Project

```javascript
async function getProjectEvents(projectId) {
  const project = new ethers.Contract(projectAddress, ProjectABI, provider);
  
  // Get all events for this project
  const donationFilter = project.filters.DonationReceived(projectId);
  const donations = await project.queryFilter(donationFilter);
  
  const releaseFilter = project.filters.FundsReleased(projectId);
  const releases = await project.queryFilter(releaseFilter);
  
  return {
    donations: donations.map(e => ({
      donor: e.args.donor,
      amount: ethers.formatEther(e.args.amount),
      timestamp: new Date(Number(e.args.timestamp) * 1000)
    })),
    releases: releases.map(e => ({
      recipient: e.args.recipient,
      amount: ethers.formatEther(e.args.amount),
      serviceFee: ethers.formatEther(e.args.serviceFee)
    }))
  };
}
```

## React Hook for Events

```jsx
// src/hooks/useProjectEvents.js
import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

function useProjectEvents(projectAddress, projectABI) {
  const [donations, setDonations] = useState([]);
  const [status, setStatus] = useState(null);
  
  useEffect(() => {
    if (!projectAddress) return;
    
    const provider = new ethers.BrowserProvider(window.ethereum);
    const project = new ethers.Contract(projectAddress, projectABI, provider);
    
    // Listen to donations
    const donationHandler = (projectId, donor, amount, inEth, timestamp) => {
      setDonations(prev => [{
        projectId: projectId.toString(),
        donor,
        amount: ethers.formatEther(amount),
        inEth,
        timestamp: new Date(Number(timestamp) * 1000)
      }, ...prev]);
    };
    
    // Listen to status changes
    const statusHandler = (projectId, oldStatus, newStatus) => {
      const statusNames = ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'];
      setStatus(statusNames[newStatus]);
    };
    
    project.on('DonationReceived', donationHandler);
    project.on('ProjectStatusChanged', statusHandler);
    
    // Cleanup
    return () => {
      project.off('DonationReceived', donationHandler);
      project.off('ProjectStatusChanged', statusHandler);
    };
  }, [projectAddress, projectABI]);
  
  return { donations, status };
}

// Usage
function ProjectPage({ projectAddress }) {
  const { donations, status } = useProjectEvents(projectAddress, ProjectABI);
  
  return (
    <div>
      <p>Status: {status}</p>
      <h3>Recent Donations</h3>
      {donations.map((donation, i) => (
        <div key={i}>
          {donation.donor}: {donation.amount} ETH
        </div>
      ))}
    </div>
  );
}
```

## Best Practices

1. **Clean up listeners** - Always remove event listeners when components unmount
2. **Handle errors** - Event listeners can fail, handle errors gracefully
3. **Use indexed parameters** - Filter events using indexed parameters for efficiency
4. **Cache event data** - Don't re-fetch data you already have from events
5. **Combine with polling** - Use events for real-time updates, polling for initial load
6. **Limit block range** - When querying past events, limit the block range to avoid timeouts

## Event Monitoring Service

```javascript
// src/services/eventMonitor.js
class EventMonitor {
  constructor(contracts) {
    this.contracts = contracts;
    this.listeners = new Map();
  }
  
  startMonitoring(callbacks) {
    // Monitor project donations
    this.contracts.factory.on('ProjectCreated', (projectId, address) => {
      callbacks.onProjectCreated?.(projectId.toString(), address);
    });
    
    this.contracts.factory.on('GlobalDonationReceived', (donor, projectId, amount) => {
      callbacks.onGlobalDonation?.({
        donor,
        projectId: projectId.toString(),
        amount: ethers.formatEther(amount)
      });
    });
    
    // Monitor badge mints
    this.contracts.badge.on('BadgeMinted', (to, tokenId, projectId, tier) => {
      callbacks.onBadgeMinted?.({
        to,
        tokenId: tokenId.toString(),
        projectId: projectId.toString(),
        tier: getTierName(tier)
      });
    });
  }
  
  stopMonitoring() {
    this.contracts.factory.removeAllListeners();
    this.contracts.badge.removeAllListeners();
  }
}

// Usage
const monitor = new EventMonitor({ factory, badge });
monitor.startMonitoring({
  onProjectCreated: (id, address) => console.log('New project:', id),
  onGlobalDonation: (data) => updateLeaderboard(data),
  onBadgeMinted: (data) => showBadgeNotification(data)
});
```

---

Use events to create a responsive, real-time user experience in your AquaFund integration!

