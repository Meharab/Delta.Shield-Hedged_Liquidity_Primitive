// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.26;

import '../../../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../../../lib/reactive-lib/src/abstract-base/AbstractReactive.sol';
import '../../../lib/reactive-lib/src/interfaces/ISystemContract.sol';

contract AutomationController is IReactive, AbstractReactive {

    uint256 public originChainId;
    uint256 public destinationChainId;
    uint64 private constant GAS_LIMIT = 1000000;

    address private callback;

    constructor(
        address _service,            // Replace with Reactive System Contract address for target chain
        uint256 _originChainId,      // Replace with origin chain ID (where AMMHook is deployed)
        uint256 _destinationChainId, // Replace with destination chain ID (where hedge execution will occur)
        address _contract,           // Replace with AMMHook contract address
        uint256 _topic_0,            // Replace with AMMHook event topic to subscribe to (HedgeRequired event)
        address _callback            // Replace with callback contract address on destination chain 
    ) payable {
        service = ISystemContract(payable(_service));

        originChainId = _originChainId;
        destinationChainId = _destinationChainId;
        callback = _callback;

        if (!vm) {
            service.subscribe(
                originChainId,
                _contract,
                _topic_0,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
        }
    }

    // This function will be called by the Reactive System when a subscribed event is emitted on the origin chain.
    function react(LogRecord calldata log) external vmOnly {
        if (log.topic_3 > 0) {
            bytes memory payload = abi.encodeWithSignature("callback(address)", address(0));
            emit Callback(destinationChainId, callback, GAS_LIMIT, payload);
        }
    }
}