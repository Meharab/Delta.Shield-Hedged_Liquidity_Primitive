# Delta-Neutral Adaptive Liquidity Hook
> Autonomous Delta Hedging for Uniswap v4 Liquidity Providers



## Introduction

Automated Market Makers (AMMs) revolutionized market making by replacing traditional order books with deterministic liquidity curves.

However, **liquidity providers (LPs) in AMMs face a fundamental problem: impermanent loss (IL).**

When market prices move, AMM rebalancing forces LPs to **sell assets when prices rise and buy assets when prices fall**, which creates structural losses relative to simple holding.

Professional market makers mitigate this using **hedging strategies in derivatives markets**. But today:

* LPs must manage hedging manually
* Tools are fragmented
* Most LPs do not understand their exposure

This project introduces a **Uniswap v4 Hook that automatically tracks LP exposure and triggers hedging actions**, enabling **delta-neutral liquidity provision**.

The result is a system where LPs can:

* Provide liquidity
* Earn trading fees
* Minimize directional price risk



## Impermanent Loss Theory

Impermanent loss arises because AMMs enforce:

```solidity
x * y = k
```

As prices move:

- pool rebalances

LP effectively:

- sells winners
- buys losers

This is equivalent to being **short volatility**.



## Problem Statement

Liquidity providers in AMMs are **short volatility traders**.

When prices move, LPs experience **impermanent loss** due to the constant rebalancing mechanism.

For example:

```solidity
ETH price = $2000
LP deposits ETH + USDC
```

If ETH doubles:

```solidity
ETH = $4000
```

The AMM sells ETH as the price rises.

LP ends with:

- less ETH
- more USDC

Compared to simply holding ETH, the LP underperforms.

This is **impermanent loss**.

Key issues:

### 1. LP exposure is hidden

LPs do not know their **real-time delta exposure**.

### 2. Hedging is complex

To hedge risk, LPs must:

* calculate exposure
* open derivative positions
* rebalance frequently

This is impractical for most users.

### 3. No automated system exists

Even advanced DeFi users rely on **manual strategies or off-chain bots**.

There is no **native AMM-level hedging mechanism**.



## Solution

This project introduces a **Uniswap v4 Hook that tracks LP exposure and enables automated hedging.**

The system continuously:

1. Track LP exposure
2. Compute delta risk
3. Trigger hedge execution
4. Maintain a neutral position

The architecture contains **three layers**.

```solidity
+------------------------------------+
|  AMM Layer (Uniswap v4 Hook)       |
|  (exposure tracking)               |
+------------------------------------+
                ↓
+------------------------------------+
|  Reactive Automation Layer         |
|  (monitoring + hedge triggers)     |
+------------------------------------+
                ↓
+------------------------------------+
|  Hedging Execution Layer           |
|  (derivatives / synthetic hedge)   |
+------------------------------------+
```

This creates **autonomous LP risk management**.



## Implementation Stack

Smart contracts:

- Solidity
- Uniswap v4 Hooks
- Foundry

Automation:

- Reactive Network

Deployment:

- Unichain



## System Architecture

The protocol contains three core layers:

### 1. AMM Layer

Responsible for:

* LP exposure tracking
* pool monitoring
* delta calculation

Implemented using **Uniswap v4 Hooks**.

### 2. Reactive Automation Layer

Responsible for:

* monitoring exposure
* triggering hedges
* scheduling rebalances

Built using **Reactive Network automation**.

### 3. Hedging Execution Layer

Responsible for:

* executing hedge positions
* interacting with derivatives protocols
* managing hedge lifecycle

Implemented via a **Hedge Controller contract**.



## 1. AMM Layer (v4 Hooks)

Hooks allow custom logic during pool events.

This project implements exposure tracking using:

```solidity
afterInitialize()
afterModifyPosition()
afterSwap()
```


### 1.1 Hook Design

The hook tracks LP exposure by observing:

- liquidity
- price
- tick ranges

#### Exposure State

For each LP:

```solidity
struct PositionExposure {
    uint128 liquidity;
    int24 tickLower;
    int24 tickUpper;
}
```


### 1.2 Liquidity Mathematics

Uniswap v3/v4 liquidity math:

```solidity
x = L (1/√P − 1/√Pb)
y = L (√P − √Pa)
```

Where:

```solidity
L = liquidity
P = current price
Pa = lower price
Pb = upper price
```

### 1.3 LP Delta Exposure

LP delta is the sensitivity of portfolio value to price.

```solidity
Δ = ∂V / ∂P
```

For AMM positions:

```solidity
Δ = x
```

Where `x` is the token0 inventory.

Example:

