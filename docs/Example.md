# Introduction

The system revolves around three interacting components:

* the AMM pool in **Uniswap v4**
* an adaptive hook controlling exposure
* a reactive automation layer from **Reactive Network** running on **Unichain**

The goal is simple:
**allow liquidity providers to earn swap fees while neutralizing most directional price risk.**



# First Principle: LP Exposure

Liquidity providers in an AMM are not neutral traders. They carry embedded market exposure.

Consider a classic constant-product pool:

$$
\Huge x \cdot y = k
$$

If you deposit:

* 1 ETH
* 2000 USDC

into an ETH/USDC pool when ETH = $2000, you now provide liquidity.

At that moment, your position value:

$$
\Huge V = 4000\ \text{USD}
$$

But as price moves, your portfolio composition automatically changes.

### Example: ETH price rises to $3000

Arbitrageurs rebalance the pool.

Your position becomes approximately:

* **0.816 ETH**
* **2449 USDC**

Total value:

$$
\Huge 0.816 * 3000 + 2449 = 4897
$$

If you had simply held assets:

$$
\Huge 1 ETH + 2000 USDC = 5000
$$

Loss vs holding:

$$
\Huge IL \approx -2.06%
$$

This is **impermanent loss**.

The reason is mathematical:

LPs **sell winners and buy losers automatically**.

Which means an LP is economically:

* short volatility
* partially directionally exposed

This directional component is called **delta**.



# Delta

In derivatives theory, **delta** measures how sensitive a position is to price change.

$$
\Huge \Delta = \frac{dV}{dP}
$$

Interpretation:

If delta = 1
→ your position behaves like holding 1 unit of the asset.

If delta = 0
→ price changes don’t affect your position value.



### LP Delta Example

For a symmetric pool:

Initial position:

1 ETH + 2000 USDC.

Delta ≈ **0.5 ETH**

Meaning:

If the ETH price increases by $100:

$$
\Huge \text{value change} \approx 0.5 \times 100 = 50
$$

LPs are **partially long ETH**.

This exposure is what causes impermanent loss.



# The Key Insight

If LPs are long 0.5 ETH exposure, we can hedge it.

Open a **short position of 0.5 ETH** somewhere else.

Then:

| Component   | Exposure |
| ----------- | -------- |
| LP position | +0.5 ETH |
| Perps short | −0.5 ETH |

Net:

$$
\Huge \Delta_{net} \approx 0
$$

Now, price movement doesn't affect net position much.

But **still earns trading fees from the pool**.

This is the core mechanism.



# Problem

Today, LPs must hedge manually.

Typical institutional workflow:

1. Provide liquidity
2. Monitor exposure
3. Calculate hedge
4. Open perps position
5. Rebalance frequently

Problems:

* slow
* manual
* expensive
* error-prone

The insight of the hook system in **Uniswap v4** is that **pool logic can become programmable**.

That means exposure tracking can happen **inside the pool lifecycle**.



# 5. Hook

The hook monitors pool events.

Important hook events:

```solidity
afterSwap()
afterModifyPosition()
```

Every time a trade occurs, the price changes.

The hook:

1. Reads current pool price
2. Calculates LP exposure
3. Compares exposure with threshold
4. If too large → emit hedge event

Example event:

```solidity
HedgeRequired(pool, delta, price)
```

This event is picked up by the automation infrastructure.



# Reactive Automation

Smart contracts cannot wake themselves up.

They must be triggered.

This is where **Reactive Network** becomes useful.

Reactive smart contracts:

1. Watch blockchain events
2. Execute logic when conditions are met

So the flow becomes:

```solidity
Swap occurs
   ↓
Hook calculates delta
   ↓
Hook emits HedgeRequired event
   ↓
Reactive Network detects event
   ↓
Reactive contract executes hedge
```

This hedge can be executed on **Unichain**, where transaction costs are lower.



# 7. Walkthrough

Let’s simulate a concrete scenario.

### Market

ETH/USDC pool.

Initial price:

```solidity
ETH = $2000
```

LP deposits:

```solidity
10 ETH
20,000 USDC
```

Total position:

```solidity
$40,000
```

Estimated delta:

```solidity
≈ 5 ETH exposure
```

Meaning LP behaves roughly like holding 5 ETH.


## Step 1: Hook Calculates Delta

Hook computes:

```solidity
delta ≈ 5 ETH
```

Configured threshold:

```solidity
3 ETH
```

Since:

```solidity
5 > 3
```

Hedge needed.

Hook emits:

```solidity
HedgeRequired(5 ETH)
```



## Step 2: Reactive Network Executes Hedge

Reactive automation receives event.

It executes a hedge:

```solidity
Open short position = 5 ETH
```

Using a perps market or synthetic hedge.

Now exposure:

| Component | Exposure |
| --------- | -------- |
| LP        | +5 ETH   |
| Perps     | −5 ETH   |

Net:

```solidity
0 ETH
```



## Step 3: Price Rises

ETH moves:

```solidity
$2000 → $2600
```

LP experiences impermanent loss internally.

But the short perps position profits.

Loss and profit approximately cancel.

What remains?

**Swap fees earned by LP.**

This is the desired outcome.



# Adaptive Rebalancing

Over time, exposure changes.

Example:

Many swaps push pool composition.

Delta might shift:

```solidity
+5 ETH → +2 ETH
```

Hook notices:

```solidity
|2 ETH| < threshold
```

So no rebalance.

Later:

```solidity
+2 ETH → −4 ETH
```

Now LP is net short ETH.

Hook emits:

```solidity
HedgeRequired(+4 ETH)
```

Automation adjusts the hedge.

This dynamic adjustment makes the system **adaptive**.



# Value

Without hedging:

LP payoff depends heavily on price direction.

With hedging:

LP payoff becomes approximately:

```solidity
Swap fees – hedge costs
```

Which behaves closer to **yield farming** than speculative exposure.

This opens new products:

* structured LP vaults
* stable yield products
* institutional market-making strategies



# Conclusion

Previous AMM versions could not do this cleanly.

The hook architecture of **Uniswap v4** allows:

* stateful logic
* swap interception
* dynamic accounting
* event emission

So the AMM itself becomes a programmable trading engine.

Technically, it demonstrates:

* AMM microstructure
* derivatives hedging theory
* automated risk management
* cross-contract architecture

Economically, it creates:

* new LP products
* risk-managed liquidity markets
* specialized AMM designs
