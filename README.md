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
function setZeroFeeAndWhitelistArbitrumRouter() external onlyOwner
```

- Sets transfer fees to zero
- Whitelists Arbitrum's Universal Router
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

#### Testnet (Arbitrum Goerli)

```solidity
// Universal Router V1
address constant ARBITRUM_GOERLI_UNIVERSAL_ROUTER = 0x4648a43B2C14Da09FdF82B161150d3F634f40491;

// Permit2 (same for all networks)
address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
```

### Address Verification Sources

- Mainnet Router: [Universal Router Arbitrum Deployment](https://github.com/Uniswap/universal-router/blob/main/deploy-addresses/arbitrum.json)
- Testnet Router: [Universal Router Arbitrum Goerli Deployment](https://github.com/Uniswap/universal-router/blob/main/deploy-addresses/arbitrum-goerli.json)
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

#### Testnet Deployment

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

## Security Contact

<security@mineral-token.com>

## Deployment and Operation Guide

### Step 1: Initial Deployment

1. Deploy implementation contract
2. Deploy the proxy contract pointing to the implementation
3. Initialize the proxy contract by calling:

   ```solidity
   initialize(address initialOwner)
   ```

### Step 2: Initial Setup

1. Set initial mineral values (automatically done in initialize):

   ```solidity
   setInitialValues()
   ```

2. Port existing minerals (if applicable):

   ```solidity
   portExistingMinerals()
   ```

### Step 3: Uniswap V3 Integration Setup

1. Configure the Universal Router:

   ```solidity
   // For mainnet
   setZeroFeeAndWhitelistArbitrumRouter(false)
   // OR for testnet
   setZeroFeeAndWhitelistArbitrumRouter(true)
   ```

2. Verify the configuration:

   ```solidity
   // For mainnet
   isRouterProperlyConfigured(false)
   // OR for testnet
   isRouterProperlyConfigured(true)
   ```

   - Ensure this returns `true` before proceeding

3. Setup Permit2:

   ```solidity
   // Approve Permit2 for token operations
   approvePermit2()
   
   // Verify Permit2 approval
   allowance(address(this), PERMIT2) == type(uint256).max
   ```

4. Approve Universal Router:

   ```solidity
   // Approve Router for token operations
   approveRouter()
   
   // Verify Router approval (use appropriate router address based on network)
   allowance(address(this), ROUTER_ADDRESS) == type(uint256).max
   ```

### Step 4: Verification Checklist

Before proceeding with any Uniswap operations, verify:

1. Router Configuration:

   ```solidity
   // Check router status
   const routerAddress = isTestnet ? 
       ARBITRUM_GOERLI_UNIVERSAL_ROUTER : 
       ARBITRUM_UNIVERSAL_ROUTER;
   
   await excludedFromFees[routerAddress] // Should return true
   await isRouterWhitelisted() // Should return true
   await gasFeePercentageBps() // Should return 0
   ```

2. Permit2 Configuration:

   ```solidity
   // Check Permit2 allowance
   const permit2Allowance = await allowance(address(this), PERMIT2);
   permit2Allowance == type(uint256).max // Should be true
   ```

3. Router Approval:

   ```solidity
   // Check Router allowance
   const routerAllowance = await allowance(address(this), ROUTER_ADDRESS);
   routerAllowance == type(uint256).max // Should be true
   ```

### Step 5: Creating Uniswap V3 Pool

Only proceed after all above steps are completed and verified:

1. Create pool with desired parameters:
   - Token pair (MXTK + pair token)
   - Fee tier
   - Initial price range
   - Initial liquidity amounts

### Network-Specific Deployment Examples

#### Mainnet Deployment

```javascript
// 1. Deploy and initialize
const mxtk = await deployProxy("MXTK", [owner]);

// 2. Configure Router
await mxtk.setZeroFeeAndWhitelistArbitrumRouter(false);

// 3. Setup Permit2
await mxtk.approvePermit2();

// 4. Approve Router
await mxtk.approveRouter();

// 5. Verify Configuration
const isConfigured = await mxtk.isRouterProperlyConfigured(false);
require(isConfigured, "Router not properly configured");
```

#### Testnet Deployment

```javascript
// 1. Deploy and initialize
const mxtk = await deployProxy("MXTK", [owner]);

