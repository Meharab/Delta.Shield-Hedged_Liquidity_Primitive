# Reactive Automation Layer

*(Monitoring + Trigger Logic)*

> **protocol-level design document for the Reactive Automation Layer**

## Purpose of the Layer

The Reactive Automation Layer provides **event-driven automation** for the hedged liquidity system.

Its responsibilities:

1. Monitor AMM risk signals emitted by the hook
2. Evaluate hedge trigger conditions
3. Execute hedge transactions automatically
4. Coordinate with the Hedge Controller
5. Prevent redundant or spam hedge executions

This layer ensures that hedging logic is executed **only when meaningful exposure risk appears**.



## Reactive Network Architecture

Reactive Network introduces **Reactive Smart Contracts (RSCs)**.

Unlike normal contracts that execute only when called, RSCs can **listen to events and react to them**.

Conceptually:

```solidity
Event Detection → Conditional Logic → Callback Execution
```

Example workflow:

```solidity
Swap occurs on Uniswap
      ↓
Hook emits RiskSignal
      ↓
Reactive contract detects event
      ↓
Trigger condition evaluated
      ↓
HedgeController.executeHedge()
```

This creates a **fully automated risk management pipeline**.



## Core Components of Reactive Layer

The layer contains three major components.

1. Reactive Monitor
2. Trigger Engine
3. Execution Dispatcher

Architecture:

```solidity
                Uniswap v4 Pool
                        │
                        ▼
                Hook Contract
                        │
                (RiskSignal Event)
                        │
                        ▼
                Reactive Monitor
                        │
                (Trigger Engine)
                        │
                (Execution Dispatcher)
                        │
                        ▼
                Hedge Controller
```



## RiskSignal Event

The hook emits structured risk events after swaps or liquidity changes.

Example event:

```solidity
event RiskSignal(
    bytes32 poolId,
    int24 currentTick,
    uint256 priceX96,
    int256 exposureDelta,
    uint256 liquidity,
    uint256 timestamp
);
```

Meaning of fields:

| Field           | Description               |
| --------------- | ------------------------- |
| `poolId`        | identifier of the v4 pool |
| `currentTick`   | current pool tick         |
| `priceX96`      | sqrt price representation |
| `exposureDelta` | directional LP exposure   |
| `liquidity`     | total pool liquidity      |
| `timestamp`     | block time                |

This event acts as the **data feed for the reactive system**.



## Reactive Monitor

The **Reactive Monitor** is the first contract in the automation layer.

Its job is to subscribe to hook events and forward relevant signals.

Pseudo architecture:

```solidity
Hook Event Listener
        │
        ▼
Reactive Monitor
        │
        ▼
Trigger Engine
```

Example structure:

```solidity
contract ReactiveMonitor {

    address public hook;
    address public triggerEngine;

    function onRiskSignal(
        bytes32 poolId,
        int24 tick,
        uint256 price,
        int256 exposure
    ) external {

        require(msg.sender == hook);

        TriggerEngine(triggerEngine).evaluate(
            poolId,
            tick,
            price,
            exposure
        );
    }
}
```

This contract acts as a **gateway between Uniswap and automation logic**.



## Trigger Engine

The Trigger Engine determines **whether a hedge should be executed**.

It evaluates risk conditions using predefined strategy rules.

Typical conditions:

- price movement threshold
- exposure imbalance
- volatility spike
- liquidity imbalance

Mathematically, the system evaluates **delta exposure risk**.



### Exposure Risk

LP exposure behaves like:

```soilidity
LP Position ≈ Long Token0 + Short Token1
```

When price changes:

```solidity
Exposure ≈ ΔP * Liquidity
```

Where

- `ΔP = price change`
- `L = liquidity`

Risk metric:

```solidity
R = |ExposureDelta|
```

If

```solidity
R > HedgeThreshold
```

Then trigger hedge.



### Example Trigger Formula

```solidity
|price_change| > 2%
AND
|exposure| > threshold
```

Mathematically:

```solidity
|P_now - P_prev| / P_prev > α
```

Where

- `α = volatility threshold`



### Trigger Engine Pseudocode

```solidity
function evaluate(
    bytes32 poolId,
    int24 tick,
    uint256 price,
    int256 exposure
) external {

    uint256 priceChange = calculatePriceChange(poolId, price);

    if(priceChange > volatilityThreshold) {

        if(abs(exposure) > exposureThreshold) {

            dispatchHedge(poolId, exposure);
        }
    }
}
```

---

## Execution Dispatcher

If trigger conditions are satisfied, the Execution Dispatcher calls the Hedge Controller.

Architecture:

```solidity
Trigger Engine
      │
      ▼
Execution Dispatcher
      │
      ▼
Hedge Controller
```

Example:

```solidity
function dispatchHedge(
    bytes32 poolId,
    int256 exposure
) internal {

    HedgeController(controller).executeHedge(
        poolId,
        exposure
    );
}
```



## Cooldown Mechanism

Without safeguards, the system could trigger hedges **too frequently**.

Example scenario:

