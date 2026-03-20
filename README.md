# DeltaShield: Autonomous Delta-Neutral Liquidity

> **"Turning Volatile Liquidity into Stable Yield through Programmable Risk Management."**

DeltaShield is a decentralized, cross-chain risk management protocol designed to neutralize **Impermanent Loss (IL)** for Liquidity Providers. By combining the programmability of **Uniswap v4 Hooks** with the event-driven intelligence of the **Reactive Network**, DeltaShield creates the first **self-hedging liquidity primitive** in the DeFi ecosystem.

---

## The Pitch: Solving the $5B Growth Blocker

Liquidly providing (LPing) in AMMs like Uniswap is the bedrock of DeFi, yet it remains fundamentally broken for the average user. **Impermanent Loss** is a structural "short volatility" bet—when prices move, LPs lose relative to holding. This makes market-making a speculative gamble rather than a yield-generating service.

**DeltaShield transforms this paradigm.** We've built an autonomous system that:
1.  **Senses** price-driven risk on Ethereum in real-time.
2.  **Analyzes** the required hedge magnitude via a Reactive Brain.
3.  **Executes** counter-derivative hedges on Unichain.

The result? LPs capture **swap fees** while the protocol maintains **directional neutrality**.

---

## How it Works: The Sensor-Brain-Actuator Loop

DeltaShield operates across three distinct blockchain environments, ensuring that risk management is as fast as the market move itself.

### 1. The Sensor (Origin: Ethereum)
Integrated as a **Uniswap v4 Hook**, the `AMMHook` monitors every swap and liquidity modification. It uses a mathematical breakthrough in on-chain efficiency to estimate risk:
*   **The Identity**: $\Delta \equiv x$ (LP Delta exposure is equivalent to Token0 inventory).
*   **The Signal**: Emits a `HedgeRequired` event the moment an exposure threshold is breached.

### 2. The Brain (Reactive Network: Lasna)
The `AutomationController` is an autonomous ReactVM contract that "listens" to the Ethereum sensor. No keepers. No bots. No central points of failure.
*   **Autonomous Logic**: Evaluates risk signals, enforces cooldowns (to prevent swap-spam), and computes the cross-chain execution payload.
*   **The Bridge**: Dispatches authenticated callbacks via the Reactive Network's secure relayers.

### 3. The Actuator (Destination: Unichain)
The `HedgeController` receives the brain's instruction and acts as the protocol's muscle.
*   **Dynamic Rebalancing**: Scales hedge positions up or down based on the delta shift.
*   **Secure Ledger**: Integrates with a `MockPerpsEngine` to track synthetic exposure and PnL with 100% determinism.

---

## Technical Uniqueness & Innovation

*   **Mathematical Simplification**: By deriving the relationship between concentrated liquidity and delta exposure, I offload complex calculus to the RVM, keeping Ethereum gas costs at an absolute minimum.
*   **Non-Custodial Automation**: Unlike traditional "Manager" vaults, DeltaShield never takes custody of LP principal. It manages a parallel hedge account to offset the risk of the primary pool.
*   **Cross-Chain Efficiency**: Rebalancing happens on secondary chains (Unichain) where execution costs are orders of magnitude lower than the Ethereum Mainnet.

---

## Technical Deep Dive & Repository Map

For the Board of Directors, Investors, and Developers, this repository is architected for transparency and production readiness:

*   ** [src/](./src/README.md)**: The core protocol smart contracts (Solidity 0.8.26).
*   ** [docs/](./docs/README.md)**: The theoretical foundation, including full delta-math derivations $(\Delta)$ and system workflows.
*   ** [test/](./test/README.md)**: An exhaustive validation suite covering price shocks, threshold hysteresis, and directional flips.
*   ** [script/](./script/README.md)**: Multi-chain deployment and orchestration workflows for Testnet simulation.

---

##  The Future: Automated Yield Vaults

DeltaShield is more than a hook; it is a **primitive for Institutional Liquidity**. Our roadmap includes:
*   **Dynamic Hedge Ratios**: Adjusting exposure based on real-time volatility (Gamma hedging).
*   **Automated Reinvestment**: Using hedge profits to buy back LP tokens, creating an auto-compounding "Delta-Zero" vault.
*   **Multi-Engine Adapters**: Integrating with GMX, Synthetix, and Hyperliquid for real-world perp execution.

---

## 🛠️ Getting Started

### Installation
```bash
git clone https://github.com/Meharab/Delta.Shield-Hedged_Liquidity_Primitive.git
cd Delta.Shield-Hedged_Liquidity_Primitive
forge build
```

### Full Verification
```bash
# Run all unit and integration tests
forge test
```

---

### **DeltaShield: Guarding your Liquidity, Shielding your Yield.**
*Developed for the Future of Autonomous Market Making.*
