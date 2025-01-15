// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title MXTK
 * @notice This contract implements the ERC20 token standard with additional features such as burnable,
 * pausable, and upgradable capabilities. It also integrates functionality for managing assets (minerals)
 * backed by real-world values using oracles.
 * @custom:security-contact security@mineral-token.com
 */
contract MXTK is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PausableUpgradeable, 
OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable, ReentrancyGuard {

    // Gas fee percentage in basis points (bps). Default: 10 bps (0.1%).
    uint256 public gasFeePercentageBps;

    // Mappings to store mineral prices and their corresponding Chainlink oracle addresses.
    mapping(string => uint256) public MineralPrices;
    mapping(string => address) public MineralPricesOracle;

    // Nested mapping to store asset holdings by owner, IPFS CID, and mineral symbol.
    mapping(address => mapping(string => mapping(string => uint256))) public newHoldings;

    // Addresses excluded from paying gas fees.
    mapping(address => bool) public excludedFromFees;

    // Struct to represent an individual asset holding.
    struct Holdings {
        address owner;          // Address of the holding owner.
        string assetIpfsCID;    // IPFS CID for asset metadata.
        string mineralSymbol;   // Mineral symbol (e.g., "AU" for gold).
        uint256 ounces;         // Quantity of the mineral in ounces.
    }

    // Array to store all holdings and an index for tracking.
    Holdings[] public newHoldingArray;
    uint256 internal newHoldingIndex;

    // Array to keep track of valid mineral symbols.
    string[] public mineralSymbols;

    // Total value of all assets (in Wei).
    uint256 public totalAssetValue;

    /**
     * @notice Prevents the initializer from being called again after deployment.
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the MXTK contract with the given owner address.
     * @param initialOwner Address of the initial contract owner.
     */
    function initialize(address initialOwner) initializer public {
        __ERC20_init("Mineral Token", "MXTK");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("Mineral Token");
        __UUPSUpgradeable_init();

        gasFeePercentageBps = 10; // Default gas fee percentage: 0.1%.
    }

    /**
     * @notice Pauses all token transfers.
     * Only callable by the contract owner.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers.
     * Only callable by the contract owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @notice Excludes an account from gas fees.
     * @param account Address to exclude from fees.
     */
    function excludeFromFees(address account) external onlyOwner {
        excludedFromFees[account] = true;
    }

    /**
     * @notice Includes an account back into the fee-paying group.
     * @param account Address to include in fees.
     */
    function includeInFees(address account) external onlyOwner {
        excludedFromFees[account] = false;
    }

    /**
     * @dev Internal function required for UUPSUpgradeable.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    /**
     * @dev Overrides the `_update` function to include frozen account checks.
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        require(!frozenAccounts[from], "Sender account is frozen");
        require(!frozenAccounts[to], "Recipient account is frozen");
        super._update(from, to, value);
    }

    /**
     * @notice Updates the Chainlink oracle address for a specific mineral symbol.
     * @param mineralSymbol Symbol of the mineral.
     * @param priceOracleAddress Address of the Chainlink oracle.
     * @param ownerAddress Address of the contract owner (for verification).
     */
    function updateMineralPriceOracle(string memory mineralSymbol, address priceOracleAddress, address ownerAddress) public {
        require(ownerAddress == owner(), "Only the contract owner can update the mineral price oracle");
        MineralPricesOracle[mineralSymbol] = priceOracleAddress;
    }

    /**
     * @notice Internal function to convert existing asset data into a Holding.
     * @param holdingOwner Address of the asset owner.
     * @param assetIpfsCID IPFS CID of the asset.
     * @param mineralSymbol Mineral symbol.
     * @param mineralOunces Quantity of the mineral (in ounces).
     */
    function existingDataToHolding(
        address holdingOwner,
        string memory assetIpfsCID,
        string memory mineralSymbol,
        uint256 mineralOunces
    ) internal onlyOwner {
        require(holdingOwner != address(0), "Holding not found");
        require(bytes(assetIpfsCID).length > 0 && bytes(assetIpfsCID).length <= 64, "Invalid IPFS CID");
        require(mineralOunces > 0 && mineralOunces <= 1e18, "Invalid mineral ounces");
        require(bytes(mineralSymbol).length > 0 && bytes(mineralSymbol).length < 6, "Symbol cannot be empty or > 6");

        // Ensure the mineral does not already exist for this holding.
        require(
            newHoldings[holdingOwner][assetIpfsCID][mineralSymbol] == 0,
            "Mineral already exists"
        );

        // Store the mineral data in the mappings and array.
        newHoldings[holdingOwner][assetIpfsCID][mineralSymbol] = mineralOunces;

        Holdings memory tx1 = Holdings(holdingOwner, assetIpfsCID, mineralSymbol, mineralOunces);
        newHoldingArray.push(tx1);
        newHoldingIndex++;

        // Update the total asset value and token price.
        uint256 mineralValueInWei = calculateMineralValueInWei(mineralSymbol, mineralOunces);
        totalAssetValue += mineralValueInWei;
        updateAndComputeTokenPrice();

        emit ExistingDataToHolding(holdingOwner, assetIpfsCID, mineralSymbol, mineralOunces);
    }

    /**
     * @notice Adds a new mineral to a holding.
     * @param holdingOwner Address of the asset owner.
     * @param assetIpfsCID IPFS CID of the asset.
     * @param mineralSymbol Mineral symbol.
     * @param mineralOunces Quantity of the mineral (in ounces).
     */
    function addMineralToHolding(
        address holdingOwner,
        string memory assetIpfsCID,
        string memory mineralSymbol,
        uint256 mineralOunces
    ) external onlyOwner {
        require(holdingOwner != address(0), "Error 1: Invalid holding owner address");
        require(bytes(assetIpfsCID).length > 0 && bytes(assetIpfsCID).length <= 64, "Error 2: Invalid IPFS CID length");
        require(mineralOunces > 0 && mineralOunces <= 1e18, "Error 3: Invalid mineral ounces");
        require(bytes(mineralSymbol).length > 0 && bytes(mineralSymbol).length < 6, "Error 4: Invalid mineral symbol length");

        // Check if the mineral already exists for this Holding.
        require(
            newHoldings[holdingOwner][assetIpfsCID][mineralSymbol] == 0,
            "Error 5: Mineral already exists in this holding"
        );

        newHoldings[holdingOwner][assetIpfsCID][mineralSymbol] = mineralOunces;

        Holdings memory tx1 = Holdings(holdingOwner, assetIpfsCID, mineralSymbol, mineralOunces);
        newHoldingArray.push(tx1);
        unchecked {
            ++newHoldingIndex;
        }

                // Calculation logic for the new holding.
        uint256 mineralValueInWei = calculateMineralValueInWei(mineralSymbol, mineralOunces);
        require(mineralValueInWei > 0, "Error 6: Invalid mineral value");

        // Calculate the number of tokens to mint based on the mineral's value.
        uint256 tokensToMintInWei = computeTokenByWei(mineralValueInWei);
        require(tokensToMintInWei > 0, "Error 7: Invalid tokens to mint");

        // Calculate the administrative fee in tokens.
        uint256 adminFeeInWei = calculateAdminFee(tokensToMintInWei);
        require(adminFeeInWei <= tokensToMintInWei, "Error 8: Admin fee exceeds tokens to mint");

        // Calculate the net tokens to transfer to the holding owner after deducting fees.
        uint256 amountToTransferToHoldingOwner = tokensToMintInWei - adminFeeInWei;
        require(amountToTransferToHoldingOwner > 0, "Error 9: Invalid amount to transfer to holding owner");

        // Update the total asset value of the contract.
        totalAssetValue += mineralValueInWei;

        // Mint the calculated number of tokens to the holding owner's address.
        _mint(holdingOwner, amountToTransferToHoldingOwner);

        // Mint the admin fee tokens to the contract owner's address.
        _mint(owner(), adminFeeInWei);

        // If the mineral symbol is new, add it to the list of valid minerals.
        if (!validMinerals[mineralSymbol]) {
            _addMineralSymbol(mineralSymbol);
        }

        // Update the token price and other metrics.
        updateAndComputeTokenPrice();

        // Emit an event to log the addition of the mineral.
        emit MineralAdded(
            holdingOwner,
            mineralSymbol,
            mineralOunces,
            mineralValueInWei,
            tokensToMintInWei,
            adminFeeInWei,
            amountToTransferToHoldingOwner
        );
    }

    /**
     * @notice Updates prices of underlying assets and recalculates the token price.
     */
    function updateAndComputeTokenPrice() public {
        // Update the total asset value by recalculating the value of all holdings.
        totalAssetValue = calculateTotalAssetValue();

        // Calculate the updated token price.
        uint256 newTokenPrice = getTokenValue();

        // Emit an event to log the updated token price.
        emit TokenPriceUpdated(newTokenPrice);
    }

    /**
     * @notice Calculates the total value of all assets in the contract.
     * @return totalValue The total value of all assets in Wei.
     */
    function calculateTotalAssetValue() internal view returns (uint256) {
        uint256 totalValue;

        // Iterate through all holdings and sum up their values.
        for (uint256 i; i < newHoldingArray.length;) {
            totalValue += calculateMineralValueInWei(newHoldingArray[i].mineralSymbol, newHoldingArray[i].ounces);
            unchecked {
                ++i;
            }
        }

        return totalValue;
    }

    /**
     * @notice Adds a new mineral symbol to the list of valid minerals.
     * @param mineralSymbol The symbol of the mineral to add (e.g., "AU").
     */
    function _addMineralSymbol(string memory mineralSymbol) internal {
        require(!validMinerals[mineralSymbol], "Mineral symbol already exists");
        mineralSymbols.push(mineralSymbol);
        validMinerals[mineralSymbol] = true;

        // Emit an event to log the addition of a new mineral symbol.
        emit MineralSymbolAdded(mineralSymbol);
    }

    /**
     * @notice Public function to add a new mineral symbol. Only callable by the owner.
     * @param mineralSymbol The symbol of the mineral to add (e.g., "AU").
     */
    function addMineralSymbol(string memory mineralSymbol) external onlyOwner {
        _addMineralSymbol(mineralSymbol);
    }

    /**
     * @notice Calculates the number of tokens based on the value of a holding in Wei.
     * @param weiAmount The value of the holding in Wei.
     * @return The equivalent number of tokens.
     */
    function computeTokenByWei(uint256 weiAmount) public view returns (uint256) {
        require(weiAmount > 0, "Value must > zero");

        uint256 price = getTokenValue();

        // If the price is zero during initialization, use the base value.
        if (price == 0) price = baseValue();

        // Calculate the equivalent number of tokens.
        uint256 tokens = divide(weiAmount, price);

        return tokens;
    }

    /**
     * @notice Performs division with precision to avoid loss due to rounding.
     * @param a Numerator.
     * @param b Denominator.
     * @return Result of the division operation.
     */
    function divide(uint256 a, uint256 b) public pure returns (uint256) {
        require(b != 0, "Division by zero is not allowed.");
        return (a * 1e18) / b; // Multiply by 1e18 to preserve precision.
    }

    /**
     * @notice Calculates the administrative fee based on tokens to mint.
     * @param tokensToMintInWei The total tokens to mint in Wei.
     * @return The administrative fee in tokens.
     */
    function calculateAdminFee(uint256 tokensToMintInWei) public pure returns (uint256) {
        require(tokensToMintInWei > 0, "Fee must > zero");

        // Calculate the admin fee as 40% of the tokens to mint.
        return (tokensToMintInWei * 40) / 100;
    }

    /**
     * @notice Calculates the value of a mineral based on its symbol and quantity.
     * @param mineralSymbol The symbol of the mineral.
     * @param mineralOunces The quantity of the mineral in ounces.
     * @return The total value of the mineral in Wei.
     */
    function calculateMineralValueInWei(string memory mineralSymbol, uint256 mineralOunces) public view returns (uint256) {
        uint256 mineralPrice = getMineralPrice(mineralSymbol);
        return divide(mineralPrice * mineralOunces, 10**8); // Adjust precision based on oracle output.
    }

    /**
     * @notice Fetches the current price of a mineral from its Chainlink oracle.
     * @param mineralSymbol The symbol of the mineral.
     * @return The current price of the mineral in Wei.
     */
    function getMineralPrice(string memory mineralSymbol) public view returns (uint256) {
        int256 price;
        AggregatorV3Interface tx1 = AggregatorV3Interface(MineralPricesOracle[mineralSymbol]);

        // Fetch the latest price data from the oracle.
        (, price, , , ) = tx1.latestRoundData();

        return uint256(price); // Convert price from int256 to uint256.
    }

    /**
     * @notice Mints tokens for reimbursement purposes. Only callable by the owner.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mintReimbursement(address to, uint256 amount) external onlyOwner {
        require(!frozenAccounts[to], "Cannot mint to a frozen account");

        // Mint tokens to the specified address.
        _mint(to, amount);

        // Emit an event to log the minting action.
        emit ReimbursementMinted(to, amount);
    }

        // Function to check if a mineral symbol is valid
    function isMineralValid(string memory mineralSymbol) public view returns (bool) {
        // Returns true if the mineral symbol exists in the validMinerals mapping.
        bool isValid = validMinerals[mineralSymbol];
        return isValid;
    }

    /**
     * @notice Overrides the ERC20 `transfer` function to include fee handling and frozen account checks.
     * @param to The address of the recipient.
     * @param amount The amount of tokens to transfer.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(!frozenAccounts[msg.sender], "Sender account is frozen");
        require(!frozenAccounts[to], "Recipient account is frozen");

        require(to != address(0), "Invalid address");
        require(amount > 0, "Amount must > zero");

        // Get balance before transfer
        uint256 balanceBefore = balanceOf(msg.sender);

        uint256 gasFee = 0;
        if (!excludedFromFees[msg.sender]) {
            // Calculate the gas fee as a percentage of the transfer amount.
            gasFee = (amount * gasFeePercentageBps) / 10_000;
        }

        // Ensure the sender's balance is sufficient.
        require(balanceBefore >= amount, "Insufficient balance");

        // Ensure the gas fee does not exceed the transfer amount.
        require(gasFee < amount, "Gas fee exceeds amount");

        // Transfer tokens minus the gas fee.
        require(super.transfer(to, amount - gasFee), "Transfer failed");

        if (gasFee > 0) {
            // Transfer the gas fee to the contract owner.
            require(super.transfer(owner(), gasFee), "Gas fee transfer failed");
        }

        return true;
    }

    /**
     * @notice Allows the contract owner to buy back a holding.
     * @param holdingOwner The owner of the holding.
     * @param ipfsCID The IPFS CID identifying the holding.
     */
    function buyBackHolding(address holdingOwner, string memory ipfsCID) external onlyOwner nonReentrant {
        // Calculate the current value of the minerals in the holding.
        uint256 holdingValueInWei = calculateHoldingValueInWei(holdingOwner, ipfsCID);

        require(holdingValueInWei > 0, "Holding has no value");

        // Calculate the number of tokens to burn for the buyback.
        uint256 tokensToBurn = computeTokenByWei(holdingValueInWei);

        // Ensure the holding owner has enough tokens for the buyback.
        require(balanceOf(holdingOwner) >= tokensToBurn, "Insufficient tokens for buyback");

        // Burn the tokens.
        _burn(holdingOwner, tokensToBurn);

        // Remove the holding from the owner.
        removeHoldingFromOwner(holdingOwner, ipfsCID);

        // Emit an event to log the buyback.
        emit HoldingBuyback(holdingOwner, tokensToBurn, holdingValueInWei);
    }

    /**
     * @notice Removes a holding from an owner based on its IPFS CID.
     * @param holdingOwner The owner of the holding.
     * @param ipfsCid The IPFS CID of the holding.
     */
    function removeHoldingFromOwner(address holdingOwner, string memory ipfsCid) internal {
        for (uint256 i; i < newHoldingArray.length;) {
            if (newHoldingArray[i].owner == holdingOwner &&
                keccak256(bytes(newHoldingArray[i].assetIpfsCID)) == keccak256(bytes(ipfsCid))
            ) {
                // Remove the holding by replacing it with the last element and reducing the array length.
                newHoldingArray[i] = newHoldingArray[newHoldingArray.length - 1];
                delete newHoldingArray[newHoldingArray.length - 1];
                newHoldingArray.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Calculates the total value of a holding in Wei based on its minerals.
     * @param holdingOwner The owner of the holding.
     * @param ipfsCid The IPFS CID of the holding.
     * @return The total value of the holding in Wei.
     */
    function calculateHoldingValueInWei(address holdingOwner, string memory ipfsCid) public view returns (uint256) {
        uint256 totalHoldingValue;

        // Calculate the value of each mineral in the holding.
        for (uint256 i; i < newHoldingArray.length;) {
            if (newHoldingArray[i].owner == holdingOwner &&
                keccak256(bytes(newHoldingArray[i].assetIpfsCID)) == keccak256(bytes(ipfsCid))
            ) {
                totalHoldingValue += calculateMineralValueInWei(
                    newHoldingArray[i].mineralSymbol,
                    newHoldingArray[i].ounces
                );
            }
            unchecked {
                ++i;
            }
        }

        return totalHoldingValue;
    }

    /**
     * @notice Updates the gas fee percentage. Only callable by the owner.
     * @param _gasFeePercentageBps The new gas fee percentage in basis points.
     */
    function setGasFeePercentageBps(uint256 _gasFeePercentageBps) external onlyOwner {
        require(_gasFeePercentageBps <= 1000, "Gas fee percentage must be less than or equal to 1000 bps (10%)");

        gasFeePercentageBps = _gasFeePercentageBps;
        emit GasFeePercentageBpsUpdated(_gasFeePercentageBps);
    }

    /**
     * @notice Overrides the `transferFrom` function to include frozen account checks.
     * @param from The address sending the tokens.
     * @param to The address receiving the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(!frozenAccounts[from], "Sender account is frozen");
        require(!frozenAccounts[to], "Recipient account is frozen");
        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice Internal function to freeze or unfreeze an account.
     * @param account The address of the account to modify.
     * @param frozen True to freeze the account, false to unfreeze.
     */
    function _setAccountFrozen(address account, bool frozen) internal onlyOwner {
        frozenAccounts[account] = frozen;
        emit AccountFrozen(account, frozen);
    }

    /**
     * @notice External function to freeze or unfreeze an account. Only callable by the owner.
     * @param account The address of the account to modify.
     * @param frozen True to freeze the account, false to unfreeze.
     */
    function setAccountFrozen(address account, bool frozen) external onlyOwner {
        _setAccountFrozen(account, frozen);
    }

    /**
     * @notice Checks whether an account is frozen.
     * @param account The address of the account to check.
     * @return True if the account is frozen, false otherwise.
     */
    function isAccountFrozen(address account) public view returns (bool) {
        return frozenAccounts[account];
    }

    /**
     * @notice Burns tokens from an account without allowing the account to buy them back.
     * @param account The address of the account to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function forceBurn(address account, uint256 amount) external onlyOwner {
        require(balanceOf(account) >= amount, "Insufficient balance to burn");
        _burn(account, amount);
        emit ForcedBurn(account, amount);
    }

    /**
     * @notice Calculates the current token value based on the total asset value and supply.
     * @return The current token value.
     */
    function getTokenValue() public view returns (uint256) {
        if (totalSupply() == 0) {
            return 0; // Avoid division by zero if totalSupply is zero.
        }
        return (totalAssetValue * 1e18) / totalSupply();
    }

    // Events are logged for various contract actions.
    event ExistingDataToHolding(address holdingOwner, string assetIpfsCID, string mineralSymbol, uint256 mineralOunces);
    event MineralSymbolAdded(string mineralSymbol);
    event MineralSymbolNotAdded(string mineralSymbol);
    event TokenPriceUpdated(uint256);
    event GasFeePercentageBpsUpdated(uint256 newGasFeePercentageBps);
    event HoldingBuyback(address indexed sender, uint256 tokensToBurn, uint256 holdingValueInWei);
    event MineralAdded(address indexed holdingOwner, string mineralSymbol, uint256 mineralOunces, uint256 mineralValue, uint256 tokensMinted, uint256 adminFee, uint256 amountTransferredToHoldingOwner);
    event AccountFrozen(address indexed account, bool frozen);
    event ForcedBurn(address indexed account, uint256 amount);
    event ReimbursementMinted(address indexed to, uint256 amount);
    event MineralAdded(string mineralSymbol);
    event InitializationComplete();
    event MineralValidationChecked(string mineralSymbol, bool isValid);

    /**
     * @notice Provides a base value for calculations during initialization.
     * @return A constant base value used for calculations.
     */
    function baseValue() public pure returns (uint256) {
        return 159089461098 * (10**18);
    }

        /**
     * @notice Initializes a predefined set of minerals and their default values.
     * This function can only be executed once by the contract owner.
     * It sets up the mineral symbols, their oracle addresses, and default prices.
     */
    function initNewVars() public onlyOwner {
        // Ensure the initialization is performed only once.
        require(!isInitialized, "already added new minerals");

        // Predefined list of elements including periodic table elements, crude oil byproducts,
        // rare earth elements, and other commercially important materials.
        string[174] memory elements = [
            // Periodic Table Elements (1-118)
            "H", "HE", "LI", "BE", "B", "C", "N", "O", "F", "NE",
            "NA", "MG", "AL", "SI", "P", "S", "CL", "AR", "K", "CA",
            "SC", "TI", "V", "CR", "MN", "FE", "CO", "NI", "CU", "ZN",
            "GA", "GE", "AS", "SE", "BR", "KR", "RB", "SR", "Y", "ZR",
            "NB", "MO", "TC", "RU", "RH", "PD", "AG", "CD", "IN", "SN",
            "SB", "TE", "I", "XE", "CS", "BA", "LA", "CE", "PR", "ND",
            "PM", "SM", "EU", "GD", "TB", "DY", "HO", "ER", "TM", "YB",
            "LU", "HF", "TA", "W", "RE", "OS", "IR", "PT", "AU", "HG",
            "TL", "PB", "BI", "PO", "AT", "RN", "FR", "RA", "AC", "TH",
            "PA", "U", "NP", "PU", "AM", "CM", "BK", "CF", "ES", "FM",
            "MD", "NO", "LR", "RF", "DB", "SG", "BH", "HS", "MT", "DS",
            "RG", "CN", "NH", "FL", "MC", "LV", "TS", "OG",

            // Crude Oil and Byproducts
            "CRUD", "NGAS", "GSLN", "KERO", "DIES", "FOIL", "NAPH", "PROP", "BUTA", "LUBE", "ASPL",

            // Rare Earth Elements (some overlap with periodic table, but included for emphasis)
            "SC", "Y", "LA", "CE", "PR", "ND", "PM", "SM", "EU", "GD", "TB", "DY", "HO", "ER", "TM", "YB", "LU",

            // Other commercially important minerals and materials
            "GR", "DMND", "RLBY", "SPPHR", "EMRLD", "TPAZ", "OPAL", "QRTZ", "MICA", "FLSP", "CLCT", "DLMT", "GYPS",
            "TLCM", "ZRCN", "APAT", "FLUOR", "BRYL", "PYRX", "AMPH", "OLIV", "GRNT",

            // Additional commodities
            "RVSND", "COAL", "IRON", "BAUXITE", "PHOSPHATE", "LIMST"
        ];

        // Default values for price and oracle address.
        uint256 defaultPrice = 0;
        address defaultOracle = address(0);

        // Iterate through the predefined elements to initialize their properties.
        for (uint i = 0; i < elements.length; i++) {
            string memory element = elements[i];
            
            // Add the element to the list of valid mineral symbols. Adds the mineral symbol to the mineralSymbols array for tracking.
            mineralSymbols.push(element);
            
            // Set default oracle address and price for the mineral. Assigns a default oracle address (0x0) to each mineral.
            MineralPricesOracle[element] = defaultOracle;
            MineralPrices[element] = defaultPrice;
            
            // Marks the mineral as valid for future operations.
            validMinerals[element] = true;

            // Emit an event for the addition of the mineral.
            emit MineralAdded(element);
        }

        // Set specific initial prices for commonly used minerals.
        MineralPrices["CU"] = 10000;              // Copper price in Wei.
        MineralPrices["AU"] = 215544000000;      // Gold price in Wei.
        MineralPrices["GR"] = 10000000;          // Graphite price in Wei.

        // Mark the initialization process as complete. Prevents the function from being called again.
        isInitialized = true;

        // Emit an event indicating the initialization is complete.
        emit InitializationComplete();
    }

    // Boolean flag to ensure that certain functions or actions are executed only once.
    bool internal calledOnce;

    // Mapping to track whether accounts are frozen.
    mapping(address => bool) public frozenAccounts;

    // Mapping to validate mineral symbols.
    mapping(string => bool) public validMinerals;

    // Boolean flag to track whether the initialization process has been completed.
    bool public isInitialized;