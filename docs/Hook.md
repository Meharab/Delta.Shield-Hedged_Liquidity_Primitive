# AMM Layer Architecture

*(Execution + Exposure Tracking)*

> **protocol-level design document for the AMM Layer**



## Purpose of the AMM Layer

The AMM layer performs three responsibilities:

**1. Observe pool state changes:** Triggered during swaps or liquidity updates.

**2. Estimate directional exposure:** Compute **LP delta** from current pool state.

**3. Emit hedge signals:** When exposure exceeds tolerance.

This layer **never performs the hedge itself**.
It only detects and signals risk.



## Requirement of Hooks

The system requires **direct access to pool lifecycle events**.

In **Uniswap v4**, hooks can intercept:

* swaps
* liquidity updates
* fee changes
* pool initialization

This allows **real-time risk monitoring**.

Without hooks, exposure estimation would require off-chain monitoring.

Hooks provide:

- synchronous state access
- atomic event emission
- per-pool state storage



## Core Components of the AMM Layer

The AMM layer contains four components.

```solidity
DeltaShield Hook Contract
│
├─ Pool State Reader
├─ Exposure Calculator
├─ Risk Threshold Engine
└─ Hedge Signal Emitter
```

Each component runs inside a single hook contract.



## Hook Contract Structure

The hook is deployed as a **singleton contract** attached to pools.

Example structure:

```solidity
DeltaShieldHook.sol
│
├─ Pool State Storage
├─ Exposure Math Library
├─ Risk Engine
├─ Event System
└─ Hook Entry Points
```



## Hook Permissions (Hook Flags)

Hooks in **Uniswap v4** use **bit flags** to declare which lifecycle events they intercept.

DeltaShield requires:

```solidity
BEFORE_SWAP_FLAG
AFTER_SWAP_FLAG
AFTER_MODIFY_POSITION_FLAG
AFTER_INITIALIZE_FLAG
```

Why each is needed:

| Flag                | Purpose                                           |
| ------------------- | ------------------------------------------------- |
| afterInitialize     | store initial price reference                     |
| afterSwap           | recompute delta after every trade                 |
| afterModifyPosition | recompute exposure when LP adds/removes liquidity |
| beforeSwap          | optional safety checks                            |

Minimal safe configuration:

1. `AFTER_SWAP_FLAG`
2. `AFTER_MODIFY_POSITION_FLAG`
3. `AFTER_INITIALIZE_FLAG`



## Pool State Storage

The hook must store state **per pool**.

Example struct:

```solidity
struct PoolState {
    uint160 lastSqrtPriceX96;
    int256 lastDelta;
    uint256 lastHedgeTimestamp;
    uint256 deltaThreshold;
    uint256 minRebalanceInterval;
}
```

Mapping:

```solidity
mapping(bytes32 => PoolState) public poolState;
```

Pool identifier:

```solidity
poolId = keccak(poolKey)
```



## Mathematical Model for Exposure

Now the interesting physics.

LP exposure comes from AMM inventory.

Let

- x = token0 reserves
- y = token1 reserves
- P = price of token0 in token1

Constant product invariant:

```solidity
x * y = k
```

Pool value:

```solidity
V = xP + y
```

LP exposure:

```solidity
Δ = dV/dP
```

Compute derivative:

```solidity
V = xP + k/x
```

Derivative:

```solidity
dV/dP = x + P * dx/dP
```

But from invariant:

```solidity
x = sqrt(k / P)
```

Therefore:

```solidity
Δ ≈ V / (2P)
```

This is the **approximate LP delta**.

This result appears in AMM research literature.

**Interpretation:**

LP behaves like **holding half its value in the base asset**.



## Practical Delta Calculation

We avoid expensive math.

Inputs available from pool:

1. `sqrtPriceX96`
2. `liquidity`

Price conversion:

```solidity
P = (sqrtPriceX96^2) / 2^192
```

Liquidity value approximation:

```solidity
V ≈ liquidity * P
```

Then delta:

```solidity
delta ≈ V / (2P)
```

Simplifies to:

```solidity
delta ≈ liquidity / 2
```

This approximation works well when LP positions are near the active range.



## Exposure Calculation Module

Implementation flow:

```solidity
function computeDelta(poolKey) returns int256
```

Steps:

1. read pool price
2. compute liquidity value
3. estimate delta
4. return exposure

