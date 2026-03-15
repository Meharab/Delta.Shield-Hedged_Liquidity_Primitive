The interesting part of this project lives exactly here. Hedging LPs requires understanding **what an LP position really is mathematically**. Think in first principles, a Uniswap LP position is not just “liquidity”. It is a **non-linear portfolio of two assets whose composition depends on price**.

That non-linearity is precisely why **impermanent loss exists** and why hedging must compute **delta exposure**.

So we will build the full picture from the ground up.



# First Principles: LP Position

In a Uniswap-style AMM, the invariant is

$$
\Huge x \cdot y = k
$$

Where

- x = token0 reserves
- y = token1 reserves
- k = constant

Price of token0 in token1:

$$
\Huge P = \frac{y}{x}
$$

But LPs do not hold fixed amounts of tokens. The AMM **rebalances their holdings continuously** as price moves.

So the LP position is effectively:

1. long token0 when the price is low
2. long token1 when the price is high

This means an LP position behaves like a **short volatility position**.

To hedge it, we must compute the **delta exposure**.



# Delta

Delta in finance means:

$$
\Huge \Delta = \frac{\partial V}{\partial P}
$$

Where

- V = portfolio value
- P = price

Interpretation:

- how much the portfolio value changes when the price changes

For hedging, we want:

```solidity
LP delta + hedge delta ≈ 0
```



# Liquidity Mathematics

Uniswap v4 inherits the **concentrated liquidity model** of v3.

Liquidity providers define a price range:

```solidity
[Pa, Pb]
```

Using the **sqrt price representation**

```solidity
sqrtP = √P
```

The pool internally uses:

```solidity
sqrtPriceX96 = √P * 2^96
```

But mathematically, we can ignore the scaling.



### Liquidity Formula

Liquidity (L) determines the reserves.

When the price is within the range:

$$
\Huge x = L \left(\frac{1}{\sqrt{P}} - \frac{1}{\sqrt{P_b}}\right)
$$

$$
\Huge y = L \left(\sqrt{P} - \sqrt{P_a}\right)
$$

Where

- x = token0 amount
- y = token1 amount

These equations describe the **exact asset composition of an LP position at any price**.



# LP Portfolio Value

Value in token1 terms:

$$
\Huge V = xP + y
$$

Substitute the formulas.



### Token0 value

$$
\Huge xP =
L \left(\frac{1}{\sqrt{P}} - \frac{1}{\sqrt{P_b}}\right) P
$$

Simplify:

$$
\Huge xP =
L \left(\sqrt{P} - \frac{P}{\sqrt{P_b}}\right)
$$



### Token1 value

$$
\Huge y =
L \left(\sqrt{P} - \sqrt{P_a}\right)
$$



### Total value

$$
\Huge V =
L \left(\sqrt{P} - \frac{P}{\sqrt{P_b}}\right)
+
L \left(\sqrt{P} - \sqrt{P_a}\right)
$$

Simplify:

$$
\Huge V =
L \left(2\sqrt{P} - \sqrt{P_a} - \frac{P}{\sqrt{P_b}}\right)
$$



# Computing LP Delta

Delta is the derivative of value w.r.t price.

$$
\Huge \Delta = \frac{dV}{dP}
$$

Take the derivative.

Derivative of:

```solidity
2√P = 1/√P
```

Derivative of:

```solidity
P/√Pb = 1/√Pb
```

So

$$
\Huge \Delta =
L \left(
\frac{1}{\sqrt{P}} -
\frac{1}{\sqrt{P_b}}
\right)
$$

This expression is extremely important.

Look closely.

It is exactly the **token0 amount**.

Recall:

$$
\Huge x =
L \left(\frac{1}{\sqrt{P}} - \frac{1}{\sqrt{P_b}}\right)
$$

Therefore

$$
\Huge \Delta = x
$$



# Key Insight

For a concentrated LP position:

```solidity
LP delta exposure = token0 inventory
```

Meaning:

```solidity
delta ≈ token0 held by the position
```

This simplifies hedging enormously.



# Intuition

If an LP holds:

```solidity
10 ETH
```

Then the LP has **+10 ETH delta exposure**.

If ETH price rises:

- LP portfolio value increases

To hedge:

```solidity
short 10 ETH
```

Now the system becomes **delta neutral**.



# Example Calculation

Suppose an LP provides liquidity:

```solidity
ETH / USDC pool
range = [1500, 2500]
```

Current price:

```solidity
P = 2000
```

Liquidity:

```solidity
L = 1000
```



### Step 1: compute sqrt prices

```solidity
√P  ≈ 44.72
√Pa ≈ 38.73
√Pb ≈ 50
```



### Step 2: compute token amounts

Token0:

$$
\Huge x =
1000 \left(
\frac{1}{44.72} -
\frac{1}{50}
\right)
$$

```solidity
1/44.72 ≈ 0.02236
1/50 ≈ 0.02
```

So

```solidity
x ≈ 2.36 ETH
```



Token1:

$$
\Huge y =
1000 (44.72 - 38.73)
$$

```solidity
y ≈ 5990 USDC
```



### Step 3: LP value

```solidity
ETH value = 2.36 × 2000 = 4720
```

Total

```solidity
V = 4720 + 5990
V ≈ 10710 USDC
```



### Step 4: Delta exposure

From the formula:

```solidity
delta = x
```

So

```solidity
delta = 2.36 ETH
```



# Hedge Position

To neutralize exposure:

```solidity
short 2.36 ETH
```

If the ETH price increases:

- LP gains
- short loses

Net exposure ≈ 0.



# Three Price Regimes

The formulas change depending on where the price lies relative to the LP range.



### Case 1: Price Below Range

$$
\Huge P < P_a
$$

LP holds only token0.

```solidity
x = L (1/√Pa − 1/√Pb)
y = 0
```

Delta:

- fully long token0



### Case 2: Price Inside Range

$$
\Huge P_a < P < P_b
$$

LP holds both tokens.

Delta:

- x token0 exposure



### Case 3: Price Above Range

$$
\Huge P > P_b
$$

LP holds only token1.

```solidity
x = 0
y = L(√Pb − √Pa)
```

Delta:

```solidity
0
```

Meaning:

- no hedge needed



# Hook Utilization

Hook tracks:

- current sqrtPrice
- liquidity
- range

It computes:

- token0 exposure

Pseudo code:

```solidity
function computeDelta(liquidity, sqrtP, sqrtPb):
        delta = liquidity * (1/sqrtP - 1/sqrtPb)
```

This value becomes:

- hedge target



# System Workflow

Full pipeline now becomes:

```solidity
swap occurs
      ↓
hook reads sqrtPrice
      ↓
compute token0 exposure
      ↓
delta = exposure
      ↓
Reactive trigger
      ↓
open short delta
```



# Real-World Refinements

A production protocol must handle additional complexity.

### Multiple LP ranges

LPs may have many ranges.

Total delta:

```solidity
Σ delta_i
```



### Price smoothing

Use:

- TWAP

instead of the spot price.



### Hedge buffer

Instead of perfect neutrality:

```solidity
hedge 90-95%
```

to reduce trading costs.



# Conclusion

This design actually computes:

```
exact delta from concentrated liquidity math
```

This protocol becomes a **quantitative liquidity vault**.
