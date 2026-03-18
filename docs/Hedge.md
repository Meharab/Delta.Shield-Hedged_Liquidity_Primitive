# Hedge Execution Layer

*(Determine Optimal Strategy + Executes Hedge)*

> **protocol-level design document for the Hedge Execution Layer**

System’s **Hedging Execution Layer** is where the abstract idea of *“risk detected → hedge applied”* becomes an **actual on-chain financial action**. This is the **actuator** in a control system.

The architecture becomes a **closed-loop risk control system**:

```solidity
Market State  →  Risk Detection  →  Risk Decision  →  Hedge Execution  →  Updated Position
     ↑                                                                    ↓
     └────────────────────── Feedback / Monitoring ───────────────────────┘
```

The project already defined:

* **AMM Hook (Onchain Risk Detection)** → monitors price, volatility, liquidity
* **Reactive Automation (Decision Engine)** → decides when hedging is required

This is the design of the **Hedging Execution Layer** that **actually places the hedge trade**.

Let’s break it from first principles.



# Problem & Solution

In DeFi, exposure is created when a user holds a position:

Examples:

| Position                        | Risk                       |
| ------------------------------- | -------------------------- |
| LP in ETH/USDC pool             | Impermanent Loss           |
| Long ETH                        | Downside price crash       |
| Borrowed stablecoin against ETH | Liquidation risk           |
| Perpetual long                  | Funding & liquidation risk |

Hedging means:

> Opening a **counter-position** that offsets risk.

Example:

```solidity
User Position:
Long ETH exposure via LP

Hedge:
Short ETH via perpetual futures
```

So the execution layer must:

1. Receive **hedging instruction**
2. Determine **how much hedge**
3. Execute **derivative or synthetic trade**
4. Track the hedge position



# Core Components

The execution layer consists of **five core modules**.

```solidity
Hedging Execution Layer
│
├── 1. Hedge Strategy Module
├── 2. Position Calculator
├── 3. Derivatives Adapter
├── 4. Trade Executor
└── 5. Hedge Position Manager
```

Let’s analyze each component rigorously.



## 1. Hedge Strategy Module

### i. Purpose

Defines **how the hedge should behave**.

Different risks require different strategies.

### ii. Inputs

Example:
```solidity
risk_event {
    asset
    exposure_size
    volatility
    risk_type
}
```

### iii. Example risk types

| Risk                 | Strategy            |
| -------------------- | ------------------- |
| Impermanent Loss     | Short base asset    |
| Liquidation Risk     | Buy protective put  |
| Downside volatility  | Delta neutral hedge |
| Portfolio volatility | Beta hedge          |

### iv. Example strategy

```solidity
If ETH exposure > threshold
AND volatility > threshold

→ hedge 70% exposure using short ETH perpetual
```

### v. Smart contract pseudo-interface

```solidity
interface IHedgeStrategy {
    function getHedgeRatio(
        address asset,
        uint256 exposure
    ) external returns (uint256);
}
```

Example output:

```solidity
Exposure = 100 ETH
Hedge ratio = 70%

→ Hedge size = 70 ETH
```



## 2. Position Calculator

This module computes **how big the hedge must be**.

This is a **risk math engine**.



### 2.1 Delta Hedging Model

Simplest hedge:

```solidity
Hedge Size = Exposure × Hedge Ratio
```

Example:

```solidity
Exposure = 100 ETH
Hedge ratio = 0.7

Hedge = 70 ETH short
```

---

### 2.2 Impermanent Loss Hedge

For LPs:

```solidity
Pool: ETH/USDC
Value = 100k

Exposure ≈ 50 ETH
```

If ETH drops:

- LP loses value

So hedge:

- Short ETH perpetual



### 2.3 Volatility Hedge

If volatility spikes:

```solidity
Hedge = buy options
```

But options are rare in DeFi testnets.

So we approximate using **perpetuals**.



## 3. Derivatives Adapter Layer

The execution layer **must interact with derivatives protocols**.

Instead of hardcoding one protocol, we design **adapters**.

Architecture:

