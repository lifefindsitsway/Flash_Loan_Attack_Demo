// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";

/// @title Mock ERC20 Token
/// @notice Simplified ERC20 implementation for creating WETH and DAI test tokens
/// @dev WARNING: This contract uses 0 decimals instead of the standard 18 decimals
///      for easier demonstration. In production, tokens typically use 18 decimals.
///      DO NOT use this implementation in production environments.
contract ERC20 is IERC20 {
    /// @notice Token balance mapping
    mapping(address => uint256) public override balanceOf;

    /// @notice Allowance mapping: owner => spender => amount
    mapping(address => mapping(address => uint256)) public override allowance;

    /// @notice Total token supply
    uint256 public override totalSupply;

    /// @notice Token name (e.g., "Wrapped Ether")
    string public name;

    /// @notice Token symbol (e.g., "WETH")
    string public symbol;

    /// @notice Token decimals
    /// @dev Set to 0 for demonstration simplicity. Standard ERC20 tokens use 18 decimals.
    ///      This makes the numbers in the demo easier to read and understand.
    uint8 public decimals = 0;

    /// @notice Creates a new ERC20 token
    /// @param name_ The token name
    /// @param symbol_ The token symbol
    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    /// @notice Transfers tokens to a recipient
    /// @param recipient The address to receive tokens
    /// @param amount The amount to transfer
    /// @return True if successful
    function transfer(address recipient, uint amount) public override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    /// @notice Approves a spender to use tokens on behalf of the caller
    /// @param spender The address to approve
    /// @param amount The allowance amount
    /// @return True if successful
    function approve(address spender, uint amount) public override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers tokens from one address to another using allowance
    /// @param sender The source address
    /// @param recipient The destination address
    /// @param amount The amount to transfer
    /// @return True if successful
    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) public override returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    /// @notice Mints new tokens to the caller
    /// @dev For testing purposes only - no access control
    /// @param amount The amount to mint
    /// @return True if successful
    function mint(uint amount) external returns (bool) {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
        return true;
    }

    /// @notice Burns tokens from the caller
    /// @dev For testing purposes only
    /// @param amount The amount to burn
    /// @return True if successful
    function burn(uint amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
        return true;
    }
}
