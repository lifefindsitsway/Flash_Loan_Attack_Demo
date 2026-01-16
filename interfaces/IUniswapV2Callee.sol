// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IUniswapV2Callee Interface
/// @notice Callback interface for Uniswap V2 flash swaps
/// @dev Contracts receiving flash loans must implement this interface
interface IUniswapV2Callee {
    /// @notice Called by the pair contract during a flash swap
    /// @dev The callback must ensure the borrowed tokens (plus fees) are returned
    ///      to the pair contract before the function returns
    /// @param sender The address that initiated the swap (msg.sender of swap())
    /// @param amount0 The amount of token0 being borrowed
    /// @param amount1 The amount of token1 being borrowed
    /// @param data Arbitrary data passed from the swap() call
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}
