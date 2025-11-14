# Integration Examples

This page contains complete, real-world examples of integrating AquaFund into your frontend application.

## Complete React Integration

### Setup

```javascript
// src/services/aquafund.js
import { ethers } from 'ethers';
import FactoryABI from '../abis/AquaFundFactory.json';
import ProjectABI from '../abis/AquaFundProject.json';
import BadgeABI from '../abis/AquaFundBadge.json';
import RegistryABI from '../abis/AquaFundRegistry.json';

const CONTRACTS = {
  factory: '0x...',
  badge: '0x...',
  registry: '0x...'
};

class AquaFundService {
  constructor(signer) {
    this.signer = signer;
    this.provider = signer.provider;
    
    this.factory = new ethers.Contract(CONTRACTS.factory, FactoryABI, signer);
    this.badge = new ethers.Contract(CONTRACTS.badge, BadgeABI, signer);
    this.registry = new ethers.Contract(CONTRACTS.registry, RegistryABI, signer);
  }
  
  // Factory methods
  async getStats() {
    const stats = await this.factory.getPlatformStats();
    return {
      totalProjects: stats.totalProjects.toString(),
      totalRaised: ethers.formatEther(stats.totalRaised),
      totalDonors: stats.totalDonors_.toString()
    };
  }
  
  async getProjectAddress(projectId) {
    return await this.factory.getProjectAddress(projectId);
  }
  
  // Project methods
  async getProjectInfo(projectAddress) {
    const project = new ethers.Contract(projectAddress, ProjectABI, this.provider);
    const info = await project.getProjectInfo();
    
    return {
      projectId: info.projectId.toString(),
      admin: info.admin,
      fundingGoal: ethers.formatEther(info.fundingGoal),
      fundsRaised: ethers.formatEther(info.fundsRaised),
      status: ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'][info.status],
      progress: (Number(info.fundsRaised) / Number(info.fundingGoal) * 100).toFixed(2)
    };
  }
  
  async donate(projectAddress, amount) {
    const project = new ethers.Contract(projectAddress, ProjectABI, this.signer);
    const tx = await project.donate({
      value: ethers.parseEther(amount.toString())
    });
    return await tx.wait();
  }
  
  // Badge methods
  async getUserBadges(userAddress) {
    const badgeIds = await this.badge.getUserBadges(userAddress);
    return Promise.all(
      badgeIds.map(async (id) => {
        const metadata = await this.badge.getBadgeMetadata(id);
        return {
          tokenId: id.toString(),
          projectId: metadata.projectId.toString(),
          tier: this.getTierName(metadata.tier)
        };
      })
    );
  }
  
  getTierName(tierBytes) {
    const tiers = {
      '0x42726f6e': 'Bronze',
      '0x53696c76': 'Silver',
      '0x476f6c64': 'Gold',
      '0x506c6174': 'Platinum'
    };
    return tiers[tierBytes] || 'Unknown';
  }
}

export default AquaFundService;
```

### React Components

```jsx
// src/components/ProjectCard.jsx
import React, { useState } from 'react';
import { useAquaFund } from '../hooks/useAquaFund';

function ProjectCard({ projectId, projectAddress }) {
  const { donate, getProjectInfo } = useAquaFund();
  const [project, setProject] = useState(null);
  const [donationAmount, setDonationAmount] = useState('');
  const [loading, setLoading] = useState(false);
  
  React.useEffect(() => {
    loadProject();
  }, [projectAddress]);
  
  async function loadProject() {
    const info = await getProjectInfo(projectAddress);
    setProject(info);
  }
  
  async function handleDonate() {
    if (!donationAmount || parseFloat(donationAmount) <= 0) return;
    
    setLoading(true);
    try {
      await donate(projectAddress, donationAmount);
      alert('Donation successful!');
      setDonationAmount('');
      await loadProject(); // Refresh
    } catch (error) {
      alert('Donation failed: ' + error.message);
    } finally {
      setLoading(false);
    }
  }
  
  if (!project) return <div>Loading...</div>;
  
  return (
    <div className="project-card">
      <h3>Project #{project.projectId}</h3>
      <div className="progress-bar">
        <div 
          className="progress-fill" 
          style={{ width: `${project.progress}%` }}
        />
      </div>
      <p>
        {project.fundsRaised} ETH / {project.fundingGoal} ETH
      </p>
      <p>Status: {project.status}</p>
      
      {project.status === 'Active' && (
        <div className="donation-form">
          <input
            type="number"
            placeholder="Amount (ETH)"
            value={donationAmount}
            onChange={(e) => setDonationAmount(e.target.value)}
            min="0.001"
            step="0.001"
          />
          <button 
            onClick={handleDonate}
            disabled={loading}
          >
            {loading ? 'Processing...' : 'Donate'}
          </button>
        </div>
      )}
    </div>
  );
}

export default ProjectCard;
```