```solidity
                Hedge Executor
                     │
        ┌────────────┼────────────┐
        │            │            │
  GMX Adapter   Synthetix Adapter  Mock Perp
```

This creates **protocol abstraction**.



### i. Adapter Interface

```solidity
interface IDerivativesAdapter {

    function openShort(
        address asset,
        uint256 size
    ) external returns (uint256 positionId);

    function closePosition(
        uint256 positionId
    ) external;
}
```



### ii. Example: Mock Perpetual Adapter (for Unichain)

```solidity
openShort(ETH, 70)
```

Internally:

```solidity
position = {
    direction: SHORT
    asset: ETH
    size: 70
}
```



## 4. Trade Executor

This component actually **executes the hedge trade**.

It receives:

```solidity
HedgeInstruction {
    asset
    hedge_size
    hedge_type
}
```

Execution flow:

1. Detect hedge event
2. Calculate hedge size
3. Select derivative protocol
4. Open position

Pseudo Solidity:

```solidity
function executeHedge(
    address asset,
    uint256 exposure
) external {

    uint hedgeRatio = strategy.getHedgeRatio(asset, exposure);

    uint hedgeSize = exposure * hedgeRatio / 1e18;

    adapter.openShort(asset, hedgeSize);
}
```



## 5. Hedge Position Manager

Once hedge positions exist, they must be **tracked**.

This module stores:

```solidity
hedge_position {
    user
    asset
    size
    direction
    protocol
}
```

Storage:

```solidity
mapping(address => HedgePosition[]) positions;
```



### Responsibilities

### i. Track open hedges

```solidity
User → short ETH 70
```

### ii. Rebalance hedge

If exposure changes:

```solidity
Old hedge = 70 ETH
New exposure = 150 ETH
Target hedge = 105 ETH
```

System must add:

```solidity
+35 ETH short
```



### iii. Close hedge

If risk disappears:

```
closePosition()
```



# System Workflow (End-to-End)

Let’s trace a full execution.



### Step 1: Risk detected

Oracle detects volatility spike.

```solidity
ETH volatility > threshold
```



### Step 2: Risk engine triggers

```solidity
risk_event = {
    asset: ETH
    exposure: 100
}
```



### Step 3: Hedge decision

Strategy returns:

```solidity
hedge_ratio = 0.7
```



### Step 4: Hedge size

```solidity
100 × 0.7 = 70 ETH
```



### Step 5: Execution

Executor calls:

```solidity
adapter.openShort(ETH, 70)
```



### Step 6: Position stored

```solidity
HedgePosition {
    asset: ETH
    direction: SHORT
    size: 70
}
```



# Full Smart Contract Architecture

```solidity
            Reactive Automation Controller
                         │
                         ▼
                  Hedge Controller
                         │
            ┌────────────┴────────────┐
            │                         │
     Hedge Strategy           Position Calculator
            │                         │
            └────────────┬────────────┘
                         ▼
                    Hedge Executor
                         │
          ┌──────────────┼──────────────┐
          │              │              │
      GMX Adapter   Synthetix Adapter   Mock Perp
                         │
                         ▼
                  Derivative Trade
```



# Minimal MVP Implementation

For this **hackathon MVP**, the implementation will be:

1. Reactive Automation Controller
2. Hedge Controller
3. Mock Perpetual Adapter
4. Hedge Executor

There will NO full derivatives protocol for the time being.

Mock engine:

```solidity
struct Position {
    address asset;
    int size;
}
```

This simulates hedging.



# Mathematical Risk Reduction

Suppose:

```solidity
User Exposure = +100 ETH
```

Hedge:

```solidity
Short 70 ETH
```

Net exposure:

```solidity
+100 - 70 = +30 ETH
```

Price drop:

```solidity
ETH: 2000 → 1500
```

Loss without hedge:

```solidity
100 × 500 = -50k
```

Hedge profit:

```solidity
70 × 500 = +35k
```

Net loss:

```solidity
-15k
```

Risk reduced **70%**.



# Key Design Decisions

### 1. Why Perpetual Futures?

Because they are:

* liquid
* simple
* continuous
* easy to simulate

Options will be harder for time being.



### 2. Why adapters?

Protocols evolve.

