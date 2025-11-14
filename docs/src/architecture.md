# AquaFund Smart Contract Architecture

## Overview

AquaFund uses a factory pattern with minimal proxies (EIP-1167) for gas-efficient project creation. The architecture consists of four main contracts working together to provide a transparent, secure, and efficient crowdfunding platform.

## Contract Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  AquaFundFactory                        │
│  - Creates project clones                               │
│  - Manages roles and permissions                        │
│  - Configures service fees                              │
│  - Integrates with Badge & Registry                     │
└──────────────┬──────────────────────────────────────────┘
               │
               │ creates clones using
               │ minimal proxy (EIP-1167)
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│              AquaFundProject (Implementation)           │
│  - Donation handling (ETH & ERC20)                      │
│  - Fund escrow management                               │
│  - Evidence submission                                  │
│  - Status tracking                                      │
│  - Badge minting integration                            │
└──────────────┬──────────────────────────────────────────┘
               │
               │ each clone delegates to implementation
               │
               ▼
┌─────────────────────────────────────────────────────────┐
│        AquaFundProject Clone 1, 2, 3... (minimal)      │
│  Each project is a minimal proxy (55 bytes)             │
│  Delegates all calls to implementation                  │
│  Has its own storage                                    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  AquaFundBadge (ERC721)                 │
│  - Mints badges on donations                            │
│  - Tier-based badges (Bronze/Silver/Gold/Platinum)     │
│  - Tracks donation metadata                            │
└─────────────────────────────────────────────────────────┘
               ▲
               │ minted by
               │
┌─────────────────────────────────────────────────────────┐
│              AquaFundRegistry                           │
│  - Platform analytics                                   │
│  - Project discovery                                    │
│  - Aggregated statistics                                │
└─────────────────────────────────────────────────────────┘
```

## Gas Optimization Strategies

### 1. Minimal Proxy Pattern (EIP-1167)
- **Savings**: ~95% gas reduction per project creation
- **How**: Each project is a 55-byte minimal proxy that delegates to the implementation
- **Trade-off**: Slightly higher gas cost per function call (delegatecall overhead)

### 2. Packed Storage
- Struct fields are packed to minimize storage slots
- Example: `ProjectStatus` uses enum (1 byte) instead of uint256

### 3. Custom Errors
- Uses Solidity custom errors instead of require strings
- Saves ~50% gas on revert

### 4. Events Optimization
- Indexed parameters for efficient filtering
- Minimal event data (only essential fields)

### 5. Unchecked Arithmetic
- Used where overflow is impossible (e.g., loop increments)
- Saves ~30 gas per operation

### 6. Efficient Data Structures
- Mappings for O(1) lookups
- Arrays only where iteration is necessary

## Security Features

### Access Control
- **OpenZeppelin AccessControl**: Role-based permissions
- **Roles**:
  - `DEFAULT_ADMIN_ROLE`: Full system admin
  - `ADMIN_ROLE`: Factory admin (fee updates, grants PROJECT_CREATOR_ROLE, etc.)
  - `PROJECT_CREATOR_ROLE`: Can create projects (granted to verified NGOs/organizations)
  - `MINTER_ROLE`: Can mint badges

### Role Hierarchy

**Factory Admin** (`ADMIN_ROLE`):
- Manages platform settings (fees, treasury)
- Grants/revokes `PROJECT_CREATOR_ROLE` to NGOs
- Can pause project creation

**Project Creator** (`PROJECT_CREATOR_ROLE`):
- Granted by factory admin to verified NGOs/organizations
- Can call `createProject()` to create new projects
- When creating a project, specifies a `projectAdminAddress`

**Project Admin**:
- The address specified when creating a project
- Becomes the owner of that specific project contract
- Can release funds, submit evidence, update status, issue refunds for that project only
- Different from the project creator (can be the same address, but doesn't have to be)

### Reentrancy Protection
- `ReentrancyGuard` on all state-changing functions
- NonReentrant modifier on:
  - `donate()`
  - `donateToken()`
  - `releaseFunds()`
  - `refundDonor()`
  - `refundAllDonors()`

### Safe Token Transfers
- `SafeERC20` for all ERC20 operations
- Checks return values
- Handles non-standard tokens

### Input Validation
- Zero address checks
- Amount validation (minimum donation)
- Status transition validation

### Pausable
- Factory can be paused for emergency stops
- Prevents new project creation
- Existing projects continue to function

## Workflow

### 1. Project Creation
```
Factory Admin (ADMIN_ROLE)
    ↓
