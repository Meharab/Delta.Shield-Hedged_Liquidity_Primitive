# Purpose

> DeltaShield Reactive Automation Architecture

This document defines the **implementation architecture** of the Reactive Automation Layer for the DeltaShield protocol.

It expands the conceptual automation design into **concrete Solidity components**, responsibilities, data flow, and module boundaries.

The architecture is designed for:

* deterministic execution
* cross-chain automation
* safety against manipulation
* modular extensibility
* compatibility with **Reactive Network**



# System Role

Within the overall protocol, the automation layer performs the following function:

```solidity
AMM Risk Signal
       │
       ▼
Reactive Automation
       │
       ▼
Hedge Controller
       │
       ▼
Derivatives Execution
```

This layer acts as the **control system** that decides **when and how hedges occur**.

Without this layer the system would require **manual keepers**.



# Reactive Contract Architecture

The automation system is implemented primarily in the **AutomationController** contract.

Internally it is composed of four logical modules.

```solidity
AutomationController
    ├── EventDecoder
    ├── TriggerEngine
    ├── CooldownManager
    ├── CrossChainDispatcher
```

These modules may be implemented either:

* **inside a single contract**
* or as **separate internal libraries**

The design goal is **logical separation without unnecessary gas overhead**.



# Core Contract

### AutomationController

Primary automation contract deployed on the **Reactive Network chain**.

Responsibilities:

* subscribe to hook events
* decode emitted signals
* evaluate hedge conditions
* dispatch cross-chain hedge execution

Minimal structure:

```solidity
contract AutomationController is IReactive, AbstractReactive {

    function react(LogRecord calldata log) external vmOnly {

        RiskSignal memory signal = EventDecoder.decode(log);

        if(TriggerEngine.evaluate(signal)) {

            if(CooldownManager.allowed(signal.poolId)) {

                CrossChainDispatcher.dispatch(signal);
            }
        }
    }

}
```



# Module Specifications

## 1. Event Decoder

### Responsibility

Decode raw Reactive Network logs into structured protocol signals.

The Reactive Network provides event data through:

- `LogRecord`

which contains encoded event data.

The decoder reconstructs the **HedgeRequired event fields**.



### Input

```solidity
LogRecord log
```



### Output

```solidity
RiskSignal struct
```



### Data Structure

```solidity
struct RiskSignal {
    bytes32 poolId;
    int256 delta;
    uint160 sqrtPriceX96;
    uint256 timestamp;
}
```



### Decoder Logic

```solidity
decode(log.data)
```

Extract:

- `poolId`
- `delta`
- `sqrtPriceX96`
- `timestamp`

Implementation concept:

```solidity
function decode(
    LogRecord calldata log
) internal pure returns (RiskSignal memory)
```



## 2. Trigger Engine

### Responsibility

Evaluate whether a **hedge should be triggered**.

The trigger engine performs:

* exposure threshold checks
* price volatility checks
* liquidity validation



### Core Trigger Formula

```solidity
|Δ| > Δ_threshold
```

where

```solidity
Δ = LP delta exposure
```

Optional volatility condition:

```solidity
|P_now − P_prev| / P_prev > α
```



### Function

```solidity
function evaluate(
    RiskSignal memory signal
) internal returns (bool)
```



### Evaluation Pipeline

```solidity
Check Liquidity
      │
Check Delta Threshold
      │
Check Price Volatility
      │
Check Oracle Validation
      │
Return Decision
```



## 3. Cooldown Manager

### Purpose

Prevent repeated hedge triggers within short time windows.

This protects against:

* price oscillation attacks
* swap spam
* hedge griefing



### State Storage

```solidity
mapping(bytes32 => uint256) lastHedgeTimestamp
```



### Rule

```solidity
block.timestamp - lastHedgeTimestamp > cooldownPeriod
```



### Function

```solidity
function allowed(bytes32 poolId)
```

Returns:

- true if cooldown satisfied



### Update Logic

When hedge dispatch occurs:

```solidity
lastHedgeTimestamp[poolId] = block.timestamp
```



## 4. CrossChain Dispatcher

### Responsibility

Send hedge execution messages to the **destination chain**.

Reactive Network supports cross-chain execution using:

```solidity
emit Callback(...)
```



### Required Data

- `destinationChainId`
- `callbackContract`
- `gasLimit`



### Dispatch Function

```solidity
function dispatch(
    RiskSignal memory signal
)
```

Payload example:

```solidity
executeHedge(poolId, delta)
```



### Message Example

```solidity
emit Callback(
    destinationChainId,
    hedgeController,
    gasLimit,
    payload
)
```



# Data Flow

Full automation pipeline:

```solidity
Swap occurs
     │
     ▼
AMMHook.afterSwap()
     │
     ▼
HedgeRequired event
     │
     ▼
Reactive Network event subscription
     │
     ▼
AutomationController.react()
     │
     ▼
EventDecoder.decode()
     │
     ▼
TriggerEngine.evaluate()
     │
     ▼
CooldownManager.allowed()
     │
     ▼
CrossChainDispatcher.dispatch()
     │
     ▼
Destination Chain HedgeController
```



# State Variables

The controller must maintain minimal state.

```solidity
mapping(bytes32 => PoolRiskState) poolState
```



### PoolRiskState

```solidity
struct PoolRiskState {

    uint160 lastPrice;
    int256 lastDelta;
    uint256 lastHedgeTimestamp;

}
```



# Configurable Parameters

These values must be configurable.

- `deltaThreshold`
- `volatilityThreshold`
- `cooldownPeriod`
- `minLiquidity`

Recommended defaults:

- `deltaThreshold = 1e18`
- `cooldownPeriod = 60 seconds`
- `volatilityThreshold = 3%`



# Security Design

Automation systems are vulnerable to manipulation if not carefully designed.

### 1. Price Manipulation

Mitigation:

- TWAP comparison



### 2. Liquidity Manipulation

Ignore events if:

```solidity
liquidity < minimum
```



### 3. Hedge Griefing

Mitigation:

- cooldown
- volatility threshold
- oracle validation



# Deployment Model

Reactive Network requires two deployments.

### Origin Chain

- Uniswap v4 Hook

### Reactive Chain

- AutomationController

### Destination Chain

- HedgeController

Architecture:

```solidity
Origin Chain
   │
Hook Event
   │
Reactive Chain
   │
Automation Controller
   │
Cross-chain message
   │
Destination Chain
   │
Hedge Controller
```



# Extensibility

Future improvements may include:

* dynamic hedge sizing
* volatility-based thresholds
* multi-pool monitoring
* risk aggregation across pools
* portfolio-level hedging