```jsx
// src/components/ProjectList.jsx
import React, { useState, useEffect } from 'react';
import { useAquaFund } from '../hooks/useAquaFund';
import ProjectCard from './ProjectCard';

function ProjectList() {
  const { registry } = useAquaFund();
  const [projects, setProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    loadProjects();
  }, []);
  
  async function loadProjects() {
    try {
      // Get active projects
      const projectIds = await registry.getProjectsByStatus(0);
      
      // Get project addresses from factory
      const projectData = await Promise.all(
        projectIds.map(async (id) => {
          const address = await registry.factory.getProjectAddress(id);
          return { id: id.toString(), address };
        })
      );
      
      setProjects(projectData);
    } catch (error) {
      console.error('Failed to load projects:', error);
    } finally {
      setLoading(false);
    }
  }
  
  if (loading) return <div>Loading projects...</div>;
  
  return (
    <div className="project-list">
      <h2>Active Projects</h2>
      {projects.length === 0 ? (
        <p>No active projects</p>
      ) : (
        projects.map(project => (
          <ProjectCard
            key={project.id}
            projectId={project.id}
            projectAddress={project.address}
          />
        ))
      )}
    </div>
  );
}

export default ProjectList;
```

### React Hook

```jsx
// src/hooks/useAquaFund.js
import { useState, useEffect, useContext, createContext } from 'react';
import { ethers } from 'ethers';
import AquaFundService from '../services/aquafund';

const AquaFundContext = createContext();

export function AquaFundProvider({ children }) {
  const [service, setService] = useState(null);
  const [connected, setConnected] = useState(false);
  
  useEffect(() => {
    connectWallet();
  }, []);
  
  async function connectWallet() {
    if (window.ethereum) {
      try {
        await window.ethereum.request({ method: 'eth_requestAccounts' });
        const provider = new ethers.BrowserProvider(window.ethereum);
        const signer = await provider.getSigner();
        const aquaFund = new AquaFundService(signer);
        
        setService(aquaFund);
        setConnected(true);
      } catch (error) {
        console.error('Failed to connect:', error);
      }
    }
  }
  
  return (
    <AquaFundContext.Provider value={{ service, connected, connectWallet }}>
      {children}
    </AquaFundContext.Provider>
  );
}

export function useAquaFund() {
  const context = useContext(AquaFundContext);
  if (!context) {
    throw new Error('useAquaFund must be used within AquaFundProvider');
  }
  
  const { service } = context;
  
  return {
    ...service,
    connected: context.connected,
    connectWallet: context.connectWallet
  };
}
```

## Event Listening Example

```javascript
// src/services/eventListener.js
import { ethers } from 'ethers';

class EventListener {
  constructor(projectAddress, projectABI) {
    this.project = new ethers.Contract(projectAddress, projectABI, provider);
    this.listeners = new Map();
  }
  
  onDonation(callback) {
    const handler = (projectId, donor, amount, inEth, timestamp) => {
      callback({
        projectId: projectId.toString(),
        donor,
        amount: ethers.formatEther(amount),
        inEth,
        timestamp: new Date(Number(timestamp) * 1000)
      });
    };
    
    this.project.on('DonationReceived', handler);
    this.listeners.set('DonationReceived', handler);
  }
  
  onFundsReleased(callback) {
    const handler = (projectId, recipient, amount, serviceFee) => {
      callback({
        projectId: projectId.toString(),
        recipient,
        amount: ethers.formatEther(amount),
        serviceFee: ethers.formatEther(serviceFee)
      });
    };
    
    this.project.on('FundsReleased', handler);
    this.listeners.set('FundsReleased', handler);
  }
  
  removeAllListeners() {
    this.listeners.forEach((handler, event) => {
      this.project.off(event, handler);
    });
    this.listeners.clear();
  }
}

// Usage in React
function useProjectEvents(projectAddress) {
  const [donations, setDonations] = useState([]);
  
  useEffect(() => {
    const listener = new EventListener(projectAddress, ProjectABI);
    
    listener.onDonation((donation) => {
      setDonations(prev => [donation, ...prev]);
    });
    
    return () => {
      listener.removeAllListeners();
    };
  }, [projectAddress]);
  
  return donations;
}
```