Pseudo code:

```solidity
price = getPoolPrice(poolKey)

liquidity = getPoolLiquidity(poolKey)

value = liquidity * price

delta = value / (2 * price)

return delta
```



## Risk Threshold Engine

The hook decides whether the risk is too large.

Two parameters:

1. `deltaThreshold`
2. `minRebalanceInterval`

Logic:

```solidity
if abs(delta) > deltaThreshold
   AND
   block.timestamp > lastHedgeTimestamp + interval
```

Then emit a hedge signal.



## Hook Entry Points

### i. `afterInitialize()`

Runs when the pool is created.

Purpose:

- initialize pool state
- set thresholds

Pseudo logic:

```solidity
state.lastPrice = sqrtPriceX96
state.deltaThreshold = default
state.minRebalanceInterval = default
```

### ii. `afterModifyPosition()`

Triggered when LP changes liquidity.

Actions:

1. recompute exposure
2. update stored delta

Pseudo code:

```solidity
delta = computeDelta(poolKey)

state.lastDelta = delta
```


### iii. `afterSwap()`

This is the main trigger.

Workflow:

```solidity
swap occurs
↓
hook executes
↓
read new pool price
↓
compute delta
↓
evaluate threshold
↓
emit hedge signal
```

Pseudo code:

```solidity
function afterSwap(...) {

   delta = computeDelta(poolKey)

   if shouldHedge(delta):

       emit HedgeRequired(
           poolKey,
           delta,
           price
       )

   state.lastDelta = delta
}
```



## Hedge Signal Event

This event informs the automation layer.

Example:

```solidity
event HedgeRequired(
    bytes32 poolId,
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
    $2100,
    block.timestamp
)
```



## Hook Return Delta

Hooks in **Uniswap v4** can optionally return **balance deltas**.

This feature allows hooks to modify token flows.

DeltaShield **does not modify swap output**.

Therefore:

```solidity
return BalanceDelta(0,0)
```

The hook behaves as **observer + signal emitter**.

This is safer and gas-efficient.



## State Update Flow

State transitions:

```solidity
swap happens
↓
afterSwap()
↓
compute delta
↓
compare threshold
↓
emit hedge signal
↓
update pool state
```



## Gas Optimization Strategy

Exposure math must be cheap.

Optimizations:

- avoid floating point
- avoid exponentiation
- reuse sqrtPriceX96
- approximate liquidity value

Hook execution target:

```solidity
< 40k gas
```

This keeps swaps inexpensive.



## Edge Case Handling

### i. Low liquidity pools

If:

```solidity
liquidity < minimum
```

Skip exposure computation.


### ii. Price shock

If the price change exceeds the safety bound:

```solidity
abs(price - lastPrice) > shockLimit
```

Emit an immediate hedge signal.



### iii. Pool shutdown

If the pool is inactive:

skip execution.



## Security Considerations

### i. Manipulation attacks

Attacker moves price to trigger hedge.

Mitigation:

- TWAP price
- minimum interval
- delta hysteresis


### ii. Swap spam

Many small swaps could spam events.

Mitigation:

- only emit event when delta crosses band

Example:

```solidity
threshold = 5 ETH
band = 1 ETH
```



## AMM Layer Data Flow

```solidity
Trader swap
     │
     ▼
Uniswap v4 Pool
     │
     ▼
DeltaShield Hook
     │
     ├─ read pool state
     ├─ compute LP delta
     ├─ evaluate threshold
     │
     ▼
Emit HedgeRequired event
```

This is the only output of this layer.



## AMM Layer Outputs

This layer guarantees:

1. exposure detection
2. deterministic event emission
3. minimal gas overhead
4. zero swap interference

It does **not** guarantee risk neutrality.

That is the job of the **Hedge Execution** layer.



# Conclusion

This design demonstrates:

- understanding of AMM microstructure
- derivatives hedging theory
- hook lifecycle engineering
- efficient on-chain math

It transforms the AMM into a **risk-aware liquidity engine**.

This layer lives entirely inside **Uniswap v4** and runs on **Unichain**.

It is the **risk-sensing brain of the system**.
It observes swaps and liquidity changes, computes LP exposure, and emits signals when the pool becomes directionally risky.

The **Reactive layer and hedging layer do nothing until this layer detects risk**.
