# Introduction

The architecture has three logical layers:

1. **AMM Layer (execution + exposure tracking)**
2. **Reactive Automation Layer (monitoring + trigger logic)**
3. **Hedging Execution Layer (derivatives or synthetic hedge)**

The AMM side lives inside **Uniswap v4**, deployed on **Unichain**, while automation uses **Reactive Network**.



# System Architecture Overview

Conceptually, the system looks like this:

```solidity
                +-----------------------------+
                |        Traders              |
                |   (Swap ETH ↔ USDC etc.)    |
                +--------------+--------------+
                               |
                               v
                  +---------------------------+
                  |      Uniswap v4 Pool      |
                  | (ETH/USDC example pool)   |
                  +-------------+-------------+
                                |
                                v
                     +---------------------+
                     |  DeltaShield Hook   |
                     |---------------------|
                     | - exposure tracker  |
                     | - delta calculator  |
                     | - threshold logic   |
                     | - event emitter     |
                     +----------+----------+
                                |
                                v
                       HedgeRequired Event
                                |
                                v
              +-------------------------------------------+
              |     Reactive Smart Contract Layer         |
              |-------------------------------------------|
              | Monitors events from hook                 |
              | Decides when to rebalance hedge           |
              | Executes hedge transaction                |
              +----------------+--------------------------+
                               |
                               v
                  +-------------------------------+
                  | Hedging Execution Mechanism   |
                  |-------------------------------|
                  | Perpetual futures position    |
                  | or synthetic hedge swap       |
                  +-------------------------------+
```

The philosophy is simple:

**AMM tracks risk → automation hedges risk.**



# Core Components

### 1. Uniswap v4 Pool

This is the liquidity pool.

Example pair:

```solidity
ETH / USDC
```

LPs deposit assets and earn trading fees.

Important characteristics:

* constant product or concentrated liquidity
* price represented as `sqrtPriceX96`
* swaps continuously rebalance token reserves

The pool itself **does not know anything about hedging**.

Instead, it delegates logic to hooks.



### 2. DeltaShield Hook

This is the heart of the system.

Hooks in **Uniswap v4** allow custom logic during pool lifecycle events.

Relevant lifecycle events:

```solidity
beforeSwap()
afterSwap()
afterModifyPosition()
```

The hook maintains internal state.

Example storage layout:

```solidity
struct PoolExposureState {
    uint256 lastPrice;
    int256 lastDelta;
    uint256 lastHedgeTimestamp;
    uint256 deltaThreshold;
}
```

Responsibilities:

1. Read pool state
2. Estimate LP exposure
3. Compare exposure vs threshold
4. Emit hedge signal



# Exposure Calculation Module

The hook estimates LP directional exposure.

Simplified formula:

$$
\Huge \Delta = \frac{dV}{dP}
$$

For a symmetric LP position:

```solidity
delta ≈ liquidity_value / (2 * price)
```

Example:

```solidity
Pool price = $2000
LP liquidity value = $40,000

delta ≈ 40,000 / (2 * 2000)
delta ≈ 10 ETH
```

Meaning the LP behaves like **holding 10 ETH exposure**.

The hook calculates this whenever:

* swap occurs
* liquidity changes



# Threshold Decision Logic

We don’t hedge every tiny change.

Otherwise:

* gas cost explodes
* system oscillates

So we define:

- `deltaThreshold`

Example:

```solidity
deltaThreshold = 3 ETH
```

Decision logic:

```solidity
if abs(netDelta) > deltaThreshold:
    emit HedgeRequired
```

To avoid rapid oscillation, we also add:

- `minimumRebalanceInterval`

Example:

```solidity
30 minutes
```

Final logic:

```solidity
if abs(delta) > threshold AND
   time_since_last_hedge > interval:
       emit HedgeRequired
```



# Event Emission

When exposure is too large, the hook emits an event.

Example:

```solidity
event HedgeRequired(
    address pool,
    int256 delta,
    uint256 price,
    uint256 timestamp
);
```

Example emission:

```solidity
HedgeRequired(
    ETH/USDC pool,
    +5 ETH,
    $2050,
    block.timestamp
)
```

This is the **signal that hedging must occur**.