Adapters allow:

- swap derivative backend

without changing core system.



# Limitations

Important engineering realities:

### 1. Liquidity risk

Perp markets may not have enough liquidity.



### 2. Oracle lag

Price movement before hedge executes.



### 3. Funding rate risk

Perpetual shorts pay funding sometimes.



### 4. Execution delay

Automation triggers are not instant.



# Final Mental Model

Thinking the system as:

```solidity
Risk Radar  →  Hedge Brain  →  Hedge Muscle
```

Where:

- Radar = Sentinel
- Brain = Strategy Engine
- Muscle = Execution Layer

The current step built the **muscle**.



# Hedging Requirements

Your AMM layer produces a signal:

```solidity
delta = +5 ETH
```

Meaning the LP behaves like it holds **+5 ETH exposure**.

To neutralize that, the system must create **−5 ETH exposure** somewhere.

There are only **three fundamental mechanisms** in DeFi capable of doing this.

| Mechanism         | Exposure Created | Capital Efficiency |
| ----------------- | ---------------- | ------------------ |
| Perpetual Futures | short ETH        | very high          |
| Options           | short delta      | medium             |
| Spot Swap         | sell ETH         | low                |

Options are unrealistic for the time being.

So the real decision is:

**Perps vs Synthetic Spot Hedge**



#  Testnet Availability

Check availability whether any **perpetual protocol exists on Unichain testnet**.

Unichain is still new. Most derivatives protocols (GMX, Drift, Hyperliquid, etc.) are **not deployed there yet**.

This means:

**Direct perps integration on Unichain is unlikely.**

Even if one existed, integrating it would require:

* margin management
* liquidation logic
* oracle dependencies
* funding rate handling

That is **far beyond current scope** of the MVP.

So we eliminate the “real perps integration” path.



# Viable Hedging Approaches

The current the realistic paths:

## Approach A: Synthetic Hedge Using Spot Swaps

Instead of opening perps, the system performs a swap.

Example:

```solidity
LP delta = +5 ETH
```

Reactive automation executes:

```solidity
Swap 5 ETH → USDC
```

Now exposure becomes:

| Component    | Exposure |
| ------------ | -------- |
| LP position  | +5 ETH   |
| Hedge wallet | −5 ETH   |
| Net          | ~0       |

Advantages:

* extremely simple
* no derivatives infrastructure
* easy to test

Disadvantages:

* capital inefficient
* not “true perps”
* requires holding hedge inventory

But for demonstration, this works.



## Approach B: Minimal Perpetual Engine (Mock Perps)

Instead of integrating a real derivatives protocol, developing **minimal perpetual contract** is a viable choice.

It can be a **derivatives sandbox**.

Features:

```solidity
openPosition(size, direction)
closePosition(positionId)
getPositionExposure()
```
Excluding:

- No funding rates.
- No liquidation.
- No margin complexity.

Just a contract that tracks **synthetic exposure**.

Example state:

```solidity
struct Position {
    int256 size;
    uint256 entryPrice;
}
```

If system opens:

```solidity
short 5 ETH
```

The contract records:

```solidity
size = -5
```

When price changes, PnL is computed.

This demonstrates the concept **without building a full perps exchange**.



# Final Strategy

The optimal solution is actually a **hybrid architecture**.

### 1. Primary Hedge

Synthetic hedge via swaps on Uniswap pools.

```solidity
ETH → USDC
```

### 2. Secondary Hedge

Include a **minimal PerpsEngine contract** to show:

```solidity
openShort(size)
closeShort(size)
getNetExposure()
```

Hedge Controller will chooses which hedge to execute.



# Final Architecture

```solidity
Hedge Controller
       │
       ▼
Hedge Execution Router
       │
       ├── Spot Hedge (Uniswap swap)
       │
       └── Mock Perps Engine
```

This provides **two hedging strategies**.

The system can even select between them based of risk factors.

Example logic:

```solidity
if hedgeSize < liquidityThreshold:
    useSpotHedge()
else:
    usePerpsEngine()
```

That is architecturally elegant.



# MVP Scope

