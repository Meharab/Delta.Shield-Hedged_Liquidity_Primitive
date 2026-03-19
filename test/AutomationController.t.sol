// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {AutomationController} from "../src/AutomationController.sol";
import {MockEventGenerator} from "../src/MockEventGenerator.sol";
import {IReactive} from "../lib/reactive-lib/src/interfaces/IReactive.sol";

/// @title MockReactiveSystem
/// @notice Simulates the Reactive Network System Contract for subscription testing
contract MockReactiveSystem {
    event Subscribed(
        uint256 indexed chain_id,
        address indexed _contract,
        uint256 indexed topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    );

    function subscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) external {
        emit Subscribed(chain_id, _contract, topic_0, topic_1, topic_2, topic_3);
    }
}

/// @title AutomationControllerTest
/// @dev Comprehensive test suite for the DeltaShield Automation Controller
contract AutomationControllerTest is Test {
    AutomationController public controller;
    MockEventGenerator public eventGenerator;
    MockReactiveSystem public reqService;

    uint256 public constant ORIGIN_CHAIN_ID = 1;
    uint256 public constant DESTINATION_CHAIN_ID = 2;
    uint256 public constant EVENT_TOPIC = 0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb; // HedgeRequired topic0

    address public callbackAddr = address(0xDEADBEEF);

    // Test data
    bytes32 poolId = bytes32(uint256(1));
    int256 deltaThreshold;

    // ─── Setup ─────────────────────────────────────────────────────────

    function setUp() public {
        // Fix: Warp time to 1000 so the first hedge (at t=1000) will pass the cooldown check (1000 > 0 + 60)
        vm.warp(1000);

        reqService = new MockReactiveSystem();
        eventGenerator = new MockEventGenerator();

        // Standard deployment matching tests
        controller = new AutomationController(
            address(reqService),
            ORIGIN_CHAIN_ID,
            DESTINATION_CHAIN_ID,
            address(eventGenerator),
            EVENT_TOPIC,
            callbackAddr
        );

        deltaThreshold = int256(controller.deltaThreshold());

        // Foundry internal trick to bypass vmOnly modifier
        vm.store(address(controller), bytes32(0), bytes32(uint256(1)));
    }

    // ─── Test 1: Deployment Tests ──────────────────────────────────────

    function test_constructorInitialization() public {
        assertEq(controller.originChainId(), ORIGIN_CHAIN_ID);
        assertEq(controller.destinationChainId(), DESTINATION_CHAIN_ID);
        assertEq(controller.callback(), callbackAddr);
        assertEq(controller.originHookAddress(), address(eventGenerator));
    }

    // ─── Test 2: Event Decoding Tests ──────────────────────────────────

    function test_eventDecoding() public {
        int256 testDelta = 5 ether;
        uint160 price = 1000;
        uint256 ts = block.timestamp;

        // Build mock log
        IReactive.LogRecord memory log = _buildMockLog(poolId, testDelta, price, ts);

        // Expect decoding and successful evaluation event
        vm.expectEmit(true, false, false, true);
        emit AutomationController.TriggerEvaluated(poolId, testDelta, true);

        controller.react(log);
    }

    // ─── Test 3: Trigger Evaluation Tests ──────────────────────────────

    function test_triggerOnDeltaThreshold() public {
        int256 testDelta = int256(deltaThreshold) + 1; // triggers hedge
        IReactive.LogRecord memory log = _buildMockLog(poolId, testDelta, 1000, block.timestamp);

        vm.expectEmit(true, false, false, true);
        emit AutomationController.TriggerEvaluated(poolId, testDelta, true);

        vm.expectEmit(true, false, false, true);
        emit AutomationController.HedgeDispatched(poolId, testDelta, block.timestamp);

        controller.react(log);
    }

    function test_noTriggerBelowThreshold() public {
        int256 testDelta = int256(deltaThreshold) - 1; // doesn't trigger
        IReactive.LogRecord memory log = _buildMockLog(poolId, testDelta, 1000, block.timestamp);

        // Should evaluate to false
        vm.expectEmit(true, false, false, true);
        emit AutomationController.TriggerEvaluated(poolId, testDelta, false);

        // Should NOT emit Callback
        vm.recordLogs();
        controller.react(log);

        VmSafe.Log[] memory emittedLogs = vm.getRecordedLogs();
        for (uint256 i = 0; i < emittedLogs.length; i++) {
            // Callback selector
            assertNotEq(emittedLogs[i].topics[0], keccak256("Callback(uint256,address,uint64,bytes)"));
        }
    }

    function test_triggerOnNegativeDeltaThreshold() public {
        int256 testDelta = -int256(deltaThreshold) - 1; // triggers hedge (absolute value)
        IReactive.LogRecord memory log = _buildMockLog(poolId, testDelta, 1000, block.timestamp);

        vm.expectEmit(true, false, false, true);
        emit AutomationController.TriggerEvaluated(poolId, testDelta, true);

        vm.expectEmit(true, false, false, true);
        emit AutomationController.HedgeDispatched(poolId, testDelta, block.timestamp);

        controller.react(log);
    }

    // ─── Test 4: Cooldown Tests ────────────────────────────────────────

    function test_cooldownProtection() public {
        int256 testDelta = int256(deltaThreshold) + 1;
        IReactive.LogRecord memory log = _buildMockLog(poolId, testDelta, 1000, block.timestamp);

        // First trigger works
        controller.react(log);
        assertEq(controller.lastHedgeTimestamp(poolId), block.timestamp);

        // Second trigger immediately fails cooldown
        vm.recordLogs();
        controller.react(log);

        VmSafe.Log[] memory emittedLogs = vm.getRecordedLogs();
        for (uint256 i = 0; i < emittedLogs.length; i++) {
            assertNotEq(
                emittedLogs[i].topics[0],
                keccak256("Callback(uint256,address,uint64,bytes)"),
                "Repeated hedge should be blocked"
            );
        }
    }

    function test_cooldownExpiry() public {
        int256 testDelta = int256(deltaThreshold) + 1;
        IReactive.LogRecord memory log = _buildMockLog(poolId, testDelta, 1000, block.timestamp);

        // First trigger
        controller.react(log);

        // Warp time past cooldown (60 seconds)
        vm.warp(block.timestamp + 61);

        // Second trigger works
        vm.expectEmit(true, false, false, true);
        emit AutomationController.TriggerEvaluated(poolId, testDelta, true);

        vm.expectEmit(true, false, false, true);
        emit AutomationController.HedgeDispatched(poolId, testDelta, block.timestamp);

        IReactive.LogRecord memory log2 = _buildMockLog(poolId, testDelta, 1000, block.timestamp);
        controller.react(log2);
    }

    // ─── Test 5: Cross-Chain Dispatch Tests ────────────────────────────

    function test_dispatchPayload() public {
        int256 testDelta = 2 ether;
        IReactive.LogRecord memory log = _buildMockLog(poolId, testDelta, 1000, block.timestamp);

        bytes memory expectedPayload = abi.encodeWithSignature("executeHedge(bytes32,int256)", poolId, testDelta);

        vm.expectEmit(true, false, false, true);
        emit AutomationController.TriggerEvaluated(poolId, testDelta, true);

        vm.expectEmit(true, false, false, true);
        emit AutomationController.HedgeDispatched(poolId, testDelta, block.timestamp);

        vm.expectEmit(true, true, true, true);
        emit IReactive.Callback(
            DESTINATION_CHAIN_ID,
            callbackAddr,
            1_000_000, // GAS_LIMIT
            expectedPayload
        );

        controller.react(log);
    }

    // ─── Test 6: Security Tests ────────────────────────────────────────

    function test_rejectInvalidEmitter() public {
        IReactive.LogRecord memory log = _buildMockLog(poolId, 2 ether, 1000, block.timestamp);
        // Change emitter to unauthorized address
        log._contract = address(0xDEAD);

        vm.expectRevert(AutomationController.InvalidEmitter.selector);
        controller.react(log);
    }

    // ─── Gas Profiling ─────────────────────────────────────────────────

    function test_gasReactFunction() public {
        IReactive.LogRecord memory log = _buildMockLog(poolId, 2 ether, 1000, block.timestamp);

        uint256 startGas = gasleft();
        controller.react(log);
        uint256 endGas = gasleft();

        console.log("react() execution cost:", startGas - endGas);
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    function _buildMockLog(bytes32 pId, int256 delta, uint160 price, uint256 ts)
        internal
        view
        returns (IReactive.LogRecord memory)
    {
        return IReactive.LogRecord({
            chain_id: ORIGIN_CHAIN_ID,
            _contract: address(eventGenerator),
            topic_0: EVENT_TOPIC,
            topic_1: uint256(pId),
            topic_2: 0,
            topic_3: 0,
            data: abi.encode(delta, price, ts),
            block_number: block.number,
            op_code: 0,
            block_hash: uint256(blockhash(block.number - 1)),
            tx_hash: uint256(keccak256("test_tx")),
            log_index: 0
        });
    }
}
