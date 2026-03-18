# Purpose
> DeltaShield Reactive Automation Interface Specification

This document defines the **interface and functional specification** for the **Reactive Automation Layer** used in the DeltaShield protocol.

The automation layer is responsible for:

* monitoring risk signals emitted by the AMM hook
* evaluating hedge trigger conditions
* dispatching hedge execution messages
* preventing redundant or malicious hedge triggers
* coordinating cross-chain execution via Reactive Network

This specification defines the **minimum contract interface, state model, and event flow** required for compliant automation implementations.



# Role of the Automation Layer

Within the DeltaShield system architecture, the automation layer acts as the **control system** between the AMM risk sensor and the hedge execution engine.

System architecture:

```solidity
        Uniswap v4 Pool
              │
              ▼
        AMMHook (sensor)
              │
       HedgeRequired Event
              │
              ▼
     Reactive Automation Layer
              │
              ▼
        Hedge Controller
              │
              ▼
      Derivatives Execution
```

The automation layer performs three primary functions:

1. **Event Monitoring**
2. **Risk Evaluation**
3. **Execution Dispatching**



# Event Inputs

The automation system listens for **risk signals emitted by the AMM hook**.

Current hook event definition:

```solidity
event HedgeRequired(
    PoolId indexed poolId,
    int256 delta,
    uint160 sqrtPriceX96,
    uint256 timestamp
);
```

### Event Field Definitions

| Field          | Type    | Meaning                                  |
| -------------- | ------- | ---------------------------------------- |
| `poolId`       | PoolId  | unique identifier of the Uniswap v4 pool |
| `delta`        | int256  | estimated LP directional exposure        |
| `sqrtPriceX96` | uint160 | pool price in Q96 format                 |
| `timestamp`    | uint256 | time risk signal was generated           |

This event represents a **candidate hedge trigger**.

The automation layer **must independently verify trigger conditions** before executing hedges.



# Reactive Event Interface

The automation layer must implement the **Reactive Network event callback interface**.

### 1. Required Function

```solidity
function react(LogRecord calldata log) external;
```

### 2. Purpose

The `react()` function is invoked automatically by the **Reactive Network System Contract** when a subscribed event occurs.

### 3. Input

`LogRecord` contains the raw event log emitted by the hook.

Typical fields include:

```solidity
struct LogRecord {
    uint256 chainId;
    address emitter;
    bytes32 topic0;
    bytes32 topic1;
    bytes32 topic2;
    bytes32 topic3;
    bytes data;
}
```

The automation controller must decode the event payload and extract:

* poolId
* delta
* sqrtPrice
* timestamp



# Core Automation Functions

The automation layer must expose the following functional modules.



### 1. Event Processing

Processes incoming hook signals.

```solidity
function processRiskSignal(
    PoolId poolId,
    int256 delta,
    uint160 sqrtPriceX96,
    uint256 timestamp
) internal;
```

Responsibilities:

* decode event
* update internal state
* forward to trigger evaluation



### 2. Trigger Evaluation

Determines whether a hedge should be executed.

```solidity
function evaluateTrigger(
    PoolId poolId,
    int256 delta,
    uint160 price
) internal returns (bool shouldHedge);
```

Typical evaluation criteria:

```solidity
|delta| > deltaThreshold
AND
priceDeviation > volatilityThreshold
AND
cooldownSatisfied
```

Mathematically:

```solidity
|Δ| > Δ_threshold
```

and

```solidity
|P_now − P_prev| / P_prev > α
```

Where:

```solidity
α = volatility threshold
```



### 3. Cooldown Verification

Ensures hedges are not triggered too frequently.

```solidity
function cooldownSatisfied(
    PoolId poolId
) internal view returns (bool);
```

Condition:

```solidity
block.timestamp - lastHedgeTimestamp > cooldownPeriod
```

This protects against:

* rapid swaps
* price oscillation attacks
* hedge spam



### 4. Hedge Dispatch

If the trigger is satisfied, the automation layer must dispatch execution.

```solidity
function dispatchHedge(
    PoolId poolId,
    int256 delta
) internal;
```

This function sends a **cross-chain callback message** to the Hedge Controller.

Reactive Network callback example:

```solidity
emit Callback(
    destinationChainId,
    callbackContract,
    gasLimit,
    payload
);
```

Payload example:

```solidity
executeHedge(poolId, delta)
```



# Required State Variables

The automation layer must maintain risk tracking state for each pool.

### Pool Risk State

