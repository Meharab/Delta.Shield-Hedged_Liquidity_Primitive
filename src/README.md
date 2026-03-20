# DeltaShield Core Smart Contracts

This directory contains the primary implementation of the DeltaShield protocol, a cross-chain risk management system for Uniswap v4 Liquidity Providers.

## System Architecture & Connectivity

DeltaShield operates as a **Sensor-Brain-Actuator** loop distributed across three chain environments:

1.  **Sensor (`AMMHook.sol`)**: Deployed on the **Origin Chain** (Ethereum). It monitors Uniswap v4 pools and emits `HedgeRequired` events when LP exposure (delta) shifts beyond safe bounds.
2.  **Brain (`AutomationController.sol`)**: Deployed on the **Reactive Network** (Lasna). It subscribes to the sensor's events, analyzes the magnitude of the risk, and computes the required hedge adjustment.
3.  **Actuator (`HedgeController.sol`)**: Deployed on the **Destination Chain** (Unichain/Arbitrum). It receives authenticated callbacks from the brain and executes synthetic derivative trades to neutralize the risk.
4.  **Execution Ledger (`MockPerpsEngine.sol`)**: The final accounting layer on the Destination Chain that manages position lifecycle and PnL.

---

## Contract Breakdown

### 1. `AMMHook.sol`
The entry point of the protocol, integrated directly into Uniswap v4.

*   **Key Variables**:
    *   `poolStates`: Mapping of `PoolId` to tracking data (last price, delta, timestamps).
    *   `DEFAULT_DELTA_THRESHOLD`: Sensitivity of the sensor (default 1 ETH equivalent).
    *   `PRICE_SHOCK_BPS`: Triggers immediate hedge if price swings > 5% regardless of cooldown.
*   **Core Functions**:
    *   `_afterSwap()`: Main trigger that recalculates exposure after every trade.
    *   `_updateExposure()`: Internal logic estimating delta as roughly `Liquidity / 2`.
    *   `_shouldHedge()`: Boolean gate evaluating threshold breaches and cooldowns.
*   **Design Patterns**: **Observer Pattern**. The hook never intercepts or modifies user swaps (non-custodial).
*   **Gas Optimization**: uses `IPoolManager.getSlot0` and `getLiquidity` directly to avoid redundant storage logic.
*   **Security**: Inherits `BaseHook`. Emits `ExposureUpdated` on every tick for transparent off-chain auditing.

### 2. `AutomationController.sol`
The autonomous analyzer running on the Reactive Virtual Machine (RVM).

*   **Key Variables**:
    *   `originHookAddress`: The ONLY authorized emitter address and topic.
    *   `callback`: Target address of the `HedgeController` on the execution chain.
*   **Core Functions**:
    *   `react()`: Primary RVM entry point. Decodes the cross-chain log and evaluates triggers.
    *   `_dispatchHedge()`: Encodes a `callback(address,...)` payload with a `address(0)` placeholder for RVM sender injection.
*   **Design Patterns**: **Reactive Automation**. Decouples high-compute risk analysis from expensive L1/L2 gas costs.
*   **Gas Optimization**: Offloads all "Heavy Math" and "If-Else" branching to the Reactive Network, keeping On-chain footprints minimal.
*   **Security**: `InvalidEmitter` check prevents malicious actors from spoofing risk signals.

### 3. `HedgeController.sol`
The execution router that acts on risk signals.

*   **Key Variables**:
    *   `perpsEngine`: Address of the authorized execution ledger.
    *   `hedgeRatio`: Scaling factor (e.g., 70% of total LP delta is hedged).
    *   `lastHedgeTimestamp`: Destination-side protection against duplicate callbacks.
*   **Core Functions**:
    *   `callback()`: Authenticated entry point for Reactive Network proxies.
    *   `_computeTargetHedge()`: Converts "LP Exposure" into "Hedge Size" (Inverse direction).
*   **Design Patterns**: **Actuator / Router**. Managed by `AbstractCallback`.
*   **Gas Optimization**: Batch rebalancing logic reduces transaction frequency by enforcing a `hedgeCooldown`.
*   **Security**: Implements `authorizedSenderOnly` (checks RVM Proxy) and `rvmIdOnly` (prevents cross-protocol replay attacks).

### 4. `MockPerpsEngine.sol`
A deterministic ledger for synthetic derivative positions.

*   **Key Variables**:
    *   `positions`: Master repository of all active hedges.
    *   `controller`: Immutable address of the only authorized `HedgeController`.
*   **Core Functions**:
    *   `openPosition()`: Creates a new directional entry.
    *   `increasePosition()` / `decreasePosition()`: Updates size and recalculates weighted average entry price.
    *   `closePosition()`: Realizes PnL based on calculated settlement prices.
*   **Design Patterns**: **Ledger / Accounting**. Centralizes all value-at-risk for the protocol.
*   **Gas Optimization**: Minimal storage mapping logic; uses integer division for entry price rounding to save compute.
*   **Security**: Strict `onlyController` access control prevents unauthorized position manipulation.

### 5. `MockEventGenerator.sol`
A helper contract used for testnet orchestration and benchmarking, allowing users to trigger the full cross-chain flow without complex Uniswap v4 pool setups.

---

## Interfaces (`/interfaces`)

The `interfaces/` sub-directory defines the standard interaction patterns to ensure modularity and ease of integration:

*   **`IHedgeController.sol`**: Defines the `callback` signature and rebalance logic enforced by the Hedge layer.
*   **`IPerpsEngine.sol`**: Standardizes position metadata, exposure queries, and the lifecycle operations (open/increase/decrease/close) for derivative ledgers.
