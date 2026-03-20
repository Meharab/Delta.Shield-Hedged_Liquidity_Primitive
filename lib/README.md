# DeltaShield Libraries & Dependencies

This directory contains the external smart contract libraries and framework extensions used by the DeltaShield protocol.

## Installation & Setup

DeltaShield uses **Foundry** for dependency management. To install or update the libraries, run:

```bash
# Install all submodules
git submodule update --init --recursive

# Alternatively, using Forge directly
forge install
```

---

## Dependency Breakdown

### 1. `reactive-lib`
**Source**: [Reactive-Network/reactive-lib](https://github.com/Reactive-Network/reactive-lib)
**Significance**: The backbone of the asynchronous automation layer.
*   **Usage**: Provides `AbstractReactive` for the brain and `AbstractCallback` for the actuator.
*   **Critical Files**: `IReactive.sol` (event structures), `ISystemContract.sol` (subscription logic).

### 2. `v4-periphery` & `v4-core`
**Source**: [Uniswap/v4-periphery](https://github.com/Uniswap/v4-periphery)
**Significance**: Official Uniswap v4 suite.
*   **Usage**: `v4-periphery` provides the base for routers and manager interactions. It internally contains `v4-core`, which defines the `IPoolManager` and core types (`PoolKey`, `BalanceDelta`, `Currency`).
*   **Critical Files**: `IPoolManager.sol`, `TickMath.sol`, `PoolId.sol`.

### 3. `v4-hooks-public`
**Source**: [Uniswap/v4-hooks-public](https://github.com/Uniswap/v4-hooks-public)
**Significance**: Development utilities for Uniswap v4 Hooks.
*   **Usage**: Provides `BaseHook.sol`, which simplifies the implementation of custom hook logic by handling permission flags and interface compliance.
*   **Critical Files**: `BaseHook.sol`, `HookMiner.sol` (used in deployment scripts).

### 4. `forge-std`
**Source**: [foundry-rs/forge-std](https://github.com/foundry-rs/forge-std)
**Significance**: The standard testing framework for Foundry.
*   **Usage**: Powering the entire `test/` suite with `Test.sol`, `console.log`, and `Vm.sol` cheatcodes.
*   **Critical Files**: `Test.sol`, `Script.sol`.

### 5. `chainlink-brownie-contracts`
**Source**: [smartcontractkit/chainlink-brownie-contracts](https://github.com/smartcontractkit/chainlink-brownie-contracts)
**Significance**: Industry-standard Oracle interfaces.
*   **Usage**: Provides the `AggregatorV3Interface.sol` used for price validation and secondary risk checks (currently mapped in `src/AggregatorV3.sol`).

---

## Nested Dependencies & Remappings

DeltaShield uses a complex dependency tree where some libraries are nested within others to ensure version compatibility (e.g., `v4-core` is inside `v4-periphery`). 

Refer to the project's [remappings.txt](../remappings.txt) to see exactly how these paths are resolved by the compiler.

### Example Remapping Logic:
```text
v4-core/=lib/v4-periphery/lib/v4-core/src/
solmate/=lib/v4-periphery/lib/v4-core/lib/solmate/
```