| Approach               | Complexity | Realism | Time          |
| ---------------------- | ---------- | ------- | ------------- |
| Real Perps Integration | very high  | high    | ❌ impossible |
| Mock Perps Engine      | medium     | medium  | ✅ feasible   |
| Spot Hedge             | low        | low     | ✅ trivial    |

Best MVP architecture:

```solidity
Mock Perps Engine + Spot Hedge
```



# Example scenario

Initial LP state:

```solidity
10 ETH
20k USDC
```

Hook detects:

```solidity
delta = +5 ETH
```

Hedge Controller executes:

```solidity
openShort(5 ETH)
```

Later price rises.

System shows:

```solidity
LP loss: -$400
Perps PnL: +$390
Fees: +$120
Net: +$110
```



# Design Choice

Building your own minimal hedge engine has advantages.

Control over:

* API
* event emission
* position accounting

It can be design **perfectly for the hook system**.



# Final Decision

For this MVP:

**Implement:**

1. Spot swap hedging via Uniswap pools
2. Minimal PerpsEngine contract for demonstration

Avoid:

* integrating real perps protocols
* margin mechanics
* liquidation engines



# Hedge Capital 

There is a subtle but **extremely important engineering question** for this project:

> **Where does the hedge capital come from?**

Because opening a derivative position requires:

- margin collateral

Your system must decide:

- User funds?
- Protocol treasury?
- Synthetic collateral?

This design decision dramatically changes the protocol architecture.

That problem sits at the intersection of **DeFi protocol design, risk management, and economic incentives**, exactly the kind of design puzzle that opens door for this protocol for research.



# Security

The current **control system** design:

```solidity
Signal Source  →  Risk Analysis  →  Decision Engine  →  Execution
(price data)       (math)            (policy)           (trades)
```

Each layer architecture must respect these boundaries.



A Uniswap pool already contains price information.

But the deeper question is:

> **What type of price information will this project needs?**

Not all prices are equal.



## i. Price Types in DeFi

There are **three different price concepts**.

### 1. Instantaneous Pool Price

Inside the pool:

```solidity
price = sqrtPriceX96
```

Derived from the tick:

```solidity
price = 1.0001^tick
```

This is the **current execution price**.

Pros:

* free
* real-time
* on-chain

Cons:

* manipulable
* single pool only

If someone performs a large swap:

- price can move dramatically in one block



### 2. TWAP (Time Weighted Average Price)

Uniswap pools maintain cumulative price:

- priceCumulative

TWAP:

```solidity
TWAP = (priceCumulative2 - priceCumulative1) / time
```

Pros:

* harder to manipulate
* on-chain

Cons:

* still local to one pool
* limited historical depth



### 3. External Oracle Price

Example systems:

* Chainlink
* Pyth
* Redstone

Pros:

* cross-exchange aggregation
* robust against manipulation
* global market reference

Cons:

* update latency
* external dependency



## ii. Requirement for Hedging

The hedge system needs to detect **market volatility** and **directional risk**.

Example:

```solidity
ETH price dropped 7% in 5 minutes
```

The v4 pool price alone cannot reliably tell this because:

* it can be manipulated
* it reflects only **one liquidity pool**

Example attack:

1. Attacker swaps
2. price moves
3. hook opens hedge
4. attacker reverses swap

Now the protocol hedges against a **fake market movement**.

This is why **robust systems combine signals**.



## iii. Best Practice Architecture

Use **two price signals**:

```solidity
Primary signal:
Uniswap v4 pool price

Verification signal:
External oracle
```

Example rule:

```solidity
IF pool_price deviation > threshold
AND oracle_price deviation > threshold

→ hedge
```

This prevents manipulation.



# Design Philisophy

This is the most critical architecture decision.

**Never put heavy logic in hooks.**

Let’s examine why.



## Uniswap v4 Hooks

Hooks are designed to be:

- lightweight
- stateless (mostly)
- execution interceptors

Hooks are **not meant to be full protocols**.

They intercept lifecycle events:

```solidity
beforeSwap
afterSwap
beforeAddLiquidity
afterRemoveLiquidity
```

Their job is:

```solidity
observe → record → modify parameters
```

