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

### 1. On-Chain Delta Approximation

Instead of heavy computation:

```solidity
Δ ≈ L / 2
```

Where:

* `L = pool liquidity`

This enables:

* Constant-time computation
* Gas-efficient execution inside the hook



### 2. Event-Driven Hedging (No Keepers)

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



### 3. Cross-Chain Risk Offloading

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

### AMM Layer

* `AMMHook.sol`
* Exposure tracking
* Event emission

### Automation Layer

* `AutomationController.sol`
* Trigger engine
* Cross-chain dispatcher

### Hedge Layer

* `HedgeController.sol`
* Execution receiver
* Position manager

### Simulation Engine

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

### 1. Delta Approximation

* Gas efficient
* Not perfectly accurate

### 2. No Gamma Modeling

* Simpler MVP
* Less optimal in high volatility

### 3. Mock Perps Engine

* Deterministic demo
* Not real market execution



# Future Roadmap

### 1. Gamma-Aware Hedging

```
Adjust the hedge dynamically with curvature
```

### 2. Real Perp Integrations

* GMX
* Synthetix
* Hyperliquid

### 3. Delta-Neutral Vaults

```solidity
LP + Auto Hedging + Auto Compounding
```



# Impact

DeltaShield introduces a new primitive:

```bash
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

- AMMs solved trading liquidity.
- DeltaShield solves liquidity risk.

**From Passive LPing → Active Risk-Managed Yield**



# Test Coverage

```bash
╭----------------------------------------+------------------+------------------+----------------+-----------------╮
| File                                   | % Lines          | % Statements     | % Branches     | % Funcs         |
+=================================================================================================================+
| script/AMMHook.s.sol                   | 0.00% (0/11)     | 0.00% (0/11)     | 0.00% (0/2)    | 0.00% (0/2)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/AutomationController.s.sol      | 0.00% (0/5)      | 0.00% (0/4)      | 100.00% (0/0)  | 0.00% (0/2)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/HedgeController.s.sol           | 0.00% (0/14)     | 0.00% (0/19)     | 100.00% (0/0)  | 0.00% (0/2)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/MockPerpsEngine.s.sol           | 0.00% (0/5)      | 0.00% (0/4)      | 100.00% (0/0)  | 0.00% (0/2)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/testnet/DeployAll.s.sol         | 0.00% (0/28)     | 0.00% (0/39)     | 100.00% (0/0)  | 0.00% (0/1)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/testnet/EdgeCaseScenarios.s.sol | 0.00% (0/20)     | 0.00% (0/22)     | 100.00% (0/0)  | 0.00% (0/1)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/testnet/MockTriggerFlow.s.sol   | 0.00% (0/13)     | 0.00% (0/17)     | 100.00% (0/0)  | 0.00% (0/1)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/testnet/SetupSystem.s.sol       | 0.00% (0/15)     | 0.00% (0/21)     | 0.00% (0/2)    | 0.00% (0/1)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/testnet/TriggerHedgeFlow.s.sol  | 0.00% (0/21)     | 0.00% (0/25)     | 100.00% (0/0)  | 0.00% (0/1)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| script/testnet/VerifyEndToEnd.s.sol    | 0.00% (0/14)     | 0.00% (0/19)     | 0.00% (0/6)    | 0.00% (0/1)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| src/AMMHook.sol                        | 98.08% (51/52)   | 96.88% (62/64)   | 66.67% (4/6)   | 100.00% (8/8)   |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| src/AggregatorV3.sol                   | 0.00% (0/9)      | 0.00% (0/8)      | 100.00% (0/0)  | 0.00% (0/3)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| src/AutomationController.sol           | 96.67% (29/30)   | 96.88% (31/32)   | 75.00% (3/4)   | 100.00% (6/6)   |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| src/HedgeController.sol                | 80.70% (46/57)   | 76.92% (50/65)   | 71.43% (10/14) | 81.82% (9/11)   |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| src/MockEventGenerator.sol             | 0.00% (0/2)      | 0.00% (0/1)      | 100.00% (0/0)  | 0.00% (0/1)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| src/MockPerpsEngine.sol                | 98.28% (57/58)   | 91.04% (61/67)   | 57.14% (8/14)  | 100.00% (10/10) |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| test/AutomationController.t.sol        | 0.00% (0/2)      | 0.00% (0/1)      | 100.00% (0/0)  | 0.00% (0/1)     |
|----------------------------------------+------------------+------------------+----------------+-----------------|
| Total                                  | 51.40% (183/356) | 48.69% (204/419) | 52.08% (25/48) | 61.11% (33/54)  |
╰----------------------------------------+------------------+------------------+----------------+-----------------╯
```