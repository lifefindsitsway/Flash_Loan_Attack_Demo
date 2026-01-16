# Flash Loan Attack Demo

[中文版](./README_CN.md) | English

A complete educational demonstration of flash loan price oracle attacks on DeFi protocols.

> ⚠️ **DISCLAIMER**: This project is for educational purposes only. Do not use this knowledge for malicious activities.

## Overview

Flash loans themselves are not vulnerabilities—they are **amplifiers**. The real vulnerability is **using DEX spot prices as oracles**.

AMM (Automated Market Maker) prices are determined by pool reserves:

```
Price = reserve1 / reserve0
```

Large trades **immediately** change this ratio, enabling price manipulation.

## The Attack in 4 Steps

1. **Flash Loan**: Borrow large amount of DAI from Pool A (no collateral needed)
2. **Price Manipulation**: Use DAI to buy WETH in Pool B, pumping WETH price
3. **Exploit**: Deposit WETH in Lending as collateral, borrow DAI at inflated price
4. **Repay & Profit**: Return flash loan, keep the difference as profit

### Math Example (Using This Demo)

```
Initial State:
  Pool B: 100 WETH + 300,000 DAI, Price = 3,000 DAI/WETH

Attack Flow:
  1. Flash loan 1,500,000 DAI from Pool A
  2. Swap 1,350,000 DAI for WETH in Pool B
     → Receive ~81 WETH
     → Pool B new price ≈ 86,842 DAI/WETH (29x increase!)
  3. Deposit 81 WETH to Lending
     → Collateral value at inflated price: 81 × 86,842 ≈ 7,034,202 DAI
     → Max borrow (80% LTV): ~5,627,361 DAI
  4. Repay 1,504,514 DAI (principal + 0.3% fee)
  
Profit: 5,627,361 - 1,504,514 + 150,000 ≈ 4,272,847 DAI
```

## Architecture

```
┌─────────────┐                    ┌─────────────┐
│  FlashPair  │ ───── Borrow ────→ │             │
│  (Pool A)   │ ←──── Repay ────── │             │
└─────────────┘                    │             │
                                   │             │
┌─────────────┐                    │             │
│ OraclePair  │ ←── Buy WETH ───── │             │
│  (Pool B)   │    (pump price)    │  Attacker   │
└─────────────┘                    │             │
       ↑                           │             │
       │ Read price                │             │
┌─────────────┐                    │             │
│   Lending   │ ←── Deposit ────── │             │
│  (Victim)   │ ─── Over-borrow ─→ │             │
└─────────────┘                    └─────────────┘
```

## Project Structure

```
flash_loan_attack_demo/
├── interfaces/
│   ├── IERC20.sol           # ERC20 standard interface
│   ├── ILending.sol         # Lending protocol interface
│   ├── IPair.sol            # Trading pair interface
│   └── IUniswapV2Callee.sol # Flash loan callback interface
│
├── Attacker.sol             # Attack contract
├── ERC20.sol                # Test token
├── Lending.sol              # Vulnerable lending protocol
├── UniswapV2Pair.sol        # Trading pair (deploy twice)
├── README.md                # English documentation
└── README_CN.md             # Chinese documentation
```

## Important Note: Token Decimals

> ⚠️ **For demonstration simplicity, the ERC20 token uses 0 decimals instead of the standard 18 decimals.**

In production:
- Standard ERC20 tokens use 18 decimals
- 1 token = 1 × 10^18 smallest units
- Prices and calculations must account for decimal scaling

In this demo:
- Tokens use 0 decimals
- 1 token = 1 smallest unit
- Makes numbers easier to read and understand

**Do NOT use this ERC20 implementation in production!**

## Deployment Guide (Remix)

### 1. Deploy Tokens

```solidity
// Deploy WETH
ERC20("Wrapped Ether", "WETH")
// Call mint(20000)

// Deploy DAI  
ERC20("Dai Stablecoin", "DAI")
// Call mint(60000000)
```

### 2. Deploy Trading Pairs

```solidity
// Pool A (Large pool - flash loan source)
UniswapV2Pair(WETH_ADDRESS, DAI_ADDRESS)
// Approve & addLiquidity(10000, 30000000)

// Pool B (Small pool - price oracle)
UniswapV2Pair(WETH_ADDRESS, DAI_ADDRESS)
// Approve & addLiquidity(100, 300000)
```

### 3. Deploy Lending Protocol

```solidity
// Constructor: pass Pool B address (used as price oracle)
Lending(POOL_B_ADDRESS, WETH_ADDRESS, DAI_ADDRESS)

// Transfer 20,000,000 DAI as reserves
DAI.transfer(LENDING_ADDRESS, 20000000)
```

### 4. Deploy Attacker Contract

```solidity
Attacker(
    POOL_A_ADDRESS,    // Flash loan source
    POOL_B_ADDRESS,    // Price manipulation target
    LENDING_ADDRESS,   // Victim protocol
    WETH_ADDRESS,
    DAI_ADDRESS
)
```

### 5. Execute Attack

```solidity
Attacker.attack(1500000)  // Flash loan 1.5M DAI
```

## Attack Results

View the [Attacker contract logs on Etherscan](https://sepolia.etherscan.io/address/0x562192326504d8966e56097eab2dfc7e304dbd8a#events) to see:

- Flash loan: 1,500,000 DAI
- WETH received: ~81 WETH
- Price before: 3,000 DAI/WETH
- Price after: 86,842 DAI/WETH
- **Profit: 4,272,847 DAI**

## FAQ

### Why two separate pools?

Uniswap V2's `swap` function has a reentrancy lock, preventing callbacks from calling `swap` on the same pool. This also explains why real-world attacks typically involve multiple protocols.

### Why is Pool B so small?

For educational demonstration. In real scenarios, attackers target pools with low liquidity where price manipulation is easier.

### How to prevent this attack?

1. **Use TWAP (Time-Weighted Average Price)**: Uniswap V2/V3 provides built-in TWAP oracles
2. **Use Chainlink or other decentralized oracles**: Resistant to single-transaction manipulation
3. **Multiple oracle sources**: Use median of multiple price feeds
4. **Price deviation checks**: Reject transactions if price deviates too much from recent average

## License

MIT

---

> ⚠️ This project is for educational and research purposes only. Do not use for illegal activities.