Grants PROJECT_CREATOR_ROLE to NGO
    ↓
NGO with PROJECT_CREATOR_ROLE
    ↓
Factory.createProject(projectAdminAddress, ...)
    ↓
Clone created (minimal proxy)
    ↓
Project.initialize() called with projectAdminAddress
    ↓
Project ownership transferred to projectAdminAddress
    ↓
Project registered in Factory & Registry
```

### 2. Donation Flow
```
Donor
    ↓
Project.donate() or donateToken()
    ↓
ReentrancyGuard protection
    ↓
Funds held in project contract
    ↓
Badge minted (if badge contract set)
    ↓
Event emitted (DonationReceived)
    ↓
Status auto-updates to Funded if goal reached
```

### 3. Fund Release
```
Project Admin
    ↓
Project.releaseFunds()
    ↓
Service fee calculated (10%)
    ↓
Service fee → Treasury
    ↓
Remaining funds → Project Admin
    ↓
Status → Completed
```

### 4. Evidence Submission
```
Project Admin
    ↓
Project.submitEvidence(ipfsHash)
    ↓
Evidence stored on-chain
    ↓
Event emitted (EvidenceSubmitted)
```

## State Management

### Project States
1. **Active**: Accepting donations, goal not reached
2. **Funded**: Goal reached, funds ready to release
3. **Completed**: Funds released, project completed
4. **Cancelled**: Project cancelled, refunds available
5. **Refunded**: Refunds issued to donors

### State Transitions
- Active → Funded: Automatic when goal reached
- Active/Funded → Cancelled: Admin action
- Cancelled → Refunded: After refunds issued
- Funded → Completed: After funds released

## Integration Points

### Frontend Integration
- Read project data via view functions
- Listen to events for real-time updates
- Call donation functions via wallet (MetaMask, etc.)

### Backend Integration
- Index blockchain events
- Cache project data
- Aggregate statistics
- Handle metadata (IPFS hashes)

### External Services
- **IPFS**: Store project metadata, images, evidence
- **Oracle**: Price feeds for multi-currency support (future)
- **KYC**: Admin verification (off-chain)

## Deployment Considerations

### Contract Dependencies
1. Deploy Implementation
2. Deploy Factory (references implementation)
3. Deploy Badge (references factory)
4. Deploy Registry
5. Configure all contracts

### Initial Setup
1. Grant PROJECT_CREATOR_ROLE to verified NGOs
2. Set badge base URI
3. Configure treasury address
4. Set service fee (default 10%)
5. Test on testnet first

### Upgrade Considerations
- Implementation is not upgradeable (by design for transparency)
- Factory can update fee structure
- Badge contract can update base URI
- Registry is standalone (can be redeployed)

## Gas Costs (Estimates)

- **Create Project**: ~200k gas (minimal proxy vs ~2M for full deployment)
- **Donate ETH**: ~80k gas
- **Donate ERC20**: ~100k gas (includes approval)
- **Release Funds**: ~60k gas
- **Submit Evidence**: ~50k gas
- **Mint Badge**: ~90k gas

## Limitations & Future Enhancements

### Current Limitations
- Fixed service fee per project (10%)
- No partial fund releases (milestone-based)
- No multi-currency automatic conversion
- Evidence stored as hashes only (full data on IPFS)

### Future Enhancements
- Milestone-based funding
- Multi-currency support with price oracles
- DAO governance for fee changes
- Automated KYC integration
- Cross-chain support (Layer 2, other chains)

## Testing Strategy

1. **Unit Tests**: Individual function testing
2. **Integration Tests**: Contract interaction testing
3. **Gas Optimization Tests**: Verify gas costs
4. **Security Tests**: Reentrancy, access control
5. **Fuzz Testing**: Random input validation
6. **Formal Verification**: Critical functions (future)

## Audit Checklist

- [ ] Third-party security audit
- [ ] Gas optimization review
- [ ] Access control review
- [ ] Reentrancy testing
- [ ] Edge case testing
- [ ] Front-running protection review
- [ ] Documentation review

---

**Note**: This architecture prioritizes security, transparency, and gas efficiency while maintaining flexibility for future enhancements.

