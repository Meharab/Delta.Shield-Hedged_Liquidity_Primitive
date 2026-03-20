# DeltaShield Deployment Scripts

This directory contains the Foundry Solidity scripts used to deploy and configure the individual components of the DeltaShield protocol.

## Core Component Scripts

These scripts are used to deploy individual contracts in isolation or linked pairs.

### 1. AMM Hook Deployment (`AMMHook.s.sol`)
Mines a CREATE2 salt to ensure the hook is deployed at an address with the required Uniswap v4 flag permissions.
- **Target**: Ethereum Mainnet/Testnet (where Uniswap v4 is deployed).
- **Execution**:
  ```bash
  forge script script/AMMHook.s.sol:AMMHookScript --rpc-url $ORIGIN_RPC --broadcast --account $ACC
  ```

### 2. Automation Controller Deployment (`AutomationController.s.sol`)
Deploys the Reactive Network's "Brain" which listens for risk events.
- **Target**: Reactive Network (Lasna).
- **Execution**:
  ```bash
  forge script script/AutomationController.s.sol:AutomationControllerScript --rpc-url $REACTIVE_RPC --broadcast --account $ACC
  ```

### 3. Unified Hedge Deployment (`HedgeController.s.sol`)
Deploy both the `HedgeController` and the `MockPerpsEngine` in a single transaction, correctly linking their authorization paths.
- **Target**: Unichain Sepolia / Arbitrum (Destination execution layer).
- **Execution**:
  ```bash
  forge script script/HedgeController.s.sol:HedgeControllerScript --rpc-url $DESTINATION_RPC --broadcast --account $ACC
  ```

### 4. Standalone Perps Engine (`MockPerpsEngine.s.sol`)
Standalone deployment of the ledger engine (primarily for debugging or manual testing).
```bash
forge script script/MockPerpsEngine.s.sol:MockPerpsEngineScript --rpc-url $DESTINATION_RPC --broadcast --account $ACC
```

---

## Complex Multi-Chain Orchestration (`/testnet`)

For a full end-to-end system test involving cross-chain relays, refer to the [Testnet Directory](./testnet/README.md).

The `testnet` folder contains specialized scripts to:
- **DeployAll**: Orchestrate deployment across 3 different RPC forks in one command.
- **SetupSystem**: Retroactively wire asynchronous components together.
- **TriggerFlow**: Simulate a risk event on Ethereum and trace it through the Reactive relay.
- **Verify**: Mathematically validate that the hedge was executed correctly on the destination chain.

---

## Environment Variable Checklist

Before running any script, ensure your `.env` contains:
```env
ACC=your_foundry_account
ORIGIN_RPC=...
DESTINATION_RPC=...
REACTIVE_RPC=...
SYSTEM_CONTRACT_ADDR=...
DESTINATION_CALLBACK_PROXY_ADDR=...
```
Refer to `.env.example` for the full list of required parameters.
