// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockPerpsEngine} from "../../src/MockPerpsEngine.sol";

contract VerifyEndToEnd is Script {
    function run() public {
        uint256 destRpc = vm.createSelectFork(vm.envString("DESTINATION_RPC"));
        address engineAddr = vm.envAddress("PERPS_ENGINE_ADDR");

        bytes32 poolId = bytes32(uint256(1)); // Matching target from TriggerHedgeFlow

        vm.selectFork(destRpc);
        MockPerpsEngine engine = MockPerpsEngine(engineAddr);

        int256 exposure = engine.getPositionExposure(poolId);

        // Verification 1: Hedge Executed
        require(exposure != 0, "FAIL: Hedge not executed. Event relay failed or proxy reverted.");

        // Verification 2: Direction Correctness
        // Our hedge trigger sent +10 ether. Ratio is 70% bounds = -7 ether.
        require(exposure == -7 ether, "FAIL: Incorrect hedge direction or sizing calculation.");

        // Verification 3: Position Persistence bounds natively mapped
        uint256 expectedPositionId = engine.poolPosition(poolId);
        (uint256 id,,,,,) = engine.positions(expectedPositionId);
        require(id != 0, "FAIL: Position not stored identically inside memory");

        console.log("End-to-End Verification Passed!");
        console.log("Final Exposure successfully synced:", exposure);
    }
}
