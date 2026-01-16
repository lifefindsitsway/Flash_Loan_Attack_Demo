// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IERC20 Interface
/// @notice Standard ERC20 interface with additional mint/burn functions for testing
/// @dev Extended interface for demonstration purposes
interface IERC20 {
    /// @notice Emitted when tokens are transferred
    /// @param from The sender address (address(0) for minting)
    /// @param to The recipient address (address(0) for burning)
    /// @param value The amount of tokens transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when an allowance is set
    /// @param owner The token owner granting the allowance
    /// @param spender The address allowed to spend the tokens
    /// @param value The allowance amount
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Returns the total token supply
    /// @return The total number of tokens in existence
    function totalSupply() external view returns (uint256);

    /// @notice Returns the token balance of an account
    /// @param account The address to query
    /// @return The token balance
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers tokens to a recipient
    /// @param to The recipient address
    /// @param amount The amount to transfer
    /// @return True if the transfer succeeded
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Returns the remaining allowance for a spender
    /// @param owner The token owner
    /// @param spender The spender address
    /// @return The remaining allowance
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Approves a spender to use tokens
    /// @param spender The address to approve
    /// @param amount The allowance amount
    /// @return True if the approval succeeded
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers tokens from one address to another using allowance
    /// @param from The source address
    /// @param to The destination address
    /// @param amount The amount to transfer
    /// @return True if the transfer succeeded
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /// @notice Mints new tokens to the caller (for testing only)
    /// @param amount The amount to mint
    /// @return True if minting succeeded
    function mint(uint amount) external returns (bool);

    /// @notice Burns tokens from the caller (for testing only)
    /// @param amount The amount to burn
    /// @return True if burning succeeded
    function burn(uint amount) external returns (bool);
}
