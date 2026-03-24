# From Delta to Gamma

Earlier we defined **delta**:

$$
\Huge \Delta = \frac{\partial V}{\partial P}
$$

where

```solidity
V = LP portfolio value
P = asset price
```

Delta tells us **how sensitive the LP value is to a small price change**.

But markets do not move smoothly. When price moves significantly, **delta itself changes**. The rate at which delta changes is **gamma**.

$$
\Huge \Gamma = \frac{\partial^2 V}{\partial P^2}
$$

Interpretation:

```solidity
gamma = how quickly exposure changes as price moves
```

In options theory:

* **Long gamma → benefits from volatility**
* **Short gamma → loses from volatility**

Uniswap LP positions are **short gamma**.

That fact explains most of impermanent loss. It intellectually is extremely valuable because it explains a phenomenon many LPs experience without realizing the mechanics: **impermanent loss accelerates during volatile markets**.



# Why LPs Are Short Gamma

Recall the LP reserve equations (inside the range):

$$
\Huge x = L\left(\frac{1}{\sqrt{P}} - \frac{1}{\sqrt{P_b}}\right)
$$

$$
\Huge y = L(\sqrt{P} - \sqrt{P_a})
$$

Earlier we discovered:

$$
\Huge \Delta = x
$$

Now compute gamma:

$$
\Huge \Gamma = \frac{d\Delta}{dP}
$$

Substitute:

$$
\Huge \Delta =
L\left(\frac{1}{\sqrt{P}} - \frac{1}{\sqrt{P_b}}\right)
$$

Derivative:

$$
\Huge \Gamma =
-\frac{L}{2P^{3/2}}
$$

Important observation:

```solidity
gamma < 0
```

That negative sign means **LPs are short gamma**.



# Intuition Behind Short Gamma

Think about what the AMM does mechanically.

When price rises:

```solidity
pool sells token0
pool buys token1
```

When price falls:

```solidity
pool buys token0
pool sells token1
```

This behavior is equivalent to:

```solidity
sell when price rises
buy when price falls
```

In trading language:

```solidity
buy high, sell low
```

That is the hallmark of a **short gamma strategy**.



# Impermanent Loss as Gamma Loss

Impermanent loss can be derived from the constant product invariant.

For a 50/50 AMM:

$$
\Huge IL = 2\sqrt{r}/(1+r) - 1
$$

where

```solidity
r = price ratio
```

Example:

Price doubles:

```solidity
r = 2
```

$$
\Huge IL ≈ -5.7%
$$

If price oscillates repeatedly, IL accumulates **even if price returns to the starting point**.

Example:

```solidity
ETH 2000 → 2200 → 2000 → 2200 → 2000
```

An LP will end with **less value than a holder**, even though the final price is identical.

This happens because every oscillation forces the AMM to:

```solidity
sell into strength
buy into weakness
```

This is exactly the loss pattern of a **short gamma position**.



# Volatility Amplifies Impermanent Loss

Gamma exposure means losses scale with **volatility squared**.

Rough approximation from options theory:

$$
\Huge Gamma\ Loss \propto \Gamma \cdot \sigma^2
$$

Where

```solidity
σ = market volatility
```

This means:

```solidity
small price drift → small IL
high volatility → large IL
```

Example:

Stable market:

```solidity
ETH moves ±2%
```

LP IL is small.

Volatile market:

```solidity
ETH moves ±20%
```

The pool continuously rebalances and accumulates losses.



# Why Delta Hedging Alone Is Not Enough

Current design hedges **delta**.

That means:

```solidity
LP exposure to price direction ≈ neutral
```

Example:

```solidity
LP delta = +5 ETH
hedge = short 5 ETH
```

Directional risk disappears.

But gamma remains.

When price moves significantly, delta changes:

```solidity
price rises → LP sells ETH → delta decreases
price falls → LP buys ETH → delta increases
```

Your hedge position becomes **misaligned**.

Example:

```solidity
initial delta = 5 ETH
short hedge = 5 ETH
```

Price rises.

LP delta becomes:

```solidity
3 ETH
```

But the hedge is still:

```solidity
short 5 ETH
```

Now the system is **over-hedged**.

You must rebalance.



# Dynamic Hedging

To handle gamma exposure, professional market makers perform **dynamic hedging**.

Concept:

```solidity
continuously adjust delta hedge
```

Mathematically:

$$
\Huge Hedge = \Delta(P)
$$

As price moves, recompute delta.

Example workflow:

```solidity
Price = 2000
delta = 5 ETH
hedge = short 5 ETH
```

Price moves to:

```solidity
2100
```

New delta:

```solidity
3.8 ETH
```

Adjust hedge:

```solidity
close 1.2 ETH short
```

This process is called:

```solidity
gamma hedging
```



# Connection to Options

An LP position resembles selling a **straddle option**.

A short straddle profits from:

```solidity
low volatility
```

But loses when price moves significantly.

LPs earn:

```solidity
trading fees
```

Which compensate for being short volatility.

In financial terms:

```solidity
LP = short volatility trader
fees = volatility premium
```

If volatility exceeds fee income:

```solidity
LP loses money
```



# Example: Volatility vs Fees

Suppose:

```solidity
daily fee income = 0.05%
```

Volatility scenario 1:

```solidity
price moves ±1%
```

Impermanent loss:

```solidity
≈ 0.01%
```

LP profits.

Volatility scenario 2:

```solidity
price moves ±10%
```

Impermanent loss:

```solidity
≈ 1%
```

Fees cannot compensate.

LP loses.



# Why Gamma Modeling Changes Hedging Strategy

A simple delta hedge assumes:

```solidity
price moves smoothly
```

But gamma-aware strategies recognize:

```solidity
large moves require rebalancing
```

Better hedging strategies include:

### Delta rebalancing thresholds

Only rebalance when delta deviates beyond a limit.

```solidity
|Δ_current − Δ_target| > threshold
```



### Volatility-aware hedging

Increase hedge frequency when volatility rises.



### Partial hedging

Instead of hedging 100%:

```solidity
hedge 80–90%
```

This reduces trading costs.



# What a Gamma-Aware Hook Would Do

Future expansion of your system could include:

1. volatility estimator
2. delta recalculation frequency
3. dynamic hedge sizing

Example workflow:

- hook computes LP delta
- Reactive layer monitors volatility
- controller adjusts hedge frequency

High volatility:

```solidity
rebalance every price move
```

Low volatility:

```solidity
rebalance rarely
```



# Why This Matters for DeFi Research

Most DeFi LP tools only show:

- APR
- fees
- impermanent loss

But professional liquidity provision is actually:

```solidity
quantitative volatility trading
```

A **gamma-aware AMM vault** would transform LPs into something closer to:

```solidity
automated options market makers
```

Which is why this topic is being studied heavily in DeFi research.



# Future Scope

Current version:

- delta-neutral hedging for LP exposure

Future version:
- gamma-aware hedging with dynamic volatility adaptation

That signals that the project can evolve from:

*reactive hedge tool* into a **full quantitative liquidity management system**.



One fascinating consequence of this short-gamma property is that **Uniswap LP positions mathematically resemble selling options**. Comparing the payoff curve of an LP to a short straddle, they are almost indistinguishable. That insight opens the door to a completely different design space, AMMs that automatically **hedge LP gamma using on-chain options markets**, something that could eventually turn a Uniswap hook into a **fully autonomous volatility market maker**.
