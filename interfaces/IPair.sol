// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IPair Interface
/// @notice Interface for Uniswap V2-style trading pair contracts
/// @dev Supports both regular swaps and flash swaps (flash loans)
interface IPair {
    /// @notice Returns the address of token0
    /// @return The token0 contract address
    function token0() external view returns (address);

    /// @notice Returns the address of token1
    /// @return The token1 contract address
    function token1() external view returns (address);

    /// @notice Returns the reserve of token0
    /// @return The current reserve amount of token0
    function reserve0() external view returns (uint112);

    /// @notice Returns the reserve of token1
    /// @return The current reserve amount of token1
    function reserve1() external view returns (uint112);

    /// @notice Returns the current spot price (token1/token0)
    /// @dev Price = reserve1 / reserve0 (no decimal scaling)
    /// @return The price in token1 per token0
    function getPrice() external view returns (uint256);

    /// @notice Adds liquidity to the pool
    /// @dev Simplified version - only for pool initialization
    /// @param amount0 The amount of token0 to add
    /// @param amount1 The amount of token1 to add
    function addLiquidity(uint256 amount0, uint256 amount1) external;

    /// @notice Executes a swap with optional flash loan callback
    /// @dev If data is non-empty, triggers uniswapV2Call on the recipient
    /// @param amount0Out The amount of token0 to receive
    /// @param amount1Out The amount of token1 to receive
    /// @param to The recipient address (also receives callback if data is non-empty)
    /// @param data Arbitrary data passed to the callback (empty = no callback)
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice Executes a simple swap without callback (for price manipulation)
    /// @param amountIn The input token amount
    /// @param oneForZero True: swap token1 for token0, False: swap token0 for token1
    /// @return The output token amount
    function swapExact(uint256 amountIn, bool oneForZero) external returns (uint256);
}
