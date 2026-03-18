// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {HedgeController} from "../src/HedgeController.sol";

/// @title HedgeControllerScript — Deploys the DeltaShield Hedge Controller
/// @dev Usage:
///   Test: forge script script/HedgeController.s.sol:HedgeControllerScript --rpc-url <RPC> --chain-id <ID>
///   Live: forge script script/HedgeController.s.sol:HedgeControllerScript --rpc-url <RPC> --chain-id <ID> --broadcast --verify
contract HedgeControllerScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        HedgeController hedgeController = new HedgeController(
            // Replace with Reactive Callback Proxy Contract address for target chain
            vm.envAddress("DESTINATION_CALLBACK_PROXY_ADDR")
        );
        console.log("HedgeController deployed successfully at:", address(hedgeController));
    }
}
/// @dev you can also deploy the HedgeController with cast:
// forge create --broadcast --rpc-url $DESTINATION_RPC --account $ACC src/HedgeController.sol:HedgeController --value 0.0001ether --constructor-args $DESTINATION_CALLBACK_PROXY_ADDR 

// Example output
// Deployer: 0x55F710a5509f4a8a8fE8a41dF476e51daD401454
// Deployed to: 0x9999B3f485771b681Cf88Abfd2fD9ed36b7F69e1
// Transaction hash: 0xe3d8d81b11a3d9128a092e3d441d2f3c65736bf5de8147afd6cc35de29ef3aed