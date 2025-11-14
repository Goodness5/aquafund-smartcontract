# AquaFundRegistry Contract

The `AquaFundRegistry` provides centralized project discovery, filtering, and platform analytics. It's designed for efficient querying and pagination.

## Overview

The Registry contract:
- Indexes all projects for easy discovery
- Provides filtered project lists (by status)
- Offers pagination support for large datasets
- Aggregates platform-wide statistics

## Reading Registry Data

### Get Platform Statistics

```javascript
const stats = await registry.getPlatformStats();

// Returns:
// {
//   totalProjects: BigNumber,
//   activeProjects: BigNumber,
//   fundedProjects: BigNumber,
//   completedProjects: BigNumber,
//   totalFundsRaised: BigNumber,
//   totalDonations: BigNumber,
//   totalDonors: BigNumber
// }

const formatted = {
  totalProjects: stats.totalProjects.toString(),
  activeProjects: stats.activeProjects.toString(),
  fundedProjects: stats.fundedProjects.toString(),
  completedProjects: stats.completedProjects.toString(),
  totalFundsRaised: ethers.formatEther(stats.totalFundsRaised),
  totalDonations: stats.totalDonations.toString(),
  totalDonors: stats.totalDonors.toString()
};
```

### Get All Project IDs

```javascript
// Note: This can be gas-intensive for many projects
// Consider using pagination instead
const allProjectIds = await registry.getAllProjectIds();
console.log(`Total projects: ${allProjectIds.length}`);
```

### Get Projects by Status

```javascript
// ProjectStatus enum: 0=Active, 1=Funded, 2=Completed, 3=Cancelled, 4=Refunded

// Get active projects
const activeProjects = await registry.getProjectsByStatus(0);
console.log(`Active projects: ${activeProjects.length}`);

// Get funded projects
const fundedProjects = await registry.getProjectsByStatus(1);
console.log(`Funded projects: ${fundedProjects.length}`);

// Get completed projects
const completedProjects = await registry.getProjectsByStatus(2);
console.log(`Completed projects: ${completedProjects.length}`);
```

### Get Project Details

```javascript
async function getProjectDetails(projectId) {
  const info = await registry.getProjectDetails(projectId);
  
  return {
    projectId: info.projectId.toString(),
    admin: info.admin,
    fundingGoal: ethers.formatEther(info.fundingGoal),
    fundsRaised: ethers.formatEther(info.fundsRaised),
    status: ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'][info.status],
    metadataUri: info.metadataUri,
    progress: (Number(info.fundsRaised) / Number(info.fundingGoal) * 100).toFixed(2) + '%'
  };
}

// Usage
const project = await getProjectDetails(1);
console.log('Project:', project);
```

### Get Paginated Projects

```javascript
async function getProjectsPage(page = 0, pageSize = 10) {
  const offset = page * pageSize;
  const { projectIds, addresses } = await registry.getProjectsPaginated(offset, pageSize);
  
  return projectIds.map((id, i) => ({
    id: id.toString(),
    address: addresses[i]
  }));
}

// Usage
const page1 = await getProjectsPage(0, 10); // First 10 projects
const page2 = await getProjectsPage(1, 10);   // Next 10 projects
```

## Building Project Lists

### Get Active Projects with Details

```javascript
async function getActiveProjectsWithDetails() {
  // Get active project IDs
  const projectIds = await registry.getProjectsByStatus(0);
  
  // Get details for each project
  const projects = await Promise.all(
    projectIds.map(async (id) => {
      const info = await registry.getProjectDetails(id);
      const projectAddress = await factory.getProjectAddress(id);
      
      return {
        projectId: id.toString(),
        address: projectAddress,
        admin: info.admin,
        fundingGoal: ethers.formatEther(info.fundingGoal),
        fundsRaised: ethers.formatEther(info.fundsRaised),
        status: 'Active',
        progress: (Number(info.fundsRaised) / Number(info.fundingGoal) * 100).toFixed(2)
      };
    })
  );
  
  return projects;
}
```

### Search and Filter Projects

```javascript
class ProjectBrowser {
  constructor(registry, factory) {
    this.registry = registry;
    this.factory = factory;
  }
  
  async getProjects(filters = {}) {
    let projectIds;
    
    // Filter by status if provided
    if (filters.status !== undefined) {
      projectIds = await this.registry.getProjectsByStatus(filters.status);
    } else {
      // Get all projects (paginated)
      const { projectIds: ids } = await this.registry.getProjectsPaginated(
        filters.offset || 0,
        filters.limit || 20
      );
      projectIds = ids;
    }
    
    // Get details for each project
    const projects = await Promise.all(
      projectIds.map(async (id) => {
        const info = await this.registry.getProjectDetails(id);
        const projectAddress = await this.factory.getProjectAddress(id);
        
        return {
          projectId: id.toString(),
          address: projectAddress,
          admin: info.admin,
          fundingGoal: ethers.formatEther(info.fundingGoal),
          fundsRaised: ethers.formatEther(info.fundsRaised),
          status: ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'][info.status],
          progress: (Number(info.fundsRaised) / Number(info.fundingGoal) * 100).toFixed(2)
        };
      })
    );
    
    // Apply additional filters (client-side)
    let filtered = projects;
    
    if (filters.minProgress) {
      filtered = filtered.filter(p => parseFloat(p.progress) >= filters.minProgress);
    }
    
    if (filters.maxProgress) {
      filtered = filtered.filter(p => parseFloat(p.progress) <= filters.maxProgress);
    }
    
    // Sort
    if (filters.sortBy === 'progress') {
      filtered.sort((a, b) => parseFloat(b.progress) - parseFloat(a.progress));
    } else if (filters.sortBy === 'fundsRaised') {
      filtered.sort((a, b) => parseFloat(b.fundsRaised) - parseFloat(a.fundsRaised));
    }
    
    return filtered;
  }
}

// Usage
const browser = new ProjectBrowser(registry, factory);

// Get active projects sorted by progress
const activeProjects = await browser.getProjects({
  status: 0,
  sortBy: 'progress'
});

// Get all projects with pagination
const allProjects = await browser.getProjects({
  offset: 0,
  limit: 20,
  sortBy: 'fundsRaised'
});
```

