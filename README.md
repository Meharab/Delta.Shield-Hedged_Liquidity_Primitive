# DeltaShield: Hedged Liquidity Primitive

> **Programmable Risk Management for AMMs — Turning LPing into a Market-Neutral Yield Primitive**



**What you're about to see:**

1. A liquidity position becomes **directionally exposed**
2. The system detects risk **on-chain in real-time**
3. A cross-chain automation system triggers a hedge
4. A synthetic derivatives engine neutralizes exposure

**End Result → LP earns fees WITHOUT taking market direction risk**



# Problem: Liquidity Provision is Structurally Broken

Liquidity Providers (LPs) in AMMs like Uniswap are:

```
Implicitly SHORT volatility
```

### Why?

When price moves:

* LP inventory becomes imbalanced
* Value < HODL
* This is **Impermanent Loss (IL)**

### Formal View

Let:

```solidity
Portfolio Value = x(P) + y(P)
```

LP payoff:

```solidity
Convexity < 0  →  Short Gamma
```

- LPs lose during volatility expansion
- LPing becomes speculation, not yield



# Solution: DeltaShield

DeltaShield transforms LPing into:

```
Market-Neutral Yield Strategy
```

### Core Idea

Continuously hedge LP exposure:

```solidity
LP Delta + Hedge Delta ≈ 0
```

So LP earns:

```solidity
Yield = Swap Fees – Hedge Cost
```



# System Architecture (Sensor → Brain → Actuator)

```solidity
        Ethereum (Sepolia)
    ┌────────────────────────┐
    │   AMMHook (Sensor)     │
    │  • Tracks LP delta     │
    │  • Emits risk signal   │
    └──────────┬─────────────┘
               │
               ▼
     Reactive Network (Lasna)
    ┌────────────────────────┐
    │ AutomationController   │
    │  • Decodes event       │
    │  • Applies logic       │
    │  • Dispatches hedge    │
    └──────────┬─────────────┘
               │
               ▼
     Unichain (Sepolia)
    ┌────────────────────────┐
    │ HedgeController        │
    │  • Executes hedge      │
    │  • Updates position    │
    └────────────────────────┘
```



# Core Innovation

## 1. On-Chain Delta Approximation

Instead of heavy computation:

```solidity
Δ ≈ L / 2
```

Where:

* `L = pool liquidity`

This enables:

* Constant-time computation
* Gas-efficient execution inside the hook



## 2. Event-Driven Hedging (No Keepers)

Traditional systems:

```solidity
Bots / Keepers → Fragile + Centralized
```

DeltaShield:

```solidity
Event → Reactive VM → Execution
```

✔ No polling
✔ No cron jobs
✔ Fully autonomous



## 3. Cross-Chain Risk Offloading

* Ethereum → Expensive, state-heavy
* Unichain → Cheap execution layer

**Design Principle:**

- Compute risk where the state lives
- Execute a hedge where the cost is lowest



# End-to-End Flow (Concrete Example)

### Step 1: LP Position Created

* ETH/USDC pool initialized
* LP provides liquidity



### Step 2: Market Moves

```solidity
ETH ↑ → LP accumulates ETH
```

Exposure:

```solidity
Δ > 0 (long ETH)
```



### Step 3: Hook Detects Risk

`AMMHook`:

```solidity
delta ≈ liquidity / 2
```

If:

```solidity
|Δ| > threshold
```

Emit:

```solidity
HedgeRequired(poolId, delta, price, timestamp)
```



### Step 4: Reactive Brain Triggers

`AutomationController`:

* Decodes event
* Checks:

  * Threshold
  * Cooldown

If valid:

```
Dispatch hedge instruction
```



### Step 5: Cross-Chain Hedge

`HedgeController`:

```solidity
executeHedge(poolId, delta)
```

Mock Engine:

```
Open SHORT position of size Δ
```



### Final State

```solidity
LP Delta        = +Δ
Hedge Delta     = -Δ
----------------------
Net Exposure    ≈ 0
```

✔ Impermanent loss neutralized
✔ Fees preserved



# Smart Contract Modules

## AMM Layer

* `AMMHook.sol`
* Exposure tracking
* Event emission

## Automation Layer

* `AutomationController.sol`
* Trigger engine
* Cross-chain dispatcher

## Hedge Layer

* `HedgeController.sol`
* Execution receiver
* Position manager

## Simulation Engine

* `MockPerpsEngine.sol`
* Tracks:

  * Position size
  * Direction
  * PnL



# Testing Strategy

### Unit Tests

* Delta computation
* Threshold logic
* Cooldown enforcement

### Integration Tests

* Event → Reaction → Dispatch

### Testnet Scripts

* Full cross-chain simulation



# Key Engineering Trade-offs

## 1. Delta Approximation

* Gas efficient
* Not perfectly accurate

## 2. No Gamma Modeling

* Simpler MVP
* Less optimal in high volatility

## 3. Mock Perps Engine

* Deterministic demo
* Not real market execution



# Future Roadmap

## 1. Gamma-Aware Hedging

```
Adjust the hedge dynamically with curvature
```

## 2. Real Perp Integrations

* GMX
* Synthetix
* Hyperliquid

## 3. Delta-Neutral Vaults

```solidity
LP + Auto Hedging + Auto Compounding
```



# Impact

DeltaShield introduces a new primitive:

```
"Self-Hedging Liquidity"
```

This enables:

* Institutional LP participation
* Predictable yield strategies
* Reduced systemic risk in AMMs



# Getting Started

```bash
git clone https://github.com/Meharab/Delta.Shield-Hedged_Liquidity_Primitive.git
cd Delta.Shield-Hedged_Liquidity_Primitive
forge build
```

### Run Tests

```bash
forge test
```



# Key Insight

> AMMs solved trading liquidity.
> DeltaShield solves liquidity risk.



# DeltaShield
**From Passive LPing → Active Risk-Managed Yield**
