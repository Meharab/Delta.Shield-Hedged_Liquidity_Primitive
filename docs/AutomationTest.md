# Purpose

> DeltaShield Automation Layer Test Specification

This document defines the **complete testing strategy** for the Reactive Automation Layer using **Foundry**.

The goal is to validate:

* trigger correctness
* cross-chain dispatch behavior
* cooldown enforcement
* event decoding
* security protections



# Test Environment

Tests will be written in:

- `test/AutomationController.t.sol`

Using Foundry utilities:

- `forge-std/Test.sol`

Mocks used:

- `MockEventGenerator`
- `MockHedgeController`
- `MockReactiveSystem`



# Test Categories

Automation tests fall into six major categories.

1. Deployment tests
2. Event decoding tests
3. Trigger evaluation tests
4. Cooldown logic tests
5. Cross-chain dispatch tests
6. Security tests



# Deployment Tests

Ensure the automation controller initializes correctly.

### Test: constructor initialization

Verify:

1. `originChainId` stored
2. `destinationChainId` stored
3. `callback` address stored
4. `subscription` created

Example:

```solidity
testConstructorInitialization()
```



# Event Decoding Tests

Validate that Reactive logs are correctly decoded.

### Test: decode HedgeRequired event

Steps:

1. emit `HedgeRequired`
2. simulate `LogRecord`
3. call `react()`

Verify:

1. decoded `poolId` correct
2. decoded `delta` correct
3. decoded `price` correct

Example:

```solidity
testEventDecoding()
```



# Trigger Evaluation Tests

Validate trigger conditions.



### Test 1: hedge triggered when delta exceeds threshold

Setup:

```solidity
delta > threshold
```

Expected:

- dispatch occurs

Example:

```solidity
testTriggerOnDeltaThreshold()
```



### Test 2: no hedge when delta below threshold

Setup:

```solidity
delta < threshold
```

Expected:

- no dispatch

Example:

```solidity
testNoTriggerBelowThreshold()
```



# Cooldown Tests

Ensure repeated triggers are blocked.



### Test 1: cooldown prevents repeated hedge

Steps:

1. emit `HedgeRequired`
2. trigger `hedge`
3. emit `HedgeRequired` again

Expected:

- second trigger rejected

Example:

```solidity
testCooldownProtection()
```



### Test 2: hedge allowed after cooldown

Steps:

1. warp time
2. emit event again

Expected:

- hedge executed

Example:

```solidity
testCooldownExpiry()
```



# Cross-Chain Dispatch Tests

Verify correct Reactive callback behavior.



### Test 1: correct callback payload

Verify:

1. Callback emitted
2. destination chain correct
3. payload contains executeHedge

Example:

```solidity
testDispatchPayload()
```



### Test 2: gas limit respected

Verify:

- callback gas limit set correctly



# Security Tests

Automation systems must resist adversarial behavior.



### Test 1: price oscillation spam

Simulate:

- rapid swap events

Expected:

- cooldown blocks spam hedges

Example:

```solidity
testSwapSpamProtection()
```



### Test 2: low liquidity ignored

Simulate:

- liquidity below threshold

Expected:

- no trigger



### Test 3: manipulated price deviation

Simulate:

- large price deviation

Expected:

- oracle validation fails



# Fuzz Testing

Foundry fuzz tests validate robustness.

Example:

```solidity
fuzzDeltaValues(int256 delta)
```

Verify:

trigger behaves correctly across ranges



# Invariant Testing

Ensure core system invariants always hold.

Invariant:

- hedge cannot trigger within cooldown window

Invariant:

- delta threshold always respected

Example:

```solidity
invariantCooldownEnforced()
```

---

# Integration Tests

Simulate **full automation pipeline**.

```solidity
MockEventGenerator
      │
emit HedgeRequired
      │
AutomationController.react()
      │
dispatch callback
```

Verify:

- end-to-end hedge signal

Example:

```solidity
testFullAutomationFlow()
```



# Gas Profiling Tests

Automation contracts must remain efficient.

Measure:

1. `react()` gas cost
2. trigger evaluation cost
3. dispatch cost
```

Example:

```solidity
testGasReactFunction()
```



# Target Coverage

Production automation contracts should aim for:

- `≥ 95%` line coverage
- `≥ 90%` branch coverage



# Final Engineering Note

The Reactive Automation Layer is effectively a **financial control system**.

In control theory terms:

```solidity
Sensor → Controller → Actuator
```

In DeltaShield:

```solidity
AMMHook → AutomationController → HedgeController
```

That architecture turns passive AMM liquidity into something much stranger and more powerful:

**autonomous hedged capital**.