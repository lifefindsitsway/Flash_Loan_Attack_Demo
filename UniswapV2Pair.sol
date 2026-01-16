// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/IUniswapV2Callee.sol";

/// @title Uniswap V2-style Trading Pair
/// @notice Simplified AMM implementation supporting flash swaps and regular swaps
/// @dev This is a minimal implementation for educational purposes.
///      The actual Uniswap V2 has additional features like reentrancy guards and LP tokens.
///      This demo uses two separate pools to avoid reentrancy issues during callbacks.
contract UniswapV2Pair is IPair {
    /// @notice Address of the first token in the pair
    address public token0;

    /// @notice Address of the second token in the pair
    address public token1;

    /// @notice Reserve amount of token0
    uint112 public reserve0;

    /// @notice Reserve amount of token1
    uint112 public reserve1;

    /// @notice Emitted when liquidity is added to the pool
    /// @param provider The address providing liquidity
    /// @param amount0 The amount of token0 added
    /// @param amount1 The amount of token1 added
    event AddLiquidity(address indexed provider, uint256 amount0, uint256 amount1);

    /// @notice Emitted when a swap occurs
    /// @param sender The address initiating the swap
    /// @param amount0In The amount of token0 sent to the pool
    /// @param amount1In The amount of token1 sent to the pool
    /// @param amount0Out The amount of token0 sent from the pool
    /// @param amount1Out The amount of token1 sent from the pool
    /// @param to The recipient of the output tokens
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    /// @notice Emitted when reserves are updated
    /// @param reserve0 The new reserve of token0
    /// @param reserve1 The new reserve of token1
    event Sync(uint112 reserve0, uint112 reserve1);

    /// @notice Creates a new trading pair
    /// @param _token0 Address of the first token (e.g., WETH)
    /// @param _token1 Address of the second token (e.g., DAI)
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    /// @notice Adds liquidity to the pool
    /// @dev Simplified version for pool initialization only.
    ///      Does not mint LP tokens or handle proportional deposits.
    /// @param amount0 The amount of token0 to add
    /// @param amount1 The amount of token1 to add
    function addLiquidity(uint256 amount0, uint256 amount1) external {
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        _sync();
        emit AddLiquidity(msg.sender, amount0, amount1);
    }

    /// @notice Executes a flash swap (flash loan)
    /// @dev Flow: 1) Optimistically transfer tokens out
    ///           2) Call recipient's callback (if data is non-empty)
    ///           3) Verify K invariant is maintained (accounting for 0.3% fee)
    ///
    ///      NOTE: The real Uniswap V2 has a reentrancy lock preventing
    ///      callbacks from calling swap() on the same pool.
    ///      This demo uses two separate pools to avoid this issue.
    ///
    /// @param amount0Out Amount of token0 to borrow/receive
    /// @param amount1Out Amount of token1 to borrow/receive
    /// @param to Recipient address (receives callback if data is non-empty)
    /// @param data Callback data (empty = regular swap, non-empty = flash swap)
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external {
        require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT_AMOUNT");

        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;

        require(
            amount0Out < _reserve0 && amount1Out < _reserve1,
            "INSUFFICIENT_LIQUIDITY"
        );

        // Step 1: Optimistic transfer - send tokens before receiving payment
        if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);

        // Step 2: Execute flash loan callback if data is provided
        if (data.length > 0) {
            IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        }

        // Step 3: Get current balances after callback
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        // Step 4: Calculate actual input amounts
        // Logic: If only "output transfer" occurred, balance would be (reserve - amountOut)
        // Any excess beyond that is the actual amountIn
        uint256 amount0In;
        uint256 amount1In;
        {
            uint256 balance0AfterOut = uint256(_reserve0) - amount0Out;
            uint256 balance1AfterOut = uint256(_reserve1) - amount1Out;
            amount0In = balance0 > balance0AfterOut ? balance0 - balance0AfterOut : 0;
            amount1In = balance1 > balance1AfterOut ? balance1 - balance1AfterOut : 0;
        }
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT_AMOUNT");

        // Step 5: Verify K invariant (with 0.3% fee)
        // Formula: (balance0 * 1000 - amount0In * 3) * (balance1 * 1000 - amount1In * 3)
        //          >= reserve0 * reserve1 * 1000000
        {
            uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(
                balance0Adjusted * balance1Adjusted >=
                    uint256(_reserve0) * uint256(_reserve1) * 1000000,
                "K"
            );
        }

        // Step 6: Update reserves
        _sync();
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @notice Executes a simple swap without callback
    /// @dev Used for price manipulation in the attack demo.
    ///      Implements the constant product formula: x * y = k
    ///      Output = amountIn * 997 * reserveOut / (reserveIn * 1000 + amountIn * 997)
    /// @param amountIn The input token amount
    /// @param oneForZero True: swap token1→token0, False: swap token0→token1
    /// @return amountOut The output token amount
    function swapExact(
        uint256 amountIn,
        bool oneForZero
    ) external returns (uint256 amountOut) {
        // Determine input/output reserves based on swap direction
        (uint256 rIn, uint256 rOut) = oneForZero
            ? (reserve1, reserve0)
            : (reserve0, reserve1);

        // Calculate output using constant product formula with 0.3% fee
        amountOut = (amountIn * 997 * rOut) / (rIn * 1000 + amountIn * 997);

        // Execute the swap
        if (oneForZero) {
            // Swap token1 for token0
            IERC20(token1).transferFrom(msg.sender, address(this), amountIn);
            IERC20(token0).transfer(msg.sender, amountOut);
        } else {
            // Swap token0 for token1
            IERC20(token0).transferFrom(msg.sender, address(this), amountIn);
            IERC20(token1).transfer(msg.sender, amountOut);
        }

        _sync();
    }

    /// @notice Returns the current spot price of token0 in terms of token1
    /// @dev Price = reserve1 / reserve0
    ///      WARNING: This spot price can be manipulated within a single transaction
    ///      using flash loans. Do NOT use as a price oracle in production.
    /// @return The price (no decimal scaling, direct ratio)
    function getPrice() external view returns (uint256) {
        return uint256(reserve1) / reserve0;
    }

    /// @notice Updates reserves to match current token balances
    /// @dev Called after any operation that changes the pool's token balances
    function _sync() private {
        reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(IERC20(token1).balanceOf(address(this)));
        emit Sync(reserve0, reserve1);
    }
}