## Token Donation Example

```javascript
// src/utils/tokenDonation.js
import { ethers } from 'ethers';
import ERC20ABI from '../abis/ERC20.json';

async function donateToken(
  projectAddress,
  tokenAddress,
  amount,
  decimals = 18
) {
  const provider = new ethers.BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  
  const project = new ethers.Contract(projectAddress, ProjectABI, signer);
  const token = new ethers.Contract(tokenAddress, ERC20ABI, signer);
  
  const amountWei = ethers.parseUnits(amount.toString(), decimals);
  
  // Check balance
  const balance = await token.balanceOf(await signer.getAddress());
  if (balance < amountWei) {
    throw new Error('Insufficient token balance');
  }
  
  // Check and approve
  const allowance = await token.allowance(
    await signer.getAddress(),
    projectAddress
  );
  
  if (allowance < amountWei) {
    console.log('Approving token...');
    const approveTx = await token.approve(projectAddress, amountWei);
    await approveTx.wait();
    console.log('Token approved');
  }
  
  // Donate
  const tx = await project.donateToken(tokenAddress, amountWei);
  const receipt = await tx.wait();
  
  return receipt;
}
```

## Complete Dashboard Example

```jsx
// src/components/Dashboard.jsx
import React, { useState, useEffect } from 'react';
import { useAquaFund } from '../hooks/useAquaFund';

function Dashboard() {
  const { getStats, registry, getUserBadges } = useAquaFund();
  const [stats, setStats] = useState(null);
  const [badges, setBadges] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    loadDashboard();
  }, []);
  
  async function loadDashboard() {
    try {
      const [platformStats, userBadges] = await Promise.all([
        getStats(),
        getUserBadges(await signer.getAddress())
      ]);
      
      setStats(platformStats);
      setBadges(userBadges);
    } catch (error) {
      console.error('Failed to load dashboard:', error);
    } finally {
      setLoading(false);
    }
  }
  
  if (loading) return <div>Loading...</div>;
  
  return (
    <div className="dashboard">
      <h1>AquaFund Dashboard</h1>
      
      <div className="stats">
        <div className="stat-card">
          <h3>Total Projects</h3>
          <p>{stats.totalProjects}</p>
        </div>
        <div className="stat-card">
          <h3>Total Raised</h3>
          <p>{stats.totalRaised} ETH</p>
        </div>
        <div className="stat-card">
          <h3>Total Donors</h3>
          <p>{stats.totalDonors}</p>
        </div>
      </div>
      
      <div className="badges-section">
        <h2>Your Badges</h2>
        {badges.length === 0 ? (
          <p>No badges yet. Make a donation to earn your first badge!</p>
        ) : (
          <div className="badge-grid">
            {badges.map(badge => (
              <div key={badge.tokenId} className="badge-card">
                <h4>{badge.tier} Badge</h4>
                <p>Project #{badge.projectId}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export default Dashboard;
```

## Error Handling Best Practices

```javascript
// src/utils/errorHandler.js
export function handleContractError(error) {
  if (error.code === 'ACTION_REJECTED') {
    return 'Transaction was rejected by user';
  }
  
  if (error.message.includes('InvalidAmount')) {
    return 'Donation amount is too small (minimum 0.001 ETH)';
  }
  
  if (error.message.includes('FundingGoalNotReached')) {
    return 'Funding goal has not been reached yet';
  }
  
  if (error.message.includes('UnauthorizedAccess')) {
    return 'You do not have permission to perform this action';
  }
  
  if (error.message.includes('Insufficient funds')) {
    return 'Insufficient balance for this transaction';
  }
  
  return 'Transaction failed. Please try again.';
}

// Usage
try {
  await donate(projectAddress, amount);
} catch (error) {
  const message = handleContractError(error);
  alert(message);
}
```

---

These examples should give you a solid foundation for integrating AquaFund into your application. Adapt them to your specific needs and framework!

