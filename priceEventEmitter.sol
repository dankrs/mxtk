// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact security@mineral-token.com
/**
 * @title PriceEventEmitter
 * @notice A simple contract to emit events with updated mineral price data.
 * @dev This contract is owned and controlled by a single owner, ensuring only authorized actions are performed.
 */
contract PriceEventEmitter is Ownable {

    /**
     * @notice Constructor to initialize the contract with the owner.
     * @param initialOwner The address of the initial owner of the contract.
     * @dev Inherits the `Ownable` constructor, which sets the contract owner upon deployment.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Event to log the emission of a mineral price update.
     * @param symbol The symbol representing the mineral (e.g., "AU" for gold).
     * @param price The updated price of the mineral in Wei.
     */
    event eventEmitted(string symbol, int256 price);

    /**
     * @notice Emits an event containing updated price information for a mineral.
     * @dev 
     * - Only the contract owner is allowed to call this function to ensure the integrity of the price data.
     * - Uses the `require` statement to validate ownership and prevent unauthorized access.
     * @param symbol The symbol representing the mineral (e.g., "AU" for gold).
     * @param price The updated price of the mineral in Wei.
     * @param ownerAddress The address provided to validate the ownership.
     */
    function emitEvent(string memory symbol, int256 price, address ownerAddress) public {
        // Ensure the caller-provided owner address matches the current contract owner.
        require(ownerAddress == owner(), "Only the contract owner can emit the mineral price oracle");

        // Emit the event with the symbol and price data. 
        // This makes the price update available for external systems or subscribers to blockchain events.
        emit eventEmitted(symbol, price);
    }
}

/**
 * Detailed Explanation of Features:
 * 
 * 1. **`@custom:security-contact security@mineral-token.com`:**
 *    - Provides a contact point for reporting vulnerabilities or issues.
 *
 * 2. **Inheritance from `Ownable`:**
 *    - Ensures basic ownership functionality.
 *    - Provides methods like `owner()` and `transferOwnership()` to manage contract ownership.
 *
 * 3. **Constructor:**
 *    - Sets the initial owner of the contract.
 *    - Calls the `Ownable` constructor with `initialOwner` to establish ownership rights.
 *
 * 4. **Event (`eventEmitted`):**
 *    - Used to log updated mineral prices in the form of blockchain events.
 *    - Parameters:
 *      - `symbol`: Represents the mineral being updated.
 *      - `price`: The new price in Wei.
 *    - Useful for applications or systems that listen to blockchain events.
 *
 * 5. **`emitEvent` Function:**
 *    - Only the owner can call this function to ensure data integrity.
 *    - Emits the `eventEmitted` event with the given parameters.
 *    - Facilitates external integrations by logging real-time updates to the blockchain.
 *
 * 6. **Use Cases:**
 *    - To broadcast real-time mineral price updates to external systems.
 *    - Ideal for systems requiring decentralized and tamper-proof price dissemination.
 */
