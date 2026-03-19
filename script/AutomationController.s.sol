// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {AutomationController} from "../src/AutomationController.sol";

/// @title AutomationControllerScript — Deploys the DeltaShield Automation Controller
/// @dev Usage:
///   Test: forge script script/AutomationController.s.sol:AutomationControllerScript --rpc-url <RPC> --chain-id <ID>
///   Live: forge script script/AutomationController.s.sol:AutomationControllerScript --rpc-url <RPC> --chain-id <ID> --broadcast --verify
contract AutomationControllerScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        AutomationController automationController = new AutomationController(
            // Replace with Reactive System Contract address for target chain
            vm.envAddress("SYSTEM_CONTRACT_ADDR"),
            // Replace with origin chain ID (where AMMHook is deployed)
            vm.envUint("ORIGIN_CHAIN_ID"),
            // Replace with destination chain ID (where hedge execution will occur)
            vm.envUint("DESTINATION_CHAIN_ID"),
            // Replace with AMMHook contract address
            vm.envAddress("ORIGIN_ADDR"),
            // Replace with AMMHook event topic to subscribe to (HedgeRequired event)
            0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb,
            // Replace with callback contract address on destination chain
            vm.envAddress("CALLBACK_ADDR")
        );
        console.log("AutomationController deployed successfully at:", address(automationController));
    }
}
// @dev you can also deploy the AutomationController with cast:
// forge create --broadcast --rpc-url $REACTIVE_RPC --account $ACC src/AutomationController.sol:AutomationController --value 0.01ether --constructor-args $SYSTEM_CONTRACT_ADDR $ORIGIN_CHAIN_ID $DESTINATION_CHAIN_ID $ORIGIN_ADDR 0x8cabf31d2b1b11ba52dbb302817a3c9c83e4b2a5194d35121ab1354d69f6a4cb $CALLBACK_ADDR

// Example output
// Deployer: 0x55F710a5509f4a8a8fE8a41dF476e51daD401454
// Deployed to: 0x9999B3f485771b681Cf88Abfd2fD9ed36b7F69e1
// Transaction hash: 0x80cb96b70e32437ac745b61e47ec74568c73c7037cd23475381071c617e61380
