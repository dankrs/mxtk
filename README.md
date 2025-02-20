# MXTK Smart Contract Documentation

## Overview

MXTK (Mineral Token) is an ERC20-compliant token implemented on Arbitrum that represents real-world mineral assets. The contract includes features for asset management, fee handling, and Uniswap V3 integration.

## Contract Features

### Core Functionality

- **ERC20 Standard Implementation**: Implements standard token features (transfer, approve, etc.)
- **Upgradeable Design**: Uses OpenZeppelin's UUPS upgrade pattern
- **Pausable Operations**: Allows pausing token transfers in emergency situations
- **Burnable Tokens**: Supports token burning functionality
- **Permit Support**: Implements ERC20Permit for gasless approvals

### Asset Management

- **Mineral Holdings**: Tracks real-world mineral assets using IPFS CIDs
- **Price Oracles**: Integration with Chainlink price feeds for mineral valuations
- **Asset Value Calculation**: Computes total asset value and token price based on holdings

### Fee Mechanism

- **Transfer Fees**: Configurable fee system in basis points (bps)
- **Fee Exclusions**: Ability to exclude addresses from transfer fees
- **Admin Fee Collection**: Automated fee collection system for mineral additions

### Security Features

- **Reentrancy Protection**: Implements ReentrancyGuard for critical functions
- **Access Control**: Owner-restricted administrative functions
- **Account Freezing**: Ability to freeze malicious accounts
- **Force Burn**: Emergency token burning capability

## Recent Updates for Uniswap V3 Integration

### New Constants

solidity
address public constant ARBITRUM_UNIVERSAL_ROUTER = 0xa51afafe0263b40edaef0df8781ea9aa03e381a3;
bool public isRouterWhitelisted;

### New Functions

#### setZeroFeeAndWhitelistArbitrumRouter

```solidity
function setZeroFeeAndWhitelistArbitrumRouter(bool isTestnet) external onlyOwner
```

- Sets transfer fees to zero
- Whitelists appropriate Universal Router based on network (mainnet or testnet)
- Can only be called once
- Must be called before creating Uniswap V3 pools

#### isRouterProperlyConfigured

```solidity
function isRouterProperlyConfigured() public view returns (bool)
```

- Verifies proper router configuration
- Checks if:
  - Universal Router is whitelisted
  - Transfer fees are set to zero
  - Router whitelist process is complete

### New Events

```solidity
event RouterWhitelisted(address indexed router);
```

- Emitted when the Universal Router is whitelisted

## Integration with Uniswap V3

### Prerequisites

1. Deploy MXTK contract
2. Call `setZeroFeeAndWhitelistArbitrumRouter()`
3. Verify setup using `isRouterProperlyConfigured()`
4. Create Uniswap V3 pool

### Important Notes

- Router whitelisting must be done before any pool creation or swaps
- Transfer fees must remain at zero for proper Uniswap V3 functionality
- The Universal Router address is hardcoded for Arbitrum network

## Uniswap V3 Integration Details

### Universal Router Addresses

#### Mainnet (Arbitrum One)

```solidity
// Universal Router V2
address constant ARBITRUM_UNIVERSAL_ROUTER = 0xa51afafe0263b40edaef0df8781ea9aa03e381a3;

// Permit2 (same for all networks)
address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
```

#### Testnet (Base Sepolia)

```solidity
// Universal Router V1
address constant BASE_SEPOLIA_UNIVERSAL_ROUTER = 0x95273d871c8156636e114b63797d78D7E1720d81;

// Permit2 (same for all networks)
address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
```

### Address Verification Sources

