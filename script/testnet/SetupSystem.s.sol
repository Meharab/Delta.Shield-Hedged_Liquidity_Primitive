// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockEventGenerator} from "../../src/MockEventGenerator.sol";
import {AutomationController} from "../../src/AutomationController.sol";
import {HedgeController} from "../../src/HedgeController.sol";
import {MockPerpsEngine} from "../../src/MockPerpsEngine.sol";

contract SetupSystem is Script {
    function run() public {
        uint256 destRpc = vm.createSelectFork(vm.envString("DESTINATION_RPC"));

        address hedgeControllerAddr = vm.envAddress("HEDGE_CONTROLLER_ADDR");
        address perpsEngineAddr = vm.envAddress("PERPS_ENGINE_ADDR");

        vm.selectFork(destRpc);
        vm.startBroadcast();

        HedgeController hedge = HedgeController(payable(hedgeControllerAddr));
        MockPerpsEngine engine = MockPerpsEngine(payable(perpsEngineAddr));

        // Ensure engine is linked
        if (hedge.perpsEngine() != address(engine)) {
            hedge.setPerpsEngine(address(engine));
            console.log("Successfully linked HedgeController -> MockPerpsEngine");
        } else {
            console.log("HedgeController is already correctly configured.");
        }

        vm.stopBroadcast();

        // Validation mapping log
        bytes32 topic = keccak256("HedgeRequired(bytes32,int256,uint160,uint256)");
        console.log("Event Topic 0 Registered:", uint256(topic));
    }
}
