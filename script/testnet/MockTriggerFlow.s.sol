// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockEventGenerator} from "../../src/MockEventGenerator.sol";

contract MockTriggerFlow is Script {
    function run() public {
        uint256 originRpc = vm.createSelectFork(vm.envString("ORIGIN_RPC"));
        address generatorAddr = vm.envAddress("GENERATOR_ADDR");

        vm.selectFork(originRpc);
        vm.startBroadcast();

        MockEventGenerator generator = MockEventGenerator(generatorAddr);

        // Simulating the system without Uniswap dependency using deterministic bytes32 pool IDs
        // Fix PoolId mismatch natively handled through the generator mapping
        bytes32 poolId = bytes32(uint256(999));

        console.log("MockTriggerFlow: Emitting offline mock HedgeRequired event bypassed native v4 Hooks...");
        generator.emitHedgeRequired(poolId, 50 ether, 2000);
        console.log("Mock Signal Emitted. Pool ID:", uint256(poolId));

        vm.stopBroadcast();

        for (uint256 i = 0; i < 5; i++) {
            console.log("Waiting for cross-chain relay... [Delay Simulation Tick", i, "]");
        }
    }
}