# Reactive Automation Layer

This layer is powered by **Reactive Network**.

Reactive contracts continuously watch on-chain events.

Workflow:

1. Subscribe to HedgeRequired events
2. Verify hedge conditions
3. Compute hedge size
4. Execute hedge transaction

Architecture:

```solidity
Reactive Watcher
        |
        v
Reactive Smart Contract
        |
        v
Execute hedge transaction
```

This removes the need for centralized keepers.



# Hedge Execution Mechanisms

Two design choices exist.

### 1. Perpetual Futures Hedge

Open derivative position.

Example:

```solidity
LP delta = +5 ETH
```

Reactive contract executes:

```solidity
Short 5 ETH perpetual
```

Exposure becomes:

```solidity
LP position: +5 ETH
Perps short: -5 ETH
Net exposure: 0
```

Price changes no longer affect net value significantly.



### 2. Synthetic Hedge Using Swaps

If perps are unavailable, hedge using spot trades.

Example:

```solidity
LP delta = +5 ETH
```

Reactive contract sells:

```solidity
5 ETH → USDC
```

This neutralizes exposure.

Less capital efficient.



# End-to-End Workflow Example

Let’s walk through the entire lifecycle.

### Initial State

```solidity
ETH price = $2000
LP deposits:
10 ETH
20,000 USDC
```

Total value:

```solidity
$40,000
```

Estimated exposure:

```solidity
delta ≈ 5 ETH
```

Threshold:

```solidity
3 ETH
```



### Step 1: Hook Detects Exposure

Hook calculates:

```solidity
delta = 5 ETH
```

Condition:

```solidity
5 > 3
```

Hook emits:

```solidity
HedgeRequired(5 ETH)
```



### Step 2: Reactive Network Listens

Reactive contract detects event.

Computes hedge:

```solidity
hedgeSize = -5 ETH
```



### Step 3: Hedge Execution

Reactive contract executes:

```solidity
Short 5 ETH perps
```

Now exposure:

```solidity
LP exposure = +5 ETH
Perps hedge = -5 ETH
Net delta = 0
```



### Step 4: Market Moves

ETH rises:

```solidity
$2000 → $2500
```

Effects:

```solidity
LP position loses due to IL
Perps short gains
```

Loss and gain roughly cancel.

Remaining profit source:

```solidity
swap fees
```



### Step 5: Exposure Drift

After many swaps, the pool composition changes.

Hook recomputes:

```solidity
delta = +2 ETH
```

Threshold check:

```solidity
2 < 3
```

No hedge.

Later:

```solidity
delta = -4 ETH
```

Now:

```solidity
|-4| > 3
```

Hook emits a new hedge event.

Automation adjusts position.



# Internal State Machine

We can represent hook behavior as a state machine.

```solidity
        +----------------+
        |  Neutral State |
        +--------+-------+
                 |
         delta > threshold
                 |
                 v
        +----------------+
        | Hedge Trigger  |
        +--------+-------+
                 |
       automation executes hedge
                 |
                 v
        +----------------+
        | Hedged State   |
        +--------+-------+
                 |
        exposure drifts
                 |
                 v
        +----------------+
        | Rebalance      |
        +----------------+
```



# Security Considerations

Key attack vectors.

### 1. Manipulation attack

Trader pushes price to trigger hedge.

Mitigation:

- use TWAP price
- minimum time between hedges



### 2. Hedge griefing

Repeated small swaps trigger hedge spam.

Mitigation:

- hysteresis threshold
- delta bands



### 3. Oracle dependency risk

Avoid external oracles.

Compute exposure purely from pool state.



# Architectural Decision

This design cleanly separates responsibilities.

| Layer               | Responsibility      |
| ------------------- | ------------------- |
| AMM Hook            | Exposure detection  |
| Reactive Automation | Event monitoring    |
| Hedging Engine      | Risk neutralization |

Each layer is composable and replaceable.

That modularity is exactly the philosophy behind **Uniswap v4**.



# Conclusion

This architecture demonstrates:

* AMM microstructure
* derivatives hedging theory
* asynchronous DeFi automation
* cross-protocol composability

It becomes **a programmable risk-managed liquidity primitive**.
