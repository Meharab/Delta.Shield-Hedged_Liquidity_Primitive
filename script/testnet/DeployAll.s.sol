// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockEventGenerator} from "../../src/MockEventGenerator.sol";
import {AutomationController} from "../../src/AutomationController.sol";
import {HedgeController} from "../../src/HedgeController.sol";
import {MockPerpsEngine} from "../../src/MockPerpsEngine.sol";

contract DeployAll is Script {
    function run() public {
        uint256 originRpc = vm.createSelectFork(vm.envString("ORIGIN_RPC"));
        uint256 destRpc = vm.createSelectFork(vm.envString("DESTINATION_RPC"));
        uint256 reactiveRpc = vm.createSelectFork(vm.envString("REACTIVE_RPC"));

        uint256 originChainId = vm.envUint("ORIGIN_CHAIN_ID");
        uint256 destChainId = vm.envUint("DESTINATION_CHAIN_ID");

        address systemContract = vm.envAddress("SYSTEM_CONTRACT_ADDR");
        address callbackProxy = vm.envAddress("DESTINATION_CALLBACK_PROXY_ADDR");
        address assetAddress = vm.envOr("ASSET_ADDR", address(0x456));

        uint256 topic0 = uint256(keccak256("HedgeRequired(bytes32,int256,uint160,uint256)"));

        // 1. ORIGIN CHAIN (Ethereum Sepolia)
        vm.selectFork(originRpc);
        vm.startBroadcast();
        MockEventGenerator generator = new MockEventGenerator();
        // Note: Skipping full v4 AMMHook to avoid heavy IPoolManager requirements purely for testnet MVP
        vm.stopBroadcast();

        // 2. DESTINATION CHAIN (Unichain Sepolia)
        vm.selectFork(destRpc);
        vm.startBroadcast();

        // Circular dependency broken via setters
        HedgeController hedge = new HedgeController{value: 0.0005 ether}(
            callbackProxy,
            assetAddress,
            60, // cooldown
            0.7e18 // ratio
        );

        MockPerpsEngine engine = new MockPerpsEngine(address(hedge));
        // Link the hedge controller directly on deployment
        hedge.setPerpsEngine(address(engine));

        vm.stopBroadcast();

        // 3. REACTIVE CHAIN (Lasna)
        vm.selectFork(reactiveRpc);
        vm.startBroadcast();
        AutomationController automation = new AutomationController{value: 0.01 ether}(
            systemContract, originChainId, destChainId, address(generator), topic0, address(hedge)
        );
        vm.stopBroadcast();

        // LOGGING
        console.log("MockEventGenerator:", address(generator));
        console.log("AutomationController:", address(automation));
        console.log("HedgeController:", address(hedge));
        console.log("MockPerpsEngine:", address(engine));
    }
}
