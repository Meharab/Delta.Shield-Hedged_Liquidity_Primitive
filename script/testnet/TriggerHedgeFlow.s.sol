// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockEventGenerator} from "../../src/MockEventGenerator.sol";

contract TriggerHedgeFlow is Script {
    function run() public {
        uint256 originRpc = vm.createSelectFork(vm.envString("ORIGIN_RPC"));
        address generatorAddr = vm.envAddress("GENERATOR_ADDR");

        vm.selectFork(originRpc);
        vm.startBroadcast();

        MockEventGenerator generator = MockEventGenerator(generatorAddr);

        bytes32 poolId = bytes32(uint256(1));
        int256 delta = 10 ether; // Triggers a 7 ETH Short (-7 ether exposure)
        uint160 price = 2000;

        console.log("Emitting Risk Signal on Origin Chain...");
        generator.emitHedgeRequired(poolId, delta, price);
        console.log("Signal Emitted. Pool ID:", uint256(poolId));
        console.log("Delta Required:", delta);

        vm.stopBroadcast();

        // CRITICAL CONSTRAINTS: Simulate async Reactive Network execution
        // We inherently cannot wait for synchronous execution, cross-chain bounds apply delay
        for (uint256 i = 0; i < 5; i++) {
            console.log("Waiting for cross-chain relay... [Delay Simulation Tick", i, "]");
        }

        console.log("\n============================================================");
        console.log("CRITICAL ACTIONS REQUIRED MANUALLY ON TESTNET RPC EXPORERS:");
        console.log("1. Check AutomationController (Lasna RPC) for `TriggerEvaluated` / `HedgeDispatched`.");
        console.log("2. Check HedgeController (Unichain RPC) execution success via Callback event log.");
        console.log("============================================================");
    }
}
