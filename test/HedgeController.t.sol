// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {HedgeController} from "../src/HedgeController.sol";
import {MockPerpsEngine} from "../src/MockPerpsEngine.sol";
import {IHedgeController} from "../src/interfaces/IHedgeController.sol";

contract HedgeControllerTest is Test {
    HedgeController public controller;
    MockPerpsEngine public engine;

    bytes32 constant poolId = bytes32(uint256(1));
    address constant automationSender = address(0xAA);
    address constant asset = address(0xBB);
    uint256 constant cooldown = 60;
    uint256 constant ratio = 0.7e18; // 70%

    function setUp() public {
        vm.warp(1000);

        // Pre-compute the exact address where the HedgeController will be deployed
        // Since we are creating engine first from `this` contract, and controller immediately after.
        address expectedController = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        engine = new MockPerpsEngine(expectedController);
        controller = new HedgeController(automationSender, asset, cooldown, ratio);
        controller.setPerpsEngine(address(engine));
    }

    // --- 1. Deployment Tests ---
    function testDeployController() public {
        // assertEq(controller.automationController(), automationSender); // Replaced by AbstractCallback proxy vendor tracking
        assertEq(controller.perpsEngine(), address(engine));
        assertEq(controller.asset(), asset);
        assertEq(controller.hedgeCooldown(), cooldown);
        assertEq(controller.hedgeRatio(), ratio);
    }

    // --- 2. Callback Authorization Tests ---
    function testUnauthorizedCallback_Reverts() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(bytes("Authorized sender only"));
        controller.callback(address(this), poolId,  10 ether, 2000);
    }

    // --- 3. Hedge Execution Tests ---
    function testExecuteHedgePositiveDelta() public {
        vm.prank(automationSender);

        vm.expectEmit(true, false, false, true);
        emit IHedgeController.HedgeOpened(poolId, -7 ether); // +10e18 * 0.7 = -7e18 short

        controller.callback(address(this), poolId,  10 ether, 2000);

        assertEq(engine.getPositionExposure(poolId), -7 ether);
        assertEq(controller.lastDelta(poolId), -7 ether);
        assertTrue(controller.hedgePositions(poolId) != 0);
    }

    function testExecuteHedgeNegativeDelta() public {
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  -10 ether, 2000);

        assertEq(engine.getPositionExposure(poolId), 7 ether); // -10e18 * 0.7 = +7e18 extended long
    }

    // --- 4. Rebalancing Tests ---
    function testRebalanceIncreaseExposure() public {
        // Step 1: Execute hedge for +10 ETH => -7 ETH Short
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  10 ether, 2000);

        assertEq(engine.getPositionExposure(poolId), -7 ether);

        // Advance bypass cooldown
        vm.warp(block.timestamp + 61);

        // Step 2: Exposure climbs to +20 ETH => -14 ETH Short Target
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  20 ether, 2000);

        assertEq(engine.getPositionExposure(poolId), -14 ether); // correctly scaled down with sizeDiff
    }

    function testRebalanceDecreaseExposure() public {
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  20 ether, 2000); // Expects -14 ETH
        assertEq(engine.getPositionExposure(poolId), -14 ether);

        vm.warp(block.timestamp + 61);

        // Drops back to +10 ETH => shrinks backwards to -7 ETH short
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  10 ether, 2000);

        assertEq(engine.getPositionExposure(poolId), -7 ether);
    }

    function testDirectionFlipRebalance() public {
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  10 ether, 2000); // Expects -7 ETH
        assertEq(engine.getPositionExposure(poolId), -7 ether);

        vm.warp(block.timestamp + 61);

        // Utterly swing from +10 exposure to -10 exposure => Target is +7 ETH
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  -10 ether, 2000);

        assertEq(engine.getPositionExposure(poolId), 7 ether);
    }

    // --- 5. Close Hedge Tests ---
    function testCloseHedge() public {
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  10 ether, 2000);

        vm.warp(block.timestamp + 61);

        vm.expectEmit(true, false, false, true);
        emit IHedgeController.HedgeClosed(poolId);

        vm.prank(automationSender);
        controller.callback(address(this), poolId,  0, 2000); // 0 exposure should gracefully wind down

        assertEq(engine.getPositionExposure(poolId), 0);
        assertEq(controller.hedgePositions(poolId), 0);
    }

    // --- 6. Cooldown Tests ---
    function testCooldownBlocksRapidHedges_Reverts() public {
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  10 ether, 2000);

        // Immediately executing again within the 60 second bounding period
        vm.prank(automationSender);
        vm.expectRevert(HedgeController.CooldownActive.selector);
        controller.callback(address(this), poolId,  12 ether, 2010);
    }

    // --- 7. Edge Case Tests ---
    function testZeroDeltaInitialization() public {
        // Should harmlessly bypass mapping allocations
        vm.prank(automationSender);
        controller.callback(address(this), poolId,  0, 2000);

        assertEq(controller.hedgePositions(poolId), 0);
    }

    // --- 8. Fuzz Tests ---
    function testFuzz_HedgeMath(int256 exposure) public {
        vm.assume(exposure > -1e30 && exposure < 1e30);

        vm.prank(automationSender);
        controller.callback(address(this), poolId,  exposure, 2000);

        int256 targetSize = (-exposure * int256(ratio)) / 1e18;
        assertEq(engine.getPositionExposure(poolId), targetSize);
    }
}
