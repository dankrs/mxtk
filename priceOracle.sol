// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./mxtk.sol";
import "./priceEventEmitter.sol";

/// @title PriceOracle
/// @notice Manages price data for specific minerals and integrates with Chainlink Aggregator interface.
///         Emits events for price updates and allows querying price information.
/// @custom:security-contact security@mineral-token.com
contract PriceOracle is AggregatorV3Interface, Ownable {

    // Name of the price oracle (e.g., "Gold Price Oracle")
    string public name;

    // Symbol associated with the mineral (e.g., "AU" for gold)
    string public symbol;

    // Reference to the main MXTK contract
    MXTK public main;

    // Stores the current price of the mineral
    int256 internal _price;

    // Version of the oracle contract
    uint256 internal _version = 1;

    // Reference to the PriceEventEmitter contract
    PriceEventEmitter public emitter;

    // Timestamp for when the price was first set
    uint256 internal _startedAt;

    // Timestamp for when the price was last updated
    uint256 internal _updatedAt;

    // Number of decimals used for the price value
    uint8 internal _decimals = 8;

    /**
     * @notice Initializes the PriceOracle contract.
     * @param initialOwner Address of the initial contract owner.
     * @param _name Name of the price oracle.
     * @param _symbol Symbol of the mineral associated with this oracle.
     * @param _mxtk Address of the MXTK contract.
     * @param _priceEventEmitter Address of the PriceEventEmitter contract.
     * @param initialPrice Initial price of the mineral.
     * @dev Links the PriceOracle to the MXTK and PriceEventEmitter contracts,
     *      and sets the initial price and timestamps.
     */
    constructor(
        address initialOwner,
        string memory _name,
        string memory _symbol,
        address _mxtk,
        address _priceEventEmitter,
        int256 initialPrice
    ) Ownable(initialOwner) {
        name = _name;
        symbol = _symbol;

        // Initialize reference to the MXTK contract
        main = MXTK(_mxtk);

        // Register this PriceOracle in the MXTK contract
        main.updateMineralPriceOracle(_symbol, address(this), initialOwner);

        // Set the initial price
        _price = initialPrice;

        // Initialize the event emitter
        emitter = PriceEventEmitter(_priceEventEmitter);

        // Set the initial timestamps
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
    }

    /**
     * @notice Returns the number of decimals used for the price.
     * @return Number of decimals.
     */
    function decimals()
        external
        view
        returns (uint8)
    {
        return _decimals;
    }

    /**
     * @notice Returns a description of the oracle.
     * @return The name of the oracle.
     */
    function description()
        external
        view
        returns (string memory)
    {
        return name;
    }

    /**
     * @notice Returns the version of the oracle contract.
     * @return The contract version.
     */
    function version()
        external
        view
        returns (uint256)
    {
        return _version;
    }

    /**
     * @notice Returns price data for a given round ID (not historical in this implementation).
     * @param _roundId The round ID for which price data is queried.
     * @return roundId The same round ID as input.
     * @return answer The price of the mineral.
     * @return startedAt The timestamp when the round started (set to 0 in this implementation).
     * @return updatedAt The timestamp of the latest price update.
     * @return answeredInRound The same round ID as input.
     */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = _roundId;
        answer = _price;
        startedAt = 0; // Placeholder, historical data not implemented
        updatedAt = block.timestamp;
        answeredInRound = _roundId;
    }

    /**
     * @notice Updates the price of the mineral and emits an event.
     * @param newPrice The new price of the mineral.
     * @dev Only callable by the owner. Updates the linked MXTK contract and timestamps.
     */
    function changePrice(int newPrice) public onlyOwner {
        // Update the stored price
        _price = newPrice;

        // Notify the MXTK contract to recompute token price
        main.updateAndComputeTokenPrice();

        // Update the last updated timestamp
        _updatedAt = block.timestamp;

        // Emit a price update event
        emitter.emitEvent(symbol, newPrice, owner());
    }

    /**
     * @notice Returns the latest round data.
     * @return roundId Always returns 0 as this oracle does not track historical rounds.
     * @return answer The current price of the mineral.
     * @return startedAt The timestamp when the oracle was initialized.
     * @return updatedAt The timestamp of the latest price update.
     * @return answeredInRound Always returns 0 as this oracle does not track historical rounds.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = 0; // Historical data not supported
        answer = _price;
        startedAt = _startedAt;
        updatedAt = _updatedAt;
        answeredInRound = 0; // Historical data not supported
    }

    // --- Explanation of Features ---
    // 1. Constructor: Initializes the oracle, links it to the MXTK and PriceEventEmitter contracts, and sets the initial price.
    // 2. Event Emission: Uses `PriceEventEmitter` to log updates, enabling external systems to monitor price changes.
    // 3. Query Functions: Provides standard interfaces (`getRoundData`, `latestRoundData`) to retrieve price and timestamp data.
    // 4. Ownership Checks: Ensures only the owner can perform sensitive actions like updating the price.
    // 5. Chainlink Compatibility: Implements `AggregatorV3Interface` for Chainlink-style integrations.
}
