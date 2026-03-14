# Threat Model & Security Considerations

## 1. Security Philosophy

Hooks in Uniswap v4 execute during core pool lifecycle events such as swaps and liquidity modifications. Any bug in a hook could introduce:

* denial-of-service risks
* price manipulation vectors
* gas griefing
* reentrancy vulnerabilities

Therefore, the hook design follows three principles:

1. minimal execution logic
2. read-only exposure tracking
3. externalized execution

The hook **does not directly execute hedge trades**.
It only **observes AMM state and emits exposure signals**.

All capital-moving logic occurs in separate contracts.

This dramatically reduces the attack surface.



## 2. Threat Model

The system assumes the following adversaries may exist:

| Adversary           | Capabilities                            | Goal                          |
| ------------------- | --------------------------------------- | ----------------------------- |
| MEV searchers       | observe mempool, reorder transactions   | manipulate exposure triggers  |
| malicious LP        | creates adversarial liquidity positions | manipulate hedge calculations |
| swap attackers      | execute large swaps                     | trigger unnecessary hedges    |
| automation griefers | spam triggers                           | increase protocol gas cost    |



## 3. Reentrancy Risks

Hooks execute inside pool operations.

Reentrancy could occur if the hook:

- calls external contracts
- which calls the pool again

Mitigation:

- no external calls inside hook
- no hedge execution in the hook
- no token transfers

The hook only performs:

- state read
- delta calculation
- event emission

This prevents reentrancy surfaces.



## 4. Oracle Manipulation

If the system relied entirely on the AMM price, an attacker could:

1. perform a large swap
2. temporarily distort the price
3. trigger hedge
4. reverse swap

Mitigation strategies:

- TWAP price checks
- minimum delta thresholds
- cooldown periods between hedges

Future versions can integrate Oracle feeds from Chainlink for price validation.



## 5. Automation Abuse

Attackers could attempt to trigger repeated hedges.

Example:

1. swap small amounts repeatedly
2. force hedge rebalancing
3. increase gas costs

Mitigation:

- delta threshold trigger
- time-based cooldown
- minimum hedge size

Trigger rule example:

```solidity
|Δ_current − Δ_target| > Δ_threshold
AND
last_hedge_time > cooldown
```



## 6. Denial of Service

Hooks must never revert unless absolutely necessary.

Design rule:

- hook logic must be non-blocking

If exposure computation fails:

- skip update
- emit fallback event

This ensures the pool continues functioning.



## 7. Smart Contract Isolation

System components are intentionally separated.

- Hook → monitoring only
- Controller → strategy logic
- Hedge adapter → execution

A compromise of one layer cannot directly compromise the pool.







# Gas Optimization Strategy

Gas efficiency is critical because hooks execute during swaps.

Poorly optimized hooks could make pools unusable.



## 1. Minimal Hook Logic

Hook computation complexity must remain **O(1)**.

Avoid:

- loops
- heavy math
- storage writes
- external calls

Operations allowed:

- simple arithmetic
- event emission
- single storage write



## 2. Storage Minimization

Storage is the most expensive operation in Ethereum.

Instead of storing full LP positions:

- store minimal exposure state

Example structure:

```solidity
struct ExposureState {
    int256 delta;
    uint256 lastUpdate;
}
```

This reduces gas during swaps.



## 3. Event-Driven Architecture

Instead of storing complex state on-chain, the hook emits events.

```solidity
ExposureUpdated(poolId, delta, price)
```

Automation services process events off-chain.

Benefits:

- less storage
- cheaper swaps
- better scalability



## 4. Fixed-Point Arithmetic

Floating-point math does not exist in Solidity.

Use efficient formats:

1. Q64.96
2. Q128.128

These formats are already used in Uniswap v3 and inherited by v4.

Benefits:

- precision
- gas efficiency
- compatibility with pool math



## 5. Avoiding Recalculation

Instead of recomputing everything:

- reuse pool state
- reuse liquidity values

Example:

```solidity
price = slot0.sqrtPriceX96
```

Then compute exposure from cached liquidity.



## 6. Batched Hedging

Instead of hedging every swap:

- aggregate exposure
- hedge periodically

This reduces execution cost.

Example rule:

1. trigger hedge every N blocks
2. or when delta exceeds threshold







# Economic Attack Analysis

DeFi protocols must defend not only against code exploits but also **economic manipulation**.



## 1. MEV Manipulation

Searchers could manipulate prices to force hedging events.

Example:

- large swap → trigger hedge
- reverse swap → capture hedge profit

Mitigation:

- TWAP validation
- hedge delay
- minimum hedge threshold



## 2. Sandwich Attacks

An attacker could:

1. front-run swap
2. trigger hedge
3. back-run swap

Mitigation:

- hedge only after threshold
- avoid single-swap triggers



## 3. Liquidity Manipulation

Malicious LPs might create positions designed to distort delta calculations.

Example:

- extremely narrow ranges
- very high leverage exposure

Mitigation:

- exposure caps
- minimum liquidity thresholds



## 4. Derivatives Market Manipulation

If the hedge uses derivatives, attackers could manipulate the derivatives market price.

Mitigation:

- use large liquidity markets
- TWAP validation
- price sanity checks



## 5. Fee vs Hedging Cost Tradeoff

Over-hedging can destroy LP profits.

Example:

```solidity
LP fees = 0.05%
hedging cost = 0.07%
```

The strategy would lose money.

Therefore, the system uses:

- adaptive hedge thresholds

This ensures hedging only occurs when risk exceeds cost.



## 6. Volatility Regime Changes

High volatility periods could produce excessive hedging.

Future improvement:

- volatility-aware hedge frequency

The system could increase or decrease hedging frequency depending on market conditions.







# 31. Security Testing Strategy

Testing includes simulations of:

- large swaps
- rapid volatility
- LP deposits and withdrawals
- hedge trigger conditions

Using **Foundry fuzz testing**.

This ensures the system behaves correctly under adversarial conditions.
