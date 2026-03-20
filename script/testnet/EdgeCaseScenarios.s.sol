// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockEventGenerator} from "../../src/MockEventGenerator.sol";

contract EdgeCaseScenarios is Script {
    function run() public {
        uint256 originRpc = vm.createSelectFork(vm.envString("ORIGIN_RPC"));
        address generatorAddr = vm.envAddress("GENERATOR_ADDR");

        vm.selectFork(originRpc);
        vm.startBroadcast();
        MockEventGenerator generator = MockEventGenerator(generatorAddr);
        
        bytes32 poolId = bytes32(uint256(42));

        console.log("=== Edge Case Scenarios Execution ===");

        // Case 1: Small delta (no hedge execution expected)
        console.log("Case 1: Small Delta (0.1 ETH)");
        generator.emitHedgeRequired(poolId, 0.1 ether, 2000); // 0.1e18 < 1e18 threshold bounds
        console.log("-> Expect: NO hedge execution natively ignored by TriggerEvaluated");

        // Case 3: Large delta spike
        console.log("\nCase 3: Large Delta Spike (100 ETH)");
        generator.emitHedgeRequired(poolId, 100 ether, 2000);
        console.log("-> Expect: Immediate cross-chain hedge execution payload emitted");

        // Case 2: Cooldown violation
        // Executing back-to-back triggers for the same pool id inside the 60s window
        console.log("\nCase 2: Cooldown Violation (100 ETH back-to-back)");
        generator.emitHedgeRequired(poolId, 100 ether, 2000);
        console.log("-> Expect: Second hedge BLOCKED by AutomationController due to Active Cooldown");

        // Case 4: Invalid emitter
        console.log("\nCase 4: Invalid Emitter simulation via unauthenticated calls");
        console.log("-> Expect: Revert InvalidEmitter() on Lasna when parsed by AutomationController React node.");

        vm.stopBroadcast();
    }
}