```solidity
struct PoolRiskState {
    uint160 lastPrice;
    int256 lastDelta;
    uint256 lastHedgeTimestamp;
}
```

Storage mapping:

```solidity
mapping(bytes32 => PoolRiskState) public poolRiskStates;
```

This state allows the system to compute:

* price change
* exposure change
* cooldown checks



# Configuration Parameters

Automation parameters must be configurable.

```solidity
uint256 public deltaThreshold;
uint256 public volatilityThreshold;
uint256 public cooldownPeriod;
uint256 public minLiquidity;
```

Typical defaults:

```solidity
deltaThreshold = 1e18
volatilityThreshold = 2%
cooldownPeriod = 5 minutes
minLiquidity = 1e6
```

These parameters determine **how sensitive the system is to risk signals**.



# Cross-Chain Execution Interface

The automation layer must support **cross-chain hedge execution**.

Required variables:

```solidity
uint256 public originChainId;
uint256 public destinationChainId;
address public callbackContract;
```

Cross-chain message format:

```solidity
payload = abi.encodeWithSignature(
    "executeHedge(bytes32,int256)",
    poolId,
    delta
);
```

The callback contract must implement:

```solidity
function executeHedge(
    bytes32 poolId,
    int256 delta
) external;
```



# Security Requirements

Automation implementations must include protection mechanisms against manipulation.



### 1. Liquidity Filter

Ignore signals if pool liquidity is too small.

Condition:

```solidity
liquidity > MIN_LIQUIDITY
```

Low-liquidity pools are vulnerable to price manipulation.



### 2. Oracle Verification

Verify pool price against trusted oracle.

```solidity
|poolPrice - oraclePrice| < deviationLimit
```

Reject signals outside the range.



### 3. TWAP Validation

Compare instantaneous price against TWAP.

Reject signals if deviation is excessive.



# Failure Handling

Automation systems must tolerate execution failures.

### 1. Hedge Failure

If hedge execution fails:

- retry after retryDelay

Or route to fallback adapter.



### 2. Oracle Failure

Fallback logic:

- `oracle → TWAP → last valid price`



### 3. Message Delivery Failure

If cross-chain message fails:

- queue retry



# Event Outputs

Automation contracts should emit diagnostic events.

### 1. Trigger Evaluation Event

```solidity
event TriggerEvaluated(
    bytes32 poolId,
    int256 delta,
    bool shouldHedge
);
```

### 2. Hedge Dispatch Event

```solidity
event HedgeDispatched(
    bytes32 poolId,
    int256 delta,
    uint256 timestamp
);
```

These events enable:

* observability
* analytics
* monitoring dashboards



# Integration with AMMHook

The automation layer must subscribe to the hook event topic.

Event signature:

```solidity
HedgeRequired(PoolId,int256,uint160,uint256)
```

Topic0:

```solidity
keccak256(
"HedgeRequired(bytes32,int256,uint160,uint256)"
)
```

Reactive subscription example:

```solidity
service.subscribe(
    originChainId,
    hookAddress,
    topic0,
    REACTIVE_IGNORE,
    REACTIVE_IGNORE,
    REACTIVE_IGNORE
);
```



# Minimal Automation Flow

Full automation lifecycle:

```solidity
Swap occurs
     │
     ▼
Hook computes exposure
     │
     ▼
HedgeRequired emitted
     │
     ▼
Reactive contract receives event
     │
     ▼
Trigger evaluation
     │
     ▼
Cooldown check
     │
     ▼
Hedge dispatch
     │
     ▼
HedgeController.executeHedge()
```



# Interface Compliance

Any automation implementation is considered **DeltaShield-compliant** if it:

1. Subscribes to hook risk events
2. Implements `react(LogRecord)`
3. Evaluates hedge triggers
4. enforces cooldown protection
5. dispatches hedge execution callbacks
6. maintains per-pool risk state



# Design Philosophy

The automation layer follows a **control systems architecture**.

Conceptually:

```solidity
System State → Monitor → Trigger → Control Action
```

For DeltaShield:

```solidity
AMM State → Automation Monitor → Hedge Trigger → Derivatives Execution
```

This transforms liquidity pools into **autonomous hedged capital systems**.

Instead of passive LP exposure, the system creates **self-adjusting liquidity positions**.



# Final Note

`AutomationInterface.md` acts as the **formal contract specification** between:

* the AMM layer
* the automation layer
* the hedge execution layer

Any future implementation, keeper networks, off-chain agents, or alternative automation frameworks, can integrate with DeltaShield by implementing this interface.