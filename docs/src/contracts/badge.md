# AquaFundBadge Contract

The `AquaFundBadge` contract is an ERC721 NFT contract that mints badges to donors based on their donation amounts. Badges serve as rewards and proof of contribution.

## Overview

The Badge contract:
- Mints NFT badges to donors
- Tracks badge metadata (project, donation amount, tier)
- Provides tier-based badges (Bronze, Silver, Gold, Platinum)
- Stores badge metadata on IPFS

## Badge Tiers

Badges are awarded based on total donation amount:

| Tier | Minimum Donation | Description |
|------|----------------|-------------|
| **Bronze** | 0.1 ETH | Entry level contributor |
| **Silver** | 1 ETH | Significant contributor |
| **Gold** | 10 ETH | Major contributor |
| **Platinum** | 100 ETH | Top tier contributor |

## Reading Badge Data

### Get User's Badges

```javascript
const userAddress = await signer.getAddress();
const badgeIds = await badge.getUserBadges(userAddress);
console.log(`User has ${badgeIds.length} badges`);

// Get details for each badge
for (const badgeId of badgeIds) {
  const metadata = await badge.getBadgeMetadata(badgeId);
  console.log('Badge:', {
    tokenId: badgeId.toString(),
    projectId: metadata.projectId.toString(),
    donationAmount: ethers.formatEther(metadata.donationAmount),
    tier: getTierName(metadata.tier),
    timestamp: new Date(Number(metadata.timestamp) * 1000)
  });
}
```

### Get Badge Metadata

```javascript
async function getBadgeInfo(badgeId) {
  const metadata = await badge.getBadgeMetadata(badgeId);
  
  // Get token URI (IPFS link)
  const tokenURI = await badge.tokenURI(badgeId);
  
  return {
    tokenId: badgeId.toString(),
    projectId: metadata.projectId.toString(),
    donationAmount: ethers.formatEther(metadata.donationAmount),
    tier: getTierName(metadata.tier),
    timestamp: new Date(Number(metadata.timestamp) * 1000),
    tokenURI
  };
}

// Helper to convert tier bytes4 to name
function getTierName(tierBytes) {
  const tiers = {
    '0x42726f6e': 'Bronze',
    '0x53696c76': 'Silver',
    '0x476f6c64': 'Gold',
    '0x506c6174': 'Platinum'
  };
  return tiers[tierBytes] || 'Unknown';
}
```

### Get Badge Count

```javascript
const userAddress = await signer.getAddress();
const count = await badge.getUserBadgeCount(userAddress);
console.log(`User has ${count} badges`);
```

### Get Token URI

```javascript
const badgeId = 1;
const tokenURI = await badge.tokenURI(badgeId);
console.log('Badge metadata URI:', tokenURI);
// This will be an IPFS link like: ipfs://Qm...

// Fetch metadata from IPFS
async function fetchBadgeMetadata(tokenURI) {
  const ipfsHash = tokenURI.replace('ipfs://', '');
  const response = await fetch(`https://ipfs.io/ipfs/${ipfsHash}`);
  const metadata = await response.json();
  return metadata;
}
```

### Check Badge Ownership

```javascript
// Using ERC721 standard function
const owner = await badge.ownerOf(badgeId);
const userAddress = await signer.getAddress();

if (owner.toLowerCase() === userAddress.toLowerCase()) {
  console.log('You own this badge!');
}
```

## Minting Badges

**Note:** Badges are typically minted automatically by the backend after a donation. The frontend usually doesn't need to call this directly.

### Mint Badge (Backend/Admin)

```javascript
async function mintBadge(donorAddress, projectId, donationAmount, ipfsMetadataURI) {
  const badge = new ethers.Contract(badgeAddress, BadgeABI, signer);
  
  try {
    const tx = await badge.mintBadge(
      donorAddress,
      projectId,
      ethers.parseEther(donationAmount.toString()),
      ipfsMetadataURI
    );
    
    const receipt = await tx.wait();
    
    // Find the BadgeMinted event
    const event = receipt.logs.find(
      log => log.topics[0] === ethers.id('BadgeMinted(address,uint256,uint256,bytes4,uint256)')
    );
    
    if (event) {
      const decoded = badge.interface.parseLog(event);
      console.log('Badge minted:', {
        to: decoded.args.to,
        tokenId: decoded.args.tokenId.toString(),
        projectId: decoded.args.projectId.toString(),
        tier: getTierName(decoded.args.tier),
        donationAmount: ethers.formatEther(decoded.args.donationAmount)
      });
    }
    
    return receipt;
  } catch (error) {
    console.error('Failed to mint badge:', error);
    throw error;
  }
}
```

## Badge Metadata Structure

Badge metadata stored on IPFS should follow this structure:

```json
{
  "name": "AquaFund Bronze Badge",
  "description": "Awarded for contributing 0.1 ETH to water project #1",
  "image": "ipfs://Qm...",
  "attributes": [
    {
      "trait_type": "Tier",
      "value": "Bronze"
    },
    {
      "trait_type": "Project ID",
      "value": "1"
    },
    {
      "trait_type": "Donation Amount",
      "value": "0.1 ETH"
    },
    {
      "trait_type": "Date",
      "value": "2024-01-15"
    }
  ]
}
```

## Displaying Badges

### Display User's Badge Collection

```javascript
async function displayUserBadges(userAddress) {
  const badgeIds = await badge.getUserBadges(userAddress);
  
  const badges = await Promise.all(
    badgeIds.map(async (id) => {
      const metadata = await badge.getBadgeMetadata(id);
      const tokenURI = await badge.tokenURI(id);
      
      // Fetch IPFS metadata
      const ipfsHash = tokenURI.replace('ipfs://', '');
      const ipfsData = await fetch(`https://ipfs.io/ipfs/${ipfsHash}`).then(r => r.json());
      
      return {
        tokenId: id.toString(),
        tier: getTierName(metadata.tier),
        projectId: metadata.projectId.toString(),
        donationAmount: ethers.formatEther(metadata.donationAmount),
        image: ipfsData.image,
        name: ipfsData.name
      };
    })
  );
  
  return badges;
}

