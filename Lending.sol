// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IERC20.sol";
import "./interfaces/IPair.sol";
import "./interfaces/ILending.sol";

/// @title Vulnerable Lending Protocol
/// @notice A deliberately vulnerable lending protocol for educational demonstration
/// @dev ⚠️ WARNING: This contract is INTENTIONALLY VULNERABLE!
///      It uses DEX spot price as an oracle, which can be manipulated via flash loans.
///      DO NOT use this pattern in production. Always use time-weighted average prices
///      (TWAP) or decentralized oracle networks (e.g., Chainlink) for price feeds.
contract Lending is ILending {
    /// @notice The DEX pair used as a price oracle (VULNERABLE!)
    IPair public oracle;

    /// @notice The collateral token (WETH)
    IERC20 public weth;

    /// @notice The borrow token (DAI)
    IERC20 public dai;

    /// @notice Mapping of user addresses to their collateral amounts
    mapping(address => uint256) public collateral;

    /// @notice Mapping of user addresses to their debt amounts
    mapping(address => uint256) public debt;

    /// @notice Emitted when a user deposits collateral
    /// @param user The depositor's address
    /// @param amount The amount of WETH deposited
    event Deposit(address indexed user, uint256 amount);

    /// @notice Emitted when a user borrows DAI
    /// @param user The borrower's address
    /// @param amount The amount of DAI borrowed
    /// @param priceUsed The WETH price used for calculation (can be manipulated!)
    event Borrow(address indexed user, uint256 amount, uint256 priceUsed);

    /// @notice Creates a new Lending protocol instance
    /// @param _oracle The DEX pair to use as price oracle (e.g., Pool B)
    /// @param _weth The WETH token address
    /// @param _dai The DAI token address
    constructor(address _oracle, address _weth, address _dai) {
        oracle = IPair(_oracle);
        weth = IERC20(_weth);
        dai = IERC20(_dai);
    }

    /// @notice Gets the current WETH price from the DEX oracle
    /// @dev ⚠️ VULNERABILITY: Reads spot price directly from DEX reserves.
    ///      This can be manipulated by:
    ///      1. Flash loaning a large amount of tokens
    ///      2. Swapping to move the price
    ///      3. Exploiting the inflated price
    ///      4. Swapping back and repaying the flash loan
    ///
    ///      SECURE ALTERNATIVES:
    ///      - Uniswap V2/V3 TWAP (time-weighted average price)
    ///      - Chainlink price feeds
    ///      - Multiple oracle sources with median
    ///
    /// @return The price in DAI per WETH (no decimal scaling)
    function getPrice() public view returns (uint256) {
        return uint256(oracle.reserve1()) / oracle.reserve0();
    }

    /// @notice Deposits WETH as collateral
    /// @param amount The amount of WETH to deposit
    function deposit(uint256 amount) external {
        weth.transferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    /// @notice Borrows DAI against deposited collateral
    /// @dev Uses 80% collateral ratio (LTV = 80%)
    ///      Maximum borrow = collateral * price * 80%
    /// @param amount The amount of DAI to borrow
    function borrow(uint256 amount) external {
        uint256 price = getPrice();
        uint256 maxAmount = (collateral[msg.sender] * price * 80) / 100;

        require(debt[msg.sender] + amount <= maxAmount, "Undercollateralized");

        debt[msg.sender] += amount;
        dai.transfer(msg.sender, amount);

        emit Borrow(msg.sender, amount, price);
    }

    /// @notice Calculates the maximum borrowable amount for a user
    /// @dev Max borrow = (collateral * price * 80%) - existing debt
    /// @param user The user's address
    /// @return The maximum additional DAI that can be borrowed
    function maxBorrow(address user) external view returns (uint256) {
        uint256 max = (collateral[user] * getPrice() * 80) / 100;
        return max > debt[user] ? max - debt[user] : 0;
    }
}