- Mainnet Router: [Universal Router Arbitrum Deployment](https://github.com/Uniswap/universal-router/blob/main/deploy-addresses/arbitrum.json)
- Testnet Router: [Universal Router Base Sepolia Deployment](https://github.com/Uniswap/universal-router/blob/main/deploy-addresses/base-sepolia.json)
- These addresses are official Uniswap deployments and should be carefully verified before use

### Universal Router Configuration

#### Important Prerequisites

Before creating any Uniswap V3 pools or executing any swaps, the following steps MUST be completed in order:

1. **Initial Contract Deployment**
   - Deploy implementation contract
   - Deploy proxy contract
   - Initialize with `initialize(address initialOwner)`

2. **Router Whitelisting Process**

   ```solidity
   // Step 1: Call the whitelisting function (specify network)
   setZeroFeeAndWhitelistArbitrumRouter(bool isTestnet)
   
   // Step 2: Verify configuration
   isRouterProperlyConfigured(bool isTestnet)
   ```

3. **Permit2 and Router Approvals**

   ```solidity
   // Step 3: Approve Permit2
   approvePermit2()
   
   // Step 4: Approve Router
   approveRouter()
   ```

#### Verification Checklist

After configuration, verify ALL of the following:

1. **Router Status**

   ```solidity
   // Check if correct router is excluded from fees (based on network)
   excludedFromFees[ROUTER_ADDRESS] == true
   
   // Verify whitelist status
   isRouterWhitelisted == true
   ```

2. **Fee Configuration**

   ```solidity
   // Confirm gas fees are set to zero
   gasFeePercentageBps == 0
   ```

3. **Permit2 Configuration**

   ```solidity
   // Verify Permit2 allowance
   allowance(address(this), PERMIT2) == type(uint256).max
   ```

4. **Complete Verification**

   ```solidity
   // Single call to verify all conditions
   isRouterProperlyConfigured(isTestnet) == true
   ```

#### Critical Notes

- **Network Specific**: Use appropriate router address for your target network
- **One-Time Operation**: Router whitelisting can only be called ONCE per deployment
- **Irreversible Process**: Once the router is whitelisted, it cannot be un-whitelisted
- **Timing Critical**: Must be completed before ANY Uniswap V3 pool creation
- **Permit2 Consistency**: Permit2 address is the same across all networks

### Deployment Network Selection

#### Mainnet Deployment

```javascript
// Deploy with mainnet configuration
await mxtk.setZeroFeeAndWhitelistArbitrumRouter(false);
```

#### Testnet Deployment (Base Sepolia)

```javascript
// Deploy with testnet configuration
await mxtk.setZeroFeeAndWhitelistArbitrumRouter(true);
```

### Troubleshooting Router Configuration

#### Common Issues

1. **Wrong Network Router**
   - Cause: Using mainnet router on testnet or vice versa
   - Solution: Verify network and use appropriate router address
   - Prevention: Use isTestnet parameter correctly

### Security Considerations

#### Router Integration

- Universal Router address is immutable
- Whitelisting process is one-way
- Fee settings are critical for operation

#### Verification Process

1. **Initial Setup**

   ```solidity
   // Call whitelisting function
   setZeroFeeAndWhitelistArbitrumRouter()
   ```

2. **Comprehensive Checks**

   ```solidity
   // Check all conditions
   require(isRouterProperlyConfigured(), "Router not properly configured");
   require(excludedFromFees[ARBITRUM_UNIVERSAL_ROUTER], "Router not excluded from fees");
   require(gasFeePercentageBps == 0, "Fees not set to zero");
   require(isRouterWhitelisted, "Router not whitelisted");
   ```

3. **Event Verification**
   - Confirm `RouterWhitelisted` event emitted
   - Verify event parameters match expected values

## Technical Specifications

### Contract Dependencies

- OpenZeppelin Contracts (Upgradeable)
  - ERC20
  - ERC20Burnable
  - ERC20Pausable
  - ERC20Permit
  - Ownable
  - UUPSUpgradeable
  - ReentrancyGuard
- Chainlink Aggregator Interface

### Network Details

- Network: Arbitrum
- Universal Router V2: `0xa51afafe0263b40edaef0df8781ea9aa03e381a3`

### Gas Optimization

- Uses unchecked blocks for counter increments
- Implements efficient storage patterns
- Optimizes loop operations

## Security Considerations

### Critical Operations

- Router whitelisting is irreversible
- Fee changes restricted to owner
- Upgrade functionality protected by UUPS pattern

### Best Practices

- Always verify `isRouterProperlyConfigured()` before pool creation
- Monitor events for important state changes
- Regular audits of mineral price updates

## Events

The contract emits various events for tracking important operations:

- RouterWhitelisted
- GasFeePercentageBpsUpdated
- MineralAdded
- HoldingBuyback
- AccountFrozen
- ForcedBurn
- TokenPriceUpdated
- And more...

## License

MIT License

## Deployment and Operation Guide

### Prerequisites for All Deployments

1. Environment Setup

```bash
# Install required packages
npm install -g hardhat
npm install -g @openzeppelin/hardhat-upgrades
npm install -g @nomiclabs/hardhat-ethers
```

2. Environment Variables

```bash
# .env.testnet
TESTNET_PRIVATE_KEY=your_testnet_private_key
BASE_SEPOLIA_RPC_URL=your_testnet_rpc
ETHERSCAN_API_KEY=your_etherscan_api_key

# .env.mainnet
MAINNET_PRIVATE_KEY=your_mainnet_private_key
ARBITRUM_MAINNET_RPC_URL=your_mainnet_rpc
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### Testnet Deployment (Base Sepolia)

1. Network Configuration

```javascript
// hardhat.config.js
module.exports = {
  networks: {
    baseSepolia: {
      url: "https://sepolia.base.org",
      chainId: 84532,
      accounts: [process.env.TESTNET_PRIVATE_KEY]
    }
  }
}
```

2. Deploy Contract

```bash
# Deploy using testnet script
npx hardhat run scripts/deploy-testnet.js --network baseSepolia
```

3. Router Configuration

```javascript
// Testnet Universal Router: 0x95273d871c8156636e114b63797d78D7E1720d81
await mxtk.setZeroFeeAndWhitelistArbitrumRouter(true);
await mxtk.approvePermit2();
await mxtk.approveRouter();
```