```solidity
ETH/USDC pool
LP holds 5 ETH equivalent
```

Delta exposure:

```solidity
Δ = +5 ETH
```

To hedge:

```solidity
short 5 ETH
```


### 1.4 Exposure Tracking Logic

Whenever a swap occurs:

```solidity
afterSwap()
```

The hook:

1. fetches the current price
2. computes LP exposure
3. stores the delta state
4. emits exposure update event

Example event:

```solidity
ExposureUpdated(
    poolId,
    lpAddress,
    delta,
    price
)
```

This event feeds the **automation layer**.


### 1.5 Hook Flags

The hook enables the following flags:

```solidity
AFTER_INITIALIZE_FLAG
AFTER_MODIFY_POSITION_FLAG
AFTER_SWAP_FLAG
```

Purpose:

1. afterInitialize → track pool setup
2. afterModifyPosition → update LP exposure
3. afterSwap → update price + delta


### 1.6 Return Delta

Hooks return:

- BalanceDelta

In this implementation:

```solidity
return ZERO_DELTA
```

Because the hook **observes the state but does not modify swap execution**.



## 2. Reactive Automation Layer

The automation layer continuously monitors LP exposure.

Implemented using **Reactive Network**.

Responsibilities:

- monitor exposure
- detect risk thresholds
- trigger hedging


### 2.1 Trigger Logic

Automation triggers hedge actions when:

```solidity
|delta exposure| > threshold
```

Example:

```solidity
delta = +4.5 ETH
threshold = 2 ETH
```

Automation triggers:

- hedge execution


### 2.2 Automation Workflow

```solidity
Hook emits the ExposureUpdated event
        ↓
Reactive Network listens
        ↓
Risk evaluation
        ↓
Trigger hedge
        ↓
Call HedgeController
```

This creates **fully autonomous hedging**.



## 3. Hedging Execution Layer

The hedge layer opens positions in derivatives markets.

In the hackathon MVP, I implement:

- Synthetic hedge contract

Instead of integrating complex derivatives protocols.


### 3.1 Hedge Controller

The main execution contract.

Responsibilities:

1. open hedge
2. close hedge
3. rebalance hedge
4. track hedge state

Example structure:

```solidity
struct HedgePosition {
    int256 size;
    uint256 entryPrice;
}
```


### 3.2 Hedge Strategy

If LP delta is positive:

- LP long asset

Then hedge:

- short asset

If LP delta is negative:

- LP short asset

Then hedge:

- long asset


### 3.3 Example Hedge

```solidity
LP exposure = +5 ETH
ETH price = $2000
```

Hedge:

- open short 5 ETH

Result:

- delta neutral


### 3.4 Dynamic Rebalancing

As prices move:

- LP delta changes

Example:

- Price rises
- LP sells ETH
- delta decreases

Automation triggers:

- hedge rebalance



## Testing

All logic is validated with **Foundry tests**.

Tests simulate:

1. liquidity deposits
2. price movement
3. delta changes
4. hedge triggers

This ensures the system behaves correctly under different scenarios.



## MVP Design Choice

The hackathon implementation includes:

- delta hedging

but excludes:

- gamma hedging
- volatility modeling

These are reserved for **future work**.



## Future Scope (Long-Term Vision)

This system opens the door to advanced research.

Future upgrades include:


### i. Gamma Hedging

Model LP gamma exposure.

```solidity
Γ = -L / (2P^(3/2))
```

Enable dynamic hedging strategies.

LP positions have **negative gamma**.

```solidity
Γ = ∂²V / ∂P²
```

Meaning:

- LP loses when volatility increases

This is why **impermanent loss accelerates during volatility**.


### ii. Volatility Estimation

Estimate market volatility.

Adapt hedge frequency accordingly.


### iii. Derivatives Integration

Integrate real protocols:

- perpetual futures
- options
- structured vaults

### iv. LP Vaults

Create automated vaults that provide:

- delta-neutral liquidity
- automated rebalancing
- risk optimization



## Conclusion

Delta-Neutral Adaptive Liquidity Hook introduces a new primitive for DeFi:

- automated LP hedging

This project moves AMMs toward a new paradigm:

- autonomous liquidity management

Where LPs no longer manually manage risk.

Instead:

- liquidity → algorithmically hedged

By combining:

1. Uniswap v4 hooks
2. Automation infrastructure
3. Derivatives hedging

The system allows LPs to:

1. Earn fees
2. Minimize risk
3. Participate in advanced strategies

This architecture lays the foundation for **fully autonomous liquidity provision in decentralized markets**. 

This transforms AMMs from passive liquidity pools into **intelligent market-making systems**.
