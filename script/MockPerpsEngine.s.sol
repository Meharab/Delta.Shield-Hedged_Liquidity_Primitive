// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockPerpsEngine} from "../src/MockPerpsEngine.sol";

/// @title MockPerpsEngineScript
/// @notice Standalone deployment script for the Mock Perpetual Engine
contract MockPerpsEngineScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        // For standalone deployment, assigns the EOA deployer as the authorized controller
        MockPerpsEngine engine = new MockPerpsEngine(msg.sender);
        console.log("Standalone MockPerpsEngine deployed successfully at:", address(engine));
    }
}
