# DeltaShield Cross-Chain Testnet Execution Guide

This directory contains the necessary scripts to deploy, configure, and verify the DeltaShield protocol across multiple testnets using the **Reactive Network** as the asynchronous event relay.

## Prerequisites

1.  **Foundry**: Ensure you have Foundry installed.
2.  **Environment Variables**: Copy `.env.example` to `.env` and fill in your private key and RPC URLs.
3.  **Funding**: 
    *   **Ethereum Sepolia**: ETH for deployment of `MockEventGenerator`.
    *   **Unichain Sepolia**: UNI for `HedgeController` callback fees.
    *   **Reactive Lasna**: REACT for `AutomationController` subscription fees.

## Execution Order

Follow these steps in order to ensure the system is correctly wired.

### 1. Deployment phase

Deploy the entire architecture across three chains (Ethereum, Reactive, Unichain).

```bash
forge script script/testnet/DeployAll.s.sol --broadcast --account $ACC
```

**Note**: After deployment, the script will output contract addresses. Save these! You will need them for the subsequent steps.

### 2. Setup & Wiring

Ensure the `HedgeController` is correctly linked to the `MockPerpsEngine` and verify the event topics.

Update your `.env` with:
- `HEDGE_CONTROLLER_ADDR`
- `PERPS_ENGINE_ADDR`

```bash
forge script script/testnet/SetupSystem.s.sol --broadcast --account $ACC
```

### 3. Triggering a Hedge Flow

Simulate a "breach" on the origin chain (Ethereum Sepolia) to trigger the Reactive Network.

Update your `.env` with:
- `GENERATOR_ADDR` (MockEventGenerator address from step 1)

```bash
forge script script/testnet/TriggerHedgeFlow.s.sol --broadcast --account $ACC
```

### 4. Verification

Verify that the hedge was successfully executed on the destination chain (Unichain Sepolia) after the async relay delay.

```bash
forge script script/testnet/VerifyEndToEnd.s.sol --rpc-url $DESTINATION_RPC --account $ACC
```

## Specialized Scenarios

### Mock Trigger (Isolated)
Test the system without external Uniswap dependencies (uses purely the MockEventGenerator).

```bash
forge script script/testnet/MockTriggerFlow.s.sol --broadcast --account $ACC
```

### Edge Case Validation
Validate the system's resilience against small deltas, cooldown violations, and large spikes.

```bash
forge script script/testnet/EdgeCaseScenarios.s.sol --broadcast --account $ACC
```

## Important Considerations

*   **Asynchronous Nature**: The Reactive Network is NOT synchronous. There is a delay between the event on Ethereum and the callback on Unichain.
*   **Funding**: If scripts fail with "Insufficient funds", ensure the `AutomationController` (Lasna) and `HedgeController` (Unichain) have sufficient native tokens.
*   **Callbacks**: The `HedgeController` must have Unichain ETH/UNI to pay the callback execution fee when the Reactive Network triggers it.
