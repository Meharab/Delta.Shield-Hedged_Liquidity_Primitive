// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.8.26;

import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';

contract HedgeController is AbstractCallback {
    event CallbackReceived(
        address indexed origin,
        address indexed sender,
        address indexed reactive_sender
    );

    /// @param _callback_sender is the $DESTINATION_CALLBACK_PROXY_ADDR 0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4 for Unichan Sepolia. Visit https://dev.reactive.network/origins-and-destinations to learn how to get the callback proxy address for other chains or testnets.
    /// @dev Must send some Unichain testnet native token to this contract to pay for the callback execution fee when the callback is triggered from the RVM.
    constructor(address _callback_sender) AbstractCallback(_callback_sender) payable {}

    /// @dev This function will be called by the callback proxy contract when the callback is triggered from the RVM.
    function callback(address sender)
        external
        authorizedSenderOnly
        rvmIdOnly(sender)
    {
        emit CallbackReceived(
            tx.origin,
            msg.sender,
            sender
        );
    }
}