## Dashboard Implementation

### Build a Project Dashboard

```javascript
async function buildDashboard() {
  const stats = await registry.getPlatformStats();
  
  // Get projects by status
  const [active, funded, completed] = await Promise.all([
    registry.getProjectsByStatus(0),
    registry.getProjectsByStatus(1),
    registry.getProjectsByStatus(2)
  ]);
  
  // Get recent projects (last 10)
  const totalProjects = stats.totalProjects;
  const recentStart = totalProjects > 10 ? totalProjects - 10 : 0;
  const { projectIds: recentIds } = await registry.getProjectsPaginated(
    recentStart,
    10
  );
  
  const recentProjects = await Promise.all(
    recentIds.map(id => registry.getProjectDetails(id))
  );
  
  return {
    stats: {
      totalProjects: stats.totalProjects.toString(),
      activeProjects: stats.activeProjects.toString(),
      fundedProjects: stats.fundedProjects.toString(),
      completedProjects: stats.completedProjects.toString(),
      totalFundsRaised: ethers.formatEther(stats.totalFundsRaised),
      totalDonations: stats.totalDonations.toString(),
      totalDonors: stats.totalDonors.toString()
    },
    projects: {
      active: active.length,
      funded: funded.length,
      completed: completed.length,
      recent: recentProjects.map(p => ({
        projectId: p.projectId.toString(),
        fundsRaised: ethers.formatEther(p.fundsRaised),
        fundingGoal: ethers.formatEther(p.fundingGoal)
      }))
    }
  };
}
```

## Complete Example

```javascript
import { ethers } from 'ethers';
import RegistryABI from './abis/AquaFundRegistry.json';
import FactoryABI from './abis/AquaFundFactory.json';

class AquaFundRegistryClient {
  constructor(registryAddress, factoryAddress, signer) {
    this.registry = new ethers.Contract(registryAddress, RegistryABI, signer);
    this.factory = new ethers.Contract(factoryAddress, FactoryABI, signer);
    this.provider = signer.provider;
  }
  
  async getStats() {
    const stats = await this.registry.getPlatformStats();
    return {
      totalProjects: stats.totalProjects.toString(),
      activeProjects: stats.activeProjects.toString(),
      fundedProjects: stats.fundedProjects.toString(),
      completedProjects: stats.completedProjects.toString(),
      totalFundsRaised: ethers.formatEther(stats.totalFundsRaised),
      totalDonations: stats.totalDonations.toString(),
      totalDonors: stats.totalDonors.toString()
    };
  }
  
  async getProjectsByStatus(status) {
    const projectIds = await this.registry.getProjectsByStatus(status);
    
    return Promise.all(
      projectIds.map(async (id) => {
        const info = await this.registry.getProjectDetails(id);
        const address = await this.factory.getProjectAddress(id);
        
        return {
          projectId: id.toString(),
          address,
          admin: info.admin,
          fundingGoal: ethers.formatEther(info.fundingGoal),
          fundsRaised: ethers.formatEther(info.fundsRaised),
          status: ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'][info.status],
          progress: (Number(info.fundsRaised) / Number(info.fundingGoal) * 100).toFixed(2)
        };
      })
    );
  }
  
  async getProjectsPage(page = 0, pageSize = 10) {
    const offset = page * pageSize;
    const { projectIds, addresses } = await this.registry.getProjectsPaginated(offset, pageSize);
    
    return Promise.all(
      projectIds.map(async (id, i) => {
        const info = await this.registry.getProjectDetails(id);
        return {
          projectId: id.toString(),
          address: addresses[i],
          admin: info.admin,
          fundingGoal: ethers.formatEther(info.fundingGoal),
          fundsRaised: ethers.formatEther(info.fundsRaised),
          status: ['Active', 'Funded', 'Completed', 'Cancelled', 'Refunded'][info.status],
          progress: (Number(info.fundsRaised) / Number(info.fundingGoal) * 100).toFixed(2)
        };
      })
    );
  }
}

// Usage
const registry = new AquaFundRegistryClient(registryAddress, factoryAddress, signer);
const stats = await registry.getStats();
const activeProjects = await registry.getProjectsByStatus(0);
const page1 = await registry.getProjectsPage(0, 10);
```

## Best Practices

1. **Use pagination** - Always use `getProjectsPaginated()` for large lists
2. **Cache statistics** - Platform stats don't change frequently
3. **Filter client-side** - Get all IDs, then filter/sort in JavaScript
4. **Batch requests** - Use `Promise.all()` for parallel queries
5. **Index off-chain** - For production, use The Graph or similar for complex queries
6. **Handle empty states** - Check for empty arrays before rendering

---

**Next:** Check out [Examples](./examples.md) for complete integration examples.

