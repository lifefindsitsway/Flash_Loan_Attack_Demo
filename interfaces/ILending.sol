// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ILending Interface
/// @notice Interface for the vulnerable lending protocol
/// @dev This protocol uses DEX spot price as an oracle (intentionally vulnerable for demonstration)
interface ILending {
    /// @notice Deposits WETH as collateral
    /// @param amount The amount of WETH to deposit
    function deposit(uint256 amount) external;

    /// @notice Borrows DAI against deposited collateral
    /// @param amount The amount of DAI to borrow
    function borrow(uint256 amount) external;

    /// @notice Calculates the maximum borrowable amount for a user
    /// @param user The address to check
    /// @return The maximum amount of DAI that can be borrowed
    function maxBorrow(address user) external view returns (uint256);

    /// @notice Returns the current WETH price from the oracle
    /// @dev WARNING: Reads spot price directly from DEX - vulnerable to manipulation
    /// @return The price in DAI per WETH (no decimal scaling)
    function getPrice() external view returns (uint256);

    /// @notice Returns the collateral balance of a user
    /// @param user The address to check
    /// @return The amount of WETH deposited as collateral
    function collateral(address user) external view returns (uint256);
}