- rapid swaps
- price oscillations
- hedge spam

Solution: **cooldown logic**.

State variable:

```solidity
mapping(bytes32 => uint256) lastHedgeTime;
```

Trigger rule:

```solidity
block.timestamp - lastHedgeTime > cooldown
```

Example:

```solidity
cooldown = 5 minutes
```

---

## Anti-Manipulation Checks

Since hooks can be triggered by swaps, malicious actors could attempt to **force hedging**.

Protection mechanisms:

### 1. TWAP verification

Compare:

- instant price
- TWAP price

Reject large deviations.



### 2. Oracle confirmation

Compare:

- pool price
- oracle price

Reject inconsistent signals.



### 3. Minimum liquidity filter

Ignore events if:

```solidity
liquidity < minimum
```



## Reactive Smart Contract Deployment

Reactive Network requires **two contracts**.

### 1. Reactive Chain Contract

Runs monitoring logic.

Responsibilities:

1. event detection
2. trigger evaluation
3. cross-chain communication



### 2. Destination Chain Contract

Executes actions on the target chain.

Responsibilities:

1. hedge execution
2. position updates
3. state storage

Architecture:

```solidity
Reactive Chain
      │
      ▼
Trigger Message
      │
      ▼
Destination Chain
      │
      ▼
Hedge Controller
```



## Event Flow Example

Let's walk through a real example.

### Step 1: Large swap

Trader swaps large ETH amount.

```
ETH/USDC pool price drops 5%
```

Hook executes:

```solidity
afterSwap()
```



### Step 2: Risk event emitted

Hook emits:

```solidity
RiskSignal(
poolId,
tick,
price,
exposure
)
```



### Step 3: Reactive monitor detects event

Reactive contract receives event.



### Step 4: Trigger evaluation

Trigger Engine computes:

```solidity
price_change = 5%
exposure = $500k
```

Threshold:

```solidity
volatility_threshold = 3%
```

Condition satisfied.



### Step 5 — Hedge triggered

Reactive dispatcher calls:

```solidity
HedgeController.executeHedge()
```



### Step 6: Hedge executed

Controller opens:

```solidity
short ETH perpetual
```

LP exposure becomes approximately **delta neutral**.



## State Data Stored by Automation Layer

Key stored data:

- `lastPrice`
- `lastHedgeTimestamp`
- `poolExposure`
- `volatilityMetric`

Example struct:

```solidity
struct PoolRiskState {
    uint256 lastPrice;
    int256 exposure;
    uint256 lastHedgeTime;
}
```



## Failure Handling

Automation layers must handle edge cases.

### 1. Hedge execution fails

Solution:

- retry logic
- fallback adapter



### 2. Oracle unavailable

Solution:

- fallback to TWAP



### 3. Repeated triggers

Solution:

- cooldown window



## Security Considerations

Potential attack vectors:

### 1. Hedge griefing

Attackers cause price oscillation to trigger hedges.

Mitigation:

- cooldown
- volatility thresholds
- oracle verification



### 2. Oracle manipulation

Mitigation:

- multi-source price feeds
- TWAP verification



### 3. Gas griefing

Mitigation:

- limit trigger frequency
- batch signals



## Final System Architecture

The complete project now looks like this:

```solidity
                ┌────────────────────┐
                │   Uniswap v4 Pool  │
                └─────────┬──────────┘
                          │
                          ▼
                ┌────────────────────┐
                │      Hook Layer    │
                │ exposure tracking  │
                └─────────┬──────────┘
                          │
                     RiskSignal
                          │
                          ▼
                ┌────────────────────┐
                │ Reactive Monitor   │
                │ Trigger Engine     │
                └─────────┬──────────┘
                          │
                     executeHedge
                          │
                          ▼
                ┌────────────────────┐
                │  Hedge Controller  │
                │ strategy engine    │
                └─────────┬──────────┘
                          │
                          ▼
                ┌────────────────────┐
                │ Derivatives Adapter│
                │   (mock perps)     │
                └────────────────────┘
```



## Conclusion

This system transforms Uniswap pools into:

- autonomous liquidity vaults

with

1. self-monitoring
2. self-hedging
3. self-risk-management

This is the **nervous system** of the protocol.

The AMM layer is the **sensor**.
The Hedging layer is the **actuator**.

The **Reactive Automation Layer** sits between them and behaves like a **control system**.

In control theory terms:

```solidity
System State → Monitor → Trigger Condition → Control Action
```

For this protocol:

```solidity
Uniswap v4 Pool → Reactive Monitor → Risk Trigger → Hedge Execution
```

This layer is extremely important because it ensures:

* **hedges trigger only when necessary**
* **no manual keepers are required**
* **cross-chain / asynchronous automation works**

Without this layer, your system would require **manual keepers**.

With Reactive automation:

- Uniswap pool becomes self-hedging

Liquidity effectively becomes **autonomous capital**.

This aligns with a broader vision emerging in DeFi research:

- Liquidity pools evolving from **passive AMMs → autonomous trading systems**.