// Usage in React component
function BadgeCollection({ userAddress }) {
  const [badges, setBadges] = useState([]);
  
  useEffect(() => {
    displayUserBadges(userAddress).then(setBadges);
  }, [userAddress]);
  
  return (
    <div className="badge-grid">
      {badges.map(badge => (
        <div key={badge.tokenId} className="badge-card">
          <img src={badge.image} alt={badge.name} />
          <h3>{badge.name}</h3>
          <p>Tier: {badge.tier}</p>
          <p>Project: #{badge.projectId}</p>
        </div>
      ))}
    </div>
  );
}
```

### Check Next Tier

```javascript
async function getNextTier(userAddress) {
  const totalDonated = await factory.getTotalDonated(userAddress);
  const totalInEth = Number(ethers.formatEther(totalDonated));
  
  const tiers = [
    { name: 'Bronze', threshold: 0.1 },
    { name: 'Silver', threshold: 1 },
    { name: 'Gold', threshold: 10 },
    { name: 'Platinum', threshold: 100 }
  ];
  
  const currentTier = tiers
    .reverse()
    .find(tier => totalInEth >= tier.threshold);
  
  const nextTier = tiers.find(tier => totalInEth < tier.threshold);
  
  if (nextTier) {
    const remaining = nextTier.threshold - totalInEth;
    return {
      current: currentTier?.name || 'None',
      next: nextTier.name,
      remaining: remaining.toFixed(4),
      progress: (totalInEth / nextTier.threshold * 100).toFixed(2)
    };
  }
  
  return {
    current: 'Platinum',
    next: null,
    message: 'You\'ve reached the highest tier!'
  };
}
```

## Events

### Listen to Badge Mints

```javascript
badge.on('BadgeMinted', (to, tokenId, projectId, tier, donationAmount) => {
  console.log('New badge minted:', {
    to,
    tokenId: tokenId.toString(),
    projectId: projectId.toString(),
    tier: getTierName(tier),
    donationAmount: ethers.formatEther(donationAmount)
  });
  
  // Update UI
  refreshBadgeCollection();
});
```

## Complete Example

```javascript
import { ethers } from 'ethers';
import BadgeABI from './abis/AquaFundBadge.json';

class AquaFundBadgeClient {
  constructor(badgeAddress, signer) {
    this.badge = new ethers.Contract(badgeAddress, BadgeABI, signer);
    this.provider = signer.provider;
  }
  
  async getUserBadges(userAddress) {
    const badgeIds = await this.badge.getUserBadges(userAddress);
    
    return Promise.all(
      badgeIds.map(async (id) => {
        const metadata = await this.badge.getBadgeMetadata(id);
        const tokenURI = await this.badge.tokenURI(id);
        
        return {
          tokenId: id.toString(),
          projectId: metadata.projectId.toString(),
          donationAmount: ethers.formatEther(metadata.donationAmount),
          tier: this.getTierName(metadata.tier),
          timestamp: new Date(Number(metadata.timestamp) * 1000),
          tokenURI
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
  
  async getBadgeInfo(badgeId) {
    const metadata = await this.badge.getBadgeMetadata(badgeId);
    const tokenURI = await this.badge.tokenURI(badgeId);
    const owner = await this.badge.ownerOf(badgeId);
    
    return {
      tokenId: badgeId.toString(),
      owner,
      projectId: metadata.projectId.toString(),
      donationAmount: ethers.formatEther(metadata.donationAmount),
      tier: this.getTierName(metadata.tier),
      timestamp: new Date(Number(metadata.timestamp) * 1000),
      tokenURI
    };
  }
}

// Usage
const badgeClient = new AquaFundBadgeClient(badgeAddress, signer);
const myBadges = await badgeClient.getUserBadges(userAddress);
```

## Best Practices

1. **Cache badge data** - Don't fetch IPFS metadata on every render
2. **Handle IPFS loading** - Use fallback images while loading from IPFS
3. **Show tier progress** - Display progress toward next tier
4. **Display badges prominently** - Badges are a key engagement feature
5. **Support badge transfers** - Users may want to transfer badges (ERC721 standard)
6. **Index badge events** - Use The Graph or similar for efficient queries

---

**Next:** Learn about the [Registry Contract](./registry.md) for project discovery.