NOT run complex financial systems



### i. Gas Constraints

Hooks run **inside the swap execution path**.

Every extra computation increases swap cost.

Example bad design:

```soilidity
swap()
  → hook
      → risk model
      → hedge execution
      → derivatives trade
```

Now a simple swap becomes extremely expensive.

This breaks UX.



### ii. Architecturel Decision

Separate the logic into two layers.

```solidity
Hook Layer (data collection)
Controller Layer (logic + execution)
```



## Layer Responsibilities

### 1. Hook Contract

Minimal responsibilities.

1. observe swap
2. calculate exposure
3. store state
4. emit event

Example data recorded:

```solidity
struct PoolExposure {
    uint256 liquidity
    int256 deltaExposure
    uint256 lastPrice
}
```

Hook emits:

```solidity
ExposureUpdated(poolId, exposure)
```



### 2. Hedge Controller Contract

This is the **protocol brain**.

Responsibilities:

1. risk evaluation
2. strategy execution
3. hedge size calculation
4. derivative execution
5. position tracking

Functions:

```solidity
evaluateRisk()
calculateHedge()
executeHedge()
rebalance()
```



### 3. Derivatives Adapter Contracts

External integrations.

1. GMX adapter
2. MockPerp adapter
3. Synthetix adapter



# Final Architecture

```solidity
                Uniswap v4 Pool
                       │
                       ▼
                  Hook Contract
              (execution observer)
                       │
                 emits event
                       │
                       ▼
              Reactive Network
                (automation)
                       │
                       ▼
               Hedge Controller
             (risk + strategy)
                       │
                       ▼
              Derivatives Adapter
                       │
                       ▼
               Hedge Position
```

This design has several advantages.



### Advantage 1: Cheap swaps

Hooks remain lightweight.



### Advantage 2: Modular architecture

This can swap out:

1. strategy modules
2. derivative protocols
3. risk models



### Advantage 3: Security isolation

If the hedge logic breaks:

- AMM still works

This is extremely important.



# Calculation



### 1. Hedge Strategy

Location:

- `HedgeController.sol`



### 2. Position Calculation

Location:

- `HedgeController.sol`



### 3. Derivatives Adapter Selection

Location:

- `HedgeController.sol`



### 4. Hedge Position Management

Location:

- `HedgeController.sol`



### 5. Hook Responsibilities

Only:

1. exposure tracking
2. pool state recording
3. event emission



# Mental Model

Hooks are **sensors**, not brains.

```solidity
Hook = Sensor
Controller = Brain
Executor = Muscle
```

System becomes:

```solidity
Sensor → Brain → Muscle
```

Flow becomes:

```solidity
Uniswap Swap
      ↓
Hook emits event
      ↓
Reactive contract detects
      ↓
Hedge execution triggered
```



# Architectural Detail

A very subtle design improvement can make your project significantly more impressive to judges.

Instead of hooks emitting generic events:

- `ExposureUpdated`

Emit **structured risk signals**.

Example:

```solidity
RiskSignal {
    pool
    price_change
    volatility
    liquidity_change
}
```

Now Reactive Network can trigger logic only when **real risk appears**, not every swap.

This makes the system:

- more efficient
- more elegant
- more research-grade

Finally:

```solidity
Hook Event
   ↓
Reactive Contract
   ↓
Hedge Controller
   ↓
Derivative Execution
```




# The Deeper Insight

The truly interesting thing about this project isn't the hedging itself.

It is that **Uniswap v4 hooks can turn AMMs into programmable market makers**.

This system becomes something very close to a **self-hedging AMM vault**, a design that many institutional market makers already run off-chain.

Now it could exist **natively inside the protocol layer**.



# Conclusion

The real intellectual novelty is:

**Turning Uniswap pools into self-protecting liquidity systems.**

Liquidity providers usually face:

- price volatility
- impermanent loss
- toxic order flow

This design makes the pool **reactively hedge itself**.

That opens doors for a research **DeFi primitive**.

Uniswap pools today are **passive liquidity**.

This hook architecture moves them toward **active liquidity management systems**.

Which is exactly the direction many researchers believe DeFi will evolve.