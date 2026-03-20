// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.26;

import {IReactive} from "../lib/reactive-lib/src/interfaces/IReactive.sol";
import {AbstractReactive} from "../lib/reactive-lib/src/abstract-base/AbstractReactive.sol";
import {ISystemContract} from "../lib/reactive-lib/src/interfaces/ISystemContract.sol";

/// @title AutomationController
/// @notice The core control system monitoring AMM Hook events and dispatching cross-chain hedge execution.
contract AutomationController is IReactive, AbstractReactive {
    // ─── Data Structures ───────────────────────────────────────────────

    struct RiskSignal {
        bytes32 poolId;
        int256 delta;
        uint160 sqrtPriceX96;
        uint256 timestamp;
    }

    // ─── Configuration ─────────────────────────────────────────────────

    uint256 public originChainId;
    uint256 public destinationChainId;
    address public callback;

    uint256 public deltaThreshold = 1e18;
    uint256 public cooldownPeriod = 60; // 60 seconds default
    uint64 private constant GAS_LIMIT = 1_000_000;

    // ─── State ─────────────────────────────────────────────────────────

    mapping(bytes32 => uint256) public lastHedgeTimestamp;

    // Address of the AMM hook to authorize specific event emitters
    address public originHookAddress;

    // ─── Custom Errors ─────────────────────────────────────────────────

    error InvalidEmitter();

    // ─── Events ────────────────────────────────────────────────────────

    event TriggerEvaluated(bytes32 poolId, int256 delta, bool shouldHedge);
    event HedgeDispatched(bytes32 poolId, int256 delta, uint256 timestamp);

    // ─── Constructor ───────────────────────────────────────────────────

    constructor(
        address _service,
        uint256 _originChainId,
        uint256 _destinationChainId,
        address _originHookAddress,
        uint256 _eventTopic,
        address _callback
    ) payable {
        service = ISystemContract(payable(_service));

        originChainId = _originChainId;
        destinationChainId = _destinationChainId;
        originHookAddress = _originHookAddress;
        callback = _callback;

        if (!vm) {
            service.subscribe(
                originChainId, originHookAddress, _eventTopic, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE
            );
        }
    }

    // ─── Required Reactive Interface ───────────────────────────────────

    /// @notice Main entry point triggered by the Reactive Network
    /// @param log Raw event intercepted by the network
    function react(LogRecord calldata log) external vmOnly {
        if (log._contract != originHookAddress) revert InvalidEmitter();

        RiskSignal memory signal = _decodeEvent(log);

        bool shouldHedge = _evaluateTrigger(signal.delta);
        emit TriggerEvaluated(signal.poolId, signal.delta, shouldHedge);

        if (shouldHedge) {
            if (_cooldownSatisfied(signal.poolId)) {
                _dispatchHedge(signal);
            }
        }
    }

    // ─── Internal Modules ──────────────────────────────────────────────

    /// @dev Module 1: Event Decoder
    /// @notice Decodes raw Reactive Network log into structured `RiskSignal`
    function _decodeEvent(LogRecord calldata log) internal pure returns (RiskSignal memory) {
        // topic1 -> poolId (indexed)
        bytes32 pId = bytes32(log.topic_1);

        // decode unindexed parameters from the data
        (int256 d, uint160 price, uint256 ts) = abi.decode(log.data, (int256, uint160, uint256));

        return RiskSignal({poolId: pId, delta: d, sqrtPriceX96: price, timestamp: ts});
    }

    /// @dev Module 2: Trigger Engine
    /// @notice Evaluates if the exposure delta requires a hedge
    function _evaluateTrigger(int256 delta) internal view returns (bool) {
        int256 absDelta = delta >= 0 ? delta : -delta;
        return uint256(absDelta) > deltaThreshold;
    }

    /// @dev Module 3: Cooldown Manager
    /// @notice Checks if enough time has passed since the last hedge
    function _cooldownSatisfied(bytes32 poolId) internal view returns (bool) {
        return block.timestamp > lastHedgeTimestamp[poolId] + cooldownPeriod;
    }

    /// @dev Module 4: CrossChain Dispatcher
    /// @notice Assembles and dispatches the execution message back to the destination chain
    function _dispatchHedge(RiskSignal memory signal) internal {
        // Update state to lock cooldown
        lastHedgeTimestamp[signal.poolId] = block.timestamp;

        // Prepare the payload targeting HedgeController's callback function via AbstractCallback logic
        bytes memory payload = abi.encodeWithSignature(
            "callback(address,bytes32,int256,uint256)",
            address(0),
            signal.poolId,
            signal.delta,
            signal.sqrtPriceX96
        );

        emit HedgeDispatched(signal.poolId, signal.delta, block.timestamp);
        emit Callback(destinationChainId, callback, GAS_LIMIT, payload);
    }
}
