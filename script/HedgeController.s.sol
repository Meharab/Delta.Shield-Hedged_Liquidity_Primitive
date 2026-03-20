// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockPerpsEngine} from "../src/MockPerpsEngine.sol";
import {HedgeController} from "../src/HedgeController.sol";

/// @title HedgeControllerScript
/// @notice Unified sequential deployment script tying the Mock Engine and HedgeController together
contract HedgeControllerScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();

        address callbackProxyAddress = vm.envOr("CALLBACK_PROXY_ADDR", address(0x123)); // Placeholder
        address assetAddress = vm.envOr("ASSET_ADDR", address(0x456)); // Placeholder
        uint256 cooldown = vm.envOr("HEDGE_COOLDOWN", uint256(60)); // 60s
        uint256 ratio = vm.envOr("HEDGE_RATIO", uint256(0.7e18)); // 70%

        // Pre-compute the execution address to initialize circular authorization
        address expectedController = vm.computeCreateAddress(msg.sender, vm.getNonce(msg.sender) + 1);

        MockPerpsEngine engine = new MockPerpsEngine(expectedController);

        HedgeController controller =
            new HedgeController(callbackProxyAddress, assetAddress, cooldown, ratio);
        controller.setPerpsEngine(address(engine));

        console.log("System Callback Proxy Target:", callbackProxyAddress);
        console.log("Linked MockPerpsEngine deployed at:", address(engine));
        console.log("Linked HedgeController deployed at:", address(controller));
    }
}