// 2. Configure Router
await mxtk.setZeroFeeAndWhitelistArbitrumRouter(true);

// 3. Setup Permit2
await mxtk.approvePermit2();

// 4. Approve Router
await mxtk.approveRouter();

// 5. Verify Configuration
const isConfigured = await mxtk.isRouterProperlyConfigured(true);
require(isConfigured, "Router not properly configured");
```

### Important Deployment Notes

1. **Order of Operations**:
   - Always complete router configuration before any pool creation
   - Permit2 approval must be done before any Universal Router operations
   - Router approval must be completed before any swaps

2. **Network Verification**:
   - Double-check network selection (mainnet vs testnet)
   - Verify router addresses match the network
   - Confirm Permit2 address is correct

3. **Security Considerations**:
   - Use different deployer accounts for testnet and mainnet
   - Keep private keys secure
   - Monitor gas costs during deployment

### Mineral Management

1. Add new minerals (owner only):

   ```solidity
   addMineralToHolding(
       address holdingOwner,
       string memory assetIpfsCID,
       string memory mineralSymbol,
       uint256 mineralOunces
   )
   ```

2. Update mineral price oracles:

   ```solidity
   updateMineralPriceOracle(
       string memory mineralSymbol,
       address priceOracleAddress,
       address ownerAddress
   )
   ```

### Fee Management (Optional)

- Exclude addresses from fees:

  ```solidity
  excludeFromFees(address account)
  ```

- Include addresses in fees:

  ```solidity
  includeInFees(address account)
  ```

- Update gas fee percentage:

  ```solidity
  setGasFeePercentageBps(uint256 _gasFeePercentageBps)
  ```

### Emergency Operations

- Pause all transfers:

  ```solidity
  pause()
  ```

- Unpause transfers:

  ```solidity
  unpause()
  ```

- Freeze malicious accounts:

  ```solidity
  setAccountFrozen(address account, bool frozen)
  ```

- Force burn tokens:

  ```solidity
  forceBurn(address account, uint256 amount)
  ```

### Monitoring and Maintenance

1. Regular checks:
   - Monitor token price:

     ```solidity
     getTokenValue()
     ```

   - Verify mineral values:

     ```solidity
     calculateMineralValueInWei(string memory mineralSymbol, uint256 mineralOunces)
     ```

   - Check holding values:

     ```solidity
     calculateHoldingValueInWei(address holdingOwner, string memory ipfsCid)
     ```

2. Event monitoring:
   - Watch for `RouterWhitelisted` events
   - Monitor `MineralAdded` events
   - Track `TokenPriceUpdated` events
   - Observe `GasFeePercentageBpsUpdated` events

### Common Operations Sequence

#### Adding New Minerals

1. Verify mineral symbol validity
2. Call `addMineralToHolding`
3. Update price oracle if needed
4. Verify total asset value updated

#### Buyback Process

1. Calculate holding value
2. Ensure sufficient token balance
3. Execute buyback:

   ```solidity
   buyBackHolding(address holdingOwner, string memory ipfsCID)
   ```

4. Verify holding removed and tokens burned

#### Upgrading Contract

1. Deploy new implementation
2. Call upgrade function through proxy
3. Verify new functionality
4. Update documentation

## Troubleshooting

### Common Issues and Solutions

1. **Router Configuration Fails**
   - Verify owner address
   - Ensure router not already whitelisted
   - Check gas fee percentage is settable

2. **Transfer Fees Issues**
   - Verify address exclusion status
   - Check current gas fee percentage
   - Ensure sufficient balance including fees

3. **Mineral Addition Fails**
   - Verify mineral symbol exists
   - Check IPFS CID format
   - Ensure no duplicate minerals

4. **Pool Creation Issues**
   - Double-check router configuration
   - Verify fee settings are at zero
   - Ensure sufficient token approvals

## Testing Guide

### Pre-deployment Testing

1. Deploy to testnet
2. Run through all setup steps
3. Verify mineral management
4. Test Uniswap integration
5. Validate emergency functions

### Post-deployment Verification

1. Confirm all events emitted
2. Verify token economics
3. Test transfer scenarios
4. Validate security features

# MXTK Testnet Deployment Guide

## Prerequisites

### Environment Setup

1. Install development tools:

   ```bash
   npm install -g hardhat
   npm install -g @openzeppelin/hardhat-upgrades
   npm install -g @nomiclabs/hardhat-ethers
   ```

2. Configure Arbitrum Goerli network:

   ```javascript
   // hardhat.config.js
   module.exports = {
     networks: {
       arbitrumGoerli: {
         url: "https://goerli-rollup.arbitrum.io/rpc",
         chainId: 421613,
         accounts: [process.env.PRIVATE_KEY]
       }
     }
   }
   ```

### Required Resources

1. MetaMask wallet with Arbitrum Goerli configured
   - Network Name: Arbitrum Goerli
   - RPC URL: <https://goerli-rollup.arbitrum.io/rpc>
   - Chain ID: 421613
   - Currency Symbol: AGOR

2. Get testnet ETH:
   - Visit Arbitrum Goerli Faucet
   - Request test ETH for deployment

3. Environment variables:

   ```bash
   # .env file
   PRIVATE_KEY=your_private_key
   ARBITRUM_GOERLI_RPC_URL=your_rpc_url
   ETHERSCAN_API_KEY=your_etherscan_api_key
   ```

## Step-by-Step Deployment Guide

### 1. Contract Preparation

1. Update Universal Router address for testnet:

   ```solidity
   // In MXTK.sol
   address public constant ARBITRUM_GOERLI_UNIVERSAL_ROUTER = 0x4C60051384bd2d3C01bfc845Cf5F4b44bcbE9de5;
   ```

2. Update Chainlink price feed addresses:

   ```solidity
   // Example for Gold price feed on Arbitrum Goerli
   MineralPricesOracle["AU"] = 0x86f27D72f5267f6b36d3F6C92F9635F3E808b9F2;
   ```

### 2. Deployment Script

Create `scripts/deploy-testnet.js`:

```javascript
const { ethers, upgrades } = require("hardhat");

