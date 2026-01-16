# 闪电贷攻击演示

中文 | [English](./README.md)

完整的闪电贷价格预言机攻击教学演示。

> ⚠️ **免责声明**：本项目仅供学习研究，请勿用于非法用途。

## 概述

闪电贷本身不是漏洞，它只是**放大器**。真正的漏洞是：**使用 DEX 即时价格作为预言机**。

AMM（自动做市商）的价格由池子比例决定：

```
价格 = reserve1 / reserve0
```

大额交易会**立即**改变这个比例，从而操纵价格。

## 攻击四步曲

1. **闪电贷**：从 Pool A 借入大量 DAI（无需抵押）
2. **价格操纵**：在 Pool B 用 DAI 买 WETH，拉高 WETH 价格
3. **漏洞利用**：将 WETH 存入 Lending 作抵押，按虚高价格借出超额 DAI
4. **还款获利**：归还闪电贷，剩余即为利润

### 数学示例（以本演示为例）

```
初始状态：
  Pool B: 100 WETH + 300,000 DAI，价格 = 3,000 DAI/WETH

攻击过程：
  1. 从 Pool A 借 1,500,000 DAI
  2. 用 1,350,000 DAI 在 Pool B 买 WETH
     → 获得约 81 WETH
     → Pool B 新价格 ≈ 86,842 DAI/WETH（涨了 29 倍！）
  3. 存 81 WETH 到 Lending
     → 按虚高价格计算抵押价值：81 × 86,842 ≈ 7,034,202 DAI
     → 可借 (80%)：约 5,627,361 DAI
  4. 还款 1,504,514 DAI（本金 + 0.3% 手续费）
  
利润：5,627,361 - 1,504,514 + 150,000 ≈ 4,272,847 DAI
```

## 架构图

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

## 文件结构

```
flash_loan_attack_demo/
├── interfaces/
│   ├── IERC20.sol           # ERC20 标准接口
│   ├── ILending.sol         # 借贷协议接口
│   ├── IPair.sol            # 交易对接口
│   └── IUniswapV2Callee.sol # 闪电贷回调接口
│
├── Attacker.sol             # 攻击合约
├── ERC20.sol                # 测试代币
├── Lending.sol              # 有漏洞的借贷协议
├── UniswapV2Pair.sol        # 交易对（部署两次）
├── README.md                # 英文文档
└── README_CN.md             # 中文文档
```

## 重要说明：代币精度

> ⚠️ **为了演示简便，本项目的 ERC20 代币使用 0 位精度，而非标准的 18 位精度。**

生产环境中：
- 标准 ERC20 代币使用 18 位精度
- 1 个代币 = 1 × 10^18 最小单位
- 价格和计算必须考虑精度缩放

本演示中：
- 代币使用 0 位精度
- 1 个代币 = 1 最小单位
- 使数字更易读和理解

**请勿在生产环境中使用此 ERC20 实现！**

## Remix 部署步骤

### 1. 部署代币

```solidity
// 部署 WETH
ERC20("Wrapped Ether", "WETH")
// 调用 mint(20000)

// 部署 DAI  
ERC20("Dai Stablecoin", "DAI")
// 调用 mint(60000000)
```

### 2. 部署交易对

```solidity
// Pool A（大池 - 闪电贷来源）
UniswapV2Pair(WETH_ADDRESS, DAI_ADDRESS)
// Approve & addLiquidity(10000, 30000000)

// Pool B（小池 - 价格预言机）
UniswapV2Pair(WETH_ADDRESS, DAI_ADDRESS)
// Approve & addLiquidity(100, 300000)
```

### 3. 部署借贷协议

```solidity
// 构造函数：传入 Pool B 地址（用作价格预言机）
Lending(POOL_B_ADDRESS, WETH_ADDRESS, DAI_ADDRESS)

// 转入 20,000,000 DAI 作为储备
DAI.transfer(LENDING_ADDRESS, 20000000)
```

### 4. 部署攻击合约

```solidity
Attacker(
    POOL_A_ADDRESS,    // 闪电贷来源
    POOL_B_ADDRESS,    // 价格操纵目标
    LENDING_ADDRESS,   // 受害协议
    WETH_ADDRESS,
    DAI_ADDRESS
)
```

### 5. 执行攻击

```solidity
Attacker.attack(1500000)  // 闪电贷 150 万 DAI
```

## 攻击结果

从 [Attacker 合约日志](https://sepolia.etherscan.io/address/0x562192326504d8966e56097eab2dfc7e304dbd8a#events) 可以看到：

- 闪电贷金额：1,500,000 DAI
- 获得 WETH：约 81 WETH
- 操纵前价格：3,000 DAI/WETH
- 操纵后价格：86,842 DAI/WETH
- **利润：4,272,847 DAI**

## 常见问题

### 为什么需要两个池子？

Uniswap V2 的 `swap` 函数有重入锁，回调期间无法调用同池的 `swap`。这也解释了为什么真实攻击通常涉及多个协议。

### Pool B 为什么这么小？

教学演示用。真实场景中，攻击者会寻找流动性薄弱的池子，更容易操纵价格。

### 如何防范此类攻击？

1. **使用 TWAP（时间加权平均价格）**：Uniswap V2/V3 内置 TWAP 预言机
2. **使用 Chainlink 等去中心化预言机**：抵抗单笔交易操纵
3. **多预言机源**：使用多个价格源的中位数
4. **价格偏差检查**：如果价格偏离近期均值过大则拒绝交易

## 许可证

MIT

---

> ⚠️ 本项目仅供学习研究，请勿用于非法用途。
