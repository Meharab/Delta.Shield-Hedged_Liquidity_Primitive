# DeltaShield Testing Suite

This directory contains the comprehensive Foundry test suite for the DeltaShield protocol, covering every layer from AMM sensing to cross-chain hedge execution.

## Execution Guide

### Run All Tests
```bash
forge test
```

### Run Specific Test Suite
```bash
forge test --match-contract AMMHookTest
```

### Run with Verbosity (Traces)
```bash
forge test -vvv
```

### Run Specific Test Function with Verbosity (Traces)
```bash
forge test --match-test testUnauthorizedCallback_Reverts -vvvvv
```

---

## Test Contracts Overview

### 1. `AMMHook.t.sol` (Hook Layer)
Validates the Uniswap v4 Hook's ability to track liquidity-weighted delta and emit risk signals.
- **`test_poolInitialization`**: Verifies that the hook correctly sets up storage for new pools.
- **`test_liquidityAddition`**: Ensures adding liquidity triggers a delta recalculation and emits an `ExposureUpdated` event.
- **`test_liquidityRemoval`**: Ensures removing liquidity updates the exposure state accurately.
- **`test_swapTrigger`**: Validates that swaps update the internal pool price and recalculate LP delta.
- **`test_hedgeTrigger`**: Hard-tests the "Breach" logic—verifies that `HedgeRequired` is emitted when delta exceeds the threshold.
- **`test_thresholdHysteresis`**: Confirms that small fluctuations below the threshold do NOT trigger unnecessary hedges.
- **`test_rebalanceInterval`**: Enforces the minimum cooldown period between subsequent hedge signals.
- **`test_priceShock`**: Verifies the "Panic" logic where large price movements (>5%) bypass the cooldown timer.
- **`test_gasCost`**: Profiles the gas overhead added to the Uniswap swap path.

### 2. `AutomationController.t.sol` (Reactive Layer)
Simulates the Reactive Network's Lasna node analyzing events and dispatching cross-chain callbacks.
- **`test_eventDecoding`**: Validates the RVM's ability to parse raw logs into structured risk data.
- **`test_triggerOnDeltaThreshold`**: Confirms that valid risk signals generate a cross-chain dispatch.
- **`test_noTriggerBelowThreshold`**: Ensures filtering logic prevents spam callbacks for minor risks.
- **`test_cooldownProtection`**: Validates that the Reactive layer itself prevents double-dispatch during the same window.
- **`test_dispatchPayload`**: **CRITICAL**: Verifies the `abi.encode` payload matches the `callback(address,...)` signature required by the Destination chain.
- **`test_rejectInvalidEmitter`**: Security test ensuring ONLY authorized origin hooks can influence the system.

### 3. `HedgeController.t.sol` (Actuator Layer)
Tests the logic that transposes risk signals into synthetic derivative orders.
- **`testUnauthorizedCallback_Reverts`**: Security test ensuring only the Reactive Network proxy can invoke the `callback`.
- **`testExecuteHedgePositiveDelta`**: Verifies that a positive LP delta results in a **SHORT** hedge to maintain neutrality.
- **`testExecuteHedgeNegativeDelta`**: Verifies that a negative LP delta results in a **LONG** hedge.
- **`testDirectionFlipRebalance`**: Tests complex scenarios where exposure swings from Long to Short, requiring a total position reversal.
- **`testCooldownBlocksRapidHedges_Reverts`**: Validates destination-side protection against rapid-fire execution.
- **`testFuzz_HedgeMath`**: Uses property-based testing to ensure math remains accurate across a vast range of LP exposure sizes.

### 4. `MockPerpsEngine.t.sol` (Execution Layer)
Validates the deterministic ledger that tracks the synthetic derivative positions.
- **`test_OpenLongPosition` / `test_OpenShortPosition`**: Basic ledger entry validation.
- **`test_IncreaseShortPosition`**: Ensures weighted average entry price logic is accurate when scaling into a position.
- **`test_ClosePosition`**: Verifies that closures compute PnL correctly based on entry vs current price.
- **`test_PnL_ShortProfit` / `test_PnL_LongLoss`**: Series of tests validating the algebraic PnL equations for both directions.
- **`testFuzz_PnLCalculation`**: Fuzzes prices to ensure PnL never overflows or breaks accounting under extreme volatility.

---

## Infrastructure Notes

- **`MockReactiveSystem`**: A helper inside `AutomationController.t.sol` that mimics the system contract to test subscription logic.
- **`MockEventGenerator`**: Used to simulate Ethereum events without the overhead of the full Uniswap v4 environment for lighter, faster testing.
