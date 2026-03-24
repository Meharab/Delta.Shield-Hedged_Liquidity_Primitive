> # 📄 DeltaShield: MVP Handover Documentation (For Next Stage)



## 🧠 Project Overview

### Project Name

**DeltaShield: Hedge Liquidity Primitive (Autonomous Delta-Neutral Liquidity)**

### Core Idea

DeltaShield is a **cross-chain, event-driven hedging system** that transforms AMM liquidity provision into a:

```text
Market-neutral yield strategy
```

By continuously offsetting LP delta exposure via derivatives.



## ⚠️ Problem Definition (Formal)

In AMMs (e.g., Uniswap v2/v3/v4):

* LPs are **short volatility**
* Experience **Impermanent Loss (IL)**

### Mathematical Form

Let price = `P`

LP portfolio:

```math
\huge V(P) = x(P) + y(P)
```

LP payoff curvature:

```math
\huge d²V/dP² < 0  → Short Gamma
```

Result:

* Profit when price is stable
* Loss when price moves significantly



## 💡 MVP Solution Summary

DeltaShield introduces:

```math
\huge Δ_LP + Δ_Hedge ≈ 0
```

Where:

* `Δ_LP` = LP exposure
* `Δ_Hedge` = derivative hedge



## 🏗️ System Architecture (3-Layer Design)



### 1. AMM Layer (Execution + Exposure Tracking)

* Runs on: **Ethereum Sepolia**
* Component: `AMMHook.sol`
* Technology: Uniswap v4 Hook

#### Responsibilities:

* Observe swaps + liquidity changes
* Estimate LP delta:

```math
\huge Δ ≈ L / 2
```

* Emit:

```solidity
event HedgeRequired(...)
```



### 2. Reactive Automation Layer (Monitoring + Trigger Logic)

* Runs on: **Reactive Network (Lasna)**
* Component: `AutomationController.sol`

#### Responsibilities:

* Subscribe to AMM events
* Decode event logs
* Apply:

  * Threshold logic
  * Cooldown logic
* Dispatch cross-chain callback



### 3. Hedge Execution Layer (Derivatives Engine)

* Runs on: **Unichain Sepolia**
* Components:

  * `HedgeController.sol`
  * `MockPerpsEngine.sol`

#### Responsibilities:

* Receive callback
* Execute hedge:

```solidity
executeHedge(poolId, delta)
```

* Simulate:

  * Position tracking
  * PnL



## 🔁 End-to-End Workflow

```text
Swap / Liquidity Change
        ↓
AMMHook computes Δ
        ↓
Emit HedgeRequired
        ↓
AutomationController.react()
        ↓
Trigger evaluation
        ↓
Dispatch cross-chain callback
        ↓
HedgeController.executeHedge()
        ↓
MockPerpsEngine updates position
```



## 📦 Smart Contract Modules

### 1. AMM Layer

* `AMMHook.sol`

  * Hook-based observer
  * Tracks:

    * sqrtPriceX96
    * liquidity
    * delta
  * Emits:

    * `ExposureUpdated`
    * `HedgeRequired`



### 2. Automation Layer

* `AutomationController.sol`

  * Implements Reactive Network interface
  * Core modules:

    1. Event Decoder
    2. Trigger Engine
    3. Cooldown Manager
    4. Dispatcher



### 3. Hedge Layer

* `HedgeController.sol`

  * Callback receiver
  * Executes hedge

* `MockPerpsEngine.sol`

  * Simulates:

    * Long/short positions
    * Exposure tracking
    * PnL



## 🔬 Key Mathematical Model (MVP)

### Simplified Delta Approximation

```math
\huge Δ ≈ L / 2
```

### Why this works:

* Avoids full concentrated liquidity integration
* Constant-time computation
* Gas-efficient

### Limitations:

* Ignores:

  * Tick range
  * Price curvature
  * Gamma



## ⚙️ Key Design Decisions

### 1. Event-Driven Architecture

* No keepers
* No bots
* Fully reactive (onchain)

### 2. Cross-Chain Separation

| Layer      | Chain            |
| ---------- | ---------------- |
| AMM        | Ethereum Sepolia |
| Automation | Reactive Network |
| Hedge      | Unichain Sepolia |

### 3. Observer Hook Design

* Hook does NOT:

  * Modify swaps
  * Transfer tokens
* Only emits signals



## 🧪 Testing Strategy (MVP)

### Local Tests

* Unit tests per layer:

  * `AMMHook.t.sol`
  * `AutomationController.t.sol`
  * `HedgeController.t.sol`
  * `MockPerpsEngine.t.sol`

### Testnet Simulation

* Cross-chain scripts:

  * Deploy contracts across 3 chains
  * Emit events manually (`MockEventGenerator.sol`)
  * Observe:

    * Reaction
    * Callback
    * Execution



## ⚠️ Known Limitations (Intentional)

### 1. No Gamma Modeling

* Delta-only hedge
* Not optimal in high volatility

### 2. Mock Perps Engine

* No real market execution

### 3. Approximate Delta

* Not precise for:

  * Narrow ranges
  * Extreme price moves

### 4. No Capital Efficiency Optimization

* Hedge size = full offset
* No partial hedging strategies



## 🔐 Security Considerations

* Event spoofing protection:

```solidity
if (log._contract != originHookAddress) revert;
```

* Cooldown enforcement:

```solidity
lastHedgeTimestamp
```

* No fund custody in hook



## 🚀 Current State (Completed)

- ✅ All 3 layers implemented
- ✅ Unit tests written
- ✅ Cross-chain deployment scripts created
- ✅ Testnet simulation possible
- ✅ README + demo ready



## 🔮 Next Stage Goals (IMPORTANT)

This is where the next conversation should start.

### A. Mathematical Upgrade

* Exact delta for concentrated liquidity:

```math
\Huge Δ = ∂V/∂P
```

### B. Gamma Modeling

* Understand:

```math
\Huge Γ = ∂²V/∂P²
```

* Dynamic hedging strategies



### C. Real Derivatives Integration

Replace:

```text
MockPerpsEngine
```

With:

* GMX
* Synthetix
* Hyperliquid



### D. Strategy Engine

* Partial hedging
* Volatility-aware hedge sizing
* Cost optimization



### E. Vault Layer

* Turn into:

```text
Delta-Neutral LP Vault
```



### F. Risk Engine Upgrade

* Multi-pool netting
* Portfolio-level hedging



## 🧭 Open Questions for Next Stage

1. What is the **exact delta formula** for v4 concentrated liquidity?
2. How to model **gamma exposure dynamically**?
3. What is the **optimal hedge frequency vs cost trade-off**?
4. Should hedging be:

   * Continuous?
   * Discrete?
   * Event + volatility hybrid?



## 📌 Instructions for Next Stage

Start with:

```text
We have completed the MVP of DeltaShield (cross-chain delta hedging system).

Now we want to move to the next stage:
→ improving the mathematical model and hedge strategy.

Here is the full system context:
[paste this document]
```



## 🧠 Final Insight

This MVP establishes:

```text
DeltaShield = Infrastructure Layer
```

Next stage builds:

```text
DeltaShield = Financial Primitive
```