async function main() {
    console.log("Deploying MXTK to Arbitrum Goerli...");

    // Deploy implementation
    const MXTK = await ethers.getContractFactory("MXTK");
    
    // Deploy proxy
    const mxtk = await upgrades.deployProxy(MXTK, 
        [process.env.OWNER_ADDRESS], // Constructor arguments
        { 
            initializer: 'initialize',
            kind: 'uups'
        }
    );

    await mxtk.deployed();
    console.log("MXTK deployed to:", mxtk.address);

    // Configure Universal Router (testnet)
    console.log("Configuring Universal Router...");
    await mxtk.setZeroFeeAndWhitelistArbitrumRouter(true);
    
    // Setup Permit2
    console.log("Setting up Permit2...");
    await mxtk.approvePermit2();
    
    // Approve Router
    console.log("Approving Router...");
    await mxtk.approveRouter();
    
    // Verify configuration
    const isConfigured = await mxtk.isRouterProperlyConfigured(true);
    console.log("Router properly configured:", isConfigured);

    // Wait for confirmations
    await mxtk.deployTransaction.wait(6);

    // Verify contract
    console.log("Verifying contract...");
    await hre.run("verify:verify", {
        address: mxtk.address,
        constructorArguments: [],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### 3. Deployment Steps

1. Deploy contract:

   ```bash
   npx hardhat run scripts/deploy-testnet.js --network arbitrumGoerli
   ```

2. Verify deployment:

   ```bash
   # Save deployment address
   export CONTRACT_ADDRESS="deployed_address"
   
   # Verify on Arbiscan
   npx hardhat verify --network arbitrumGoerli $CONTRACT_ADDRESS
   ```

3. Run post-deployment verification:

   ```javascript
   // scripts/verify-deployment.js
   async function main() {
       const mxtk = await ethers.getContractAt("MXTK", process.env.CONTRACT_ADDRESS);
       
       // Check router configuration
       const isConfigured = await mxtk.isRouterProperlyConfigured(true);
       console.log("Router configured:", isConfigured);
       
       // Check Permit2 allowance
       const permit2Allowance = await mxtk.allowance(
           mxtk.address, 
           "0x000000000022D473030F116dDEE9F6B43aC78BA3"
       );
       console.log("Permit2 allowance:", permit2Allowance.toString());
       
       // Check router allowance
       const routerAllowance = await mxtk.allowance(
           mxtk.address,
           "0x4C60051384bd2d3C01bfc845Cf5F4b44bcbE9de5"
       );
       console.log("Router allowance:", routerAllowance.toString());
   }
   ```

### 4. Testing Deployment

1. Basic transfer test:

   ```javascript
   // Test transfer
   await mxtk.transfer("recipient_address", ethers.utils.parseEther("1"));
   ```

2. Router integration test:

   ```javascript
   // Verify router exclusion
   const isExcluded = await mxtk.excludedFromFees(
       "0x4C60051384bd2d3C01bfc845Cf5F4b44bcbE9de5"
   );
   console.log("Router excluded from fees:", isExcluded);
   ```

### 5. Troubleshooting Common Issues

1. **Deployment Fails**
   - Check testnet ETH balance
   - Verify network configuration
   - Confirm contract size within limits

2. **Router Configuration Fails**
   - Ensure correct testnet addresses
   - Verify owner permissions
   - Check gas settings

3. **Verification Fails**
   - Wait for more block confirmations
   - Check contract source matches deployment
   - Verify constructor arguments

### 6. Next Steps

1. Create Uniswap V3 test pool:
   - Use testnet router address
   - Start with small liquidity amounts
   - Test basic swaps

2. Monitor contract:
   - Watch events on Arbiscan
   - Check router configuration periodically
   - Monitor fee settings

### Important Notes

- Always test thoroughly on testnet before mainnet deployment
- Keep deployment private keys secure
- Document all deployed addresses and configurations
- Monitor gas costs and optimization
- Maintain separate environments for testing and production

# MXTK Mainnet Deployment Guide

## Mainnet Deployment Prerequisites

### Environment Setup

1. Configure Arbitrum One network:

   ```javascript
   // hardhat.config.js
   module.exports = {
     networks: {
       arbitrumOne: {
         url: "https://arb1.arbitrum.io/rpc",
         chainId: 42161,
         accounts: [process.env.MAINNET_PRIVATE_KEY]
       }
     }
   }
   ```

### Required Resources

1. MetaMask wallet with Arbitrum One configured:
   - Network Name: Arbitrum One
   - RPC URL: <https://arb1.arbitrum.io/rpc>
   - Chain ID: 42161
   - Currency Symbol: ETH

2. Mainnet ETH:
   - Ensure sufficient ETH for deployment and operations
   - Estimated gas costs: ~2-3 ETH for full deployment and setup

3. Production Environment Variables:

   ```bash
   # .env.production file
   MAINNET_PRIVATE_KEY=your_production_private_key
   ARBITRUM_MAINNET_RPC_URL=your_production_rpc_url
   ETHERSCAN_API_KEY=your_etherscan_api_key
   OWNER_ADDRESS=your_owner_wallet_address
   ```

## Step-by-Step Mainnet Deployment

### 1. Pre-deployment Checklist

- [ ] Contract audited
- [ ] Testnet deployment successful
- [ ] All tests passing
- [ ] Gas optimization completed
- [ ] Emergency procedures documented
- [ ] Multi-sig wallet ready (recommended)

### 2. Contract Preparation

1. Verify Universal Router address:

   ```solidity
   // In MXTK.sol - Confirm this address
   address public constant ARBITRUM_UNIVERSAL_ROUTER = 0xa51afafe0263b40edaef0df8781ea9aa03e381a3;
   ```
   ```

2. Configure Chainlink mainnet price feeds:

   ```solidity
   // Example for Gold price feed on Arbitrum One
   MineralPricesOracle["AU"] = 0x1F954Dc24a49708C26E0C1777f16750B5C6d5a2c;
   ```

### 3. Deployment Script

Create `scripts/deploy-mainnet.js`:

```javascript
const { ethers, upgrades } = require("hardhat");

async function main() {
    console.log("Starting MXTK mainnet deployment...");

    // Deploy implementation with extra gas limit for mainnet
    const MXTK = await ethers.getContractFactory("MXTK");
    
    // Deploy proxy with production settings
    const mxtk = await upgrades.deployProxy(MXTK, 
        [process.env.OWNER_ADDRESS],
        { 
            initializer: 'initialize',
            kind: 'uups',
            gasLimit: 5000000 // Adjust based on requirements
        }
    );

    console.log("Waiting for deployment confirmations...");
    await mxtk.deployed();
    console.log("MXTK deployed to:", mxtk.address);

    // Wait for more confirmations on mainnet
    console.log("Waiting for 10 block confirmations...");
    await mxtk.deployTransaction.wait(10);

    // Configure Universal Router (mainnet)
    console.log("Configuring Universal Router...");
    await mxtk.setZeroFeeAndWhitelistArbitrumRouter(false);
    await mxtk.deployTransaction.wait(5);
    
    // Setup Permit2
    console.log("Setting up Permit2...");
    await mxtk.approvePermit2();
    await mxtk.deployTransaction.wait(5);
    
    // Approve Router
    console.log("Approving Router...");
    await mxtk.approveRouter();
    await mxtk.deployTransaction.wait(5);
    
    // Final verification
    const isConfigured = await mxtk.isRouterProperlyConfigured(false);
    console.log("Router properly configured:", isConfigured);

    // Verify contract on Arbiscan
    console.log("Verifying contract on Arbiscan...");
    await hre.run("verify:verify", {
        address: mxtk.address,
        constructorArguments: [],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### 4. Deployment Steps

1. Deploy to mainnet:

   ```bash
   # Use production environment
   source .env.production
   
   # Deploy contract
   npx hardhat run scripts/deploy-mainnet.js --network arbitrumOne
   ```

2. Verify deployment:

   ```bash
   # Save production address
   export MAINNET_CONTRACT_ADDRESS="deployed_address"
   
   # Verify on Arbiscan
   npx hardhat verify --network arbitrumOne $MAINNET_CONTRACT_ADDRESS
   ```

3. Run production verification:

   ```javascript
   // scripts/verify-mainnet.js
   async function main() {
       const mxtk = await ethers.getContractAt("MXTK", process.env.MAINNET_CONTRACT_ADDRESS);
       
       // Verify router configuration
       const isConfigured = await mxtk.isRouterProperlyConfigured(false);
       console.log("Router configured:", isConfigured);
       
       // Verify Permit2 allowance
       const permit2Allowance = await mxtk.allowance(
           mxtk.address, 
           "0x000000000022D473030F116dDEE9F6B43aC78BA3"
       );
       console.log("Permit2 allowance:", permit2Allowance.toString());
       
       // Verify router allowance
       const routerAllowance = await mxtk.allowance(
           mxtk.address,
           "0xa51afafe0263b40edaef0df8781ea9aa03e381a3"
       );
       console.log("Router allowance:", routerAllowance.toString());
   }
   ```

### 5. Post-Deployment Checklist

1. **Contract Verification**
   - [ ] Contract verified on Arbiscan
   - [ ] Owner address confirmed
   - [ ] Router configuration verified
   - [ ] Permit2 setup confirmed

2. **Security Checks**
   - [ ] Access controls working
   - [ ] Fee mechanisms verified
   - [ ] Emergency functions tested
   - [ ] Multi-sig controls active

3. **Integration Verification**
   - [ ] Universal Router integration working
   - [ ] Permit2 approvals confirmed
   - [ ] Price feeds operational
   - [ ] Events emitting correctly

### 6. Production Monitoring

1. Set up monitoring for:
   - Contract events
   - Transaction volume
   - Gas usage
   - Price feed updates

2. Configure alerts for:
   - Large transfers
   - Owner operations
   - Emergency actions
   - Price deviations

### Important Production Notes

1. **Security**
   - Use multi-sig for owner operations
   - Monitor contract activity 24/7
   - Have emergency response plan ready
   - Keep backup of all deployment data

2. **Operations**
   - Document all configuration changes
   - Maintain upgrade plans
   - Regular security reviews
   - Keep technical documentation updated

3. **Compliance**
   - Record all deployments
   - Document all owner operations
   - Maintain operation logs
   - Keep audit trail

[Rest of README continues...]
