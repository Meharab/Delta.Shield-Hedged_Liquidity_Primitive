// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockPerpsEngine} from "../src/MockPerpsEngine.sol";
import {IPerpsEngine} from "../src/interfaces/IPerpsEngine.sol";

contract MockPerpsEngineTest is Test {
    MockPerpsEngine public engine;

    bytes32 constant poolId = bytes32(uint256(1));
    bytes32 constant poolId2 = bytes32(uint256(2));
    address constant asset = address(0xAA);

    function setUp() public {
        // This test contract acts as the authorized controller
        engine = new MockPerpsEngine(address(this));
    }

    // --- 1. Deployment Tests ---
    function test_EngineDeployment() public {
        assertEq(engine.controller(), address(this));
        assertEq(engine.nextPositionId(), 1);
    }

    // --- 2. Position Creation Tests ---
    function test_OpenLongPosition() public {
        vm.expectEmit(true, true, false, true);
        emit IPerpsEngine.PositionOpened(1, poolId, 5 ether, 2000);

        uint256 id = engine.openPosition(poolId, asset, 5 ether, 2000);
        assertEq(id, 1);

        (uint256 pId, bytes32 pPool, address pAsset, int256 pSize, uint256 pPrice, uint256 pTimestamp) = _getPos(id);
        assertEq(pId, 1);
        assertEq(pPool, poolId);
        assertEq(pAsset, asset);
        assertEq(pSize, 5 ether);
        assertEq(pPrice, 2000);
        assertEq(pTimestamp, block.timestamp);
    }

    function test_OpenShortPosition() public {
        engine.openPosition(poolId, asset, -5 ether, 2000);
        (,,, int256 pSize,,) = _getPos(1);
        assertEq(pSize, -5 ether);
    }

    function test_MultiplePositionCreation() public {
        uint256 id1 = engine.openPosition(poolId, asset, 5 ether, 2000);
        uint256 id2 = engine.openPosition(poolId2, asset, -3 ether, 2100);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    // --- 3. Position Update Tests ---
    function test_IncreaseShortPosition() public {
        uint256 id = engine.openPosition(poolId, asset, -5 ether, 2000);

        vm.expectEmit(true, false, false, true);
        emit IPerpsEngine.PositionUpdated(id, -8 ether);

        engine.increasePosition(id, -3 ether, 1500);

        (,,, int256 pSize, uint256 pPrice,) = _getPos(id);
        assertEq(pSize, -8 ether);
        // Cost: (-5 * 2000) + (-3 * 1500) = -10000 - 4500 = -14500
        // New price: -14500 / -8 = 1812.5 => 1812 (integer division)
        assertEq(pPrice, 1812);
    }

    function test_IncreaseLongPosition() public {
        uint256 id = engine.openPosition(poolId, asset, 5 ether, 2000);
        engine.increasePosition(id, 2 ether, 3000);
        (,,, int256 pSize, uint256 pPrice,) = _getPos(id);
        assertEq(pSize, 7 ether);
        // Cost: 10000 + 6000 = 16000 / 7 = 2285
        assertEq(pPrice, 2285);
    }

    // --- 4. Position Reduction Tests ---
    function test_DecreaseShortPosition() public {
        uint256 id = engine.openPosition(poolId, asset, -8 ether, 2000);
        engine.decreasePosition(id, 3 ether);
        (,,, int256 pSize,,) = _getPos(id);
        assertEq(pSize, -5 ether);
    }

    function test_DecreaseLongPosition() public {
        uint256 id = engine.openPosition(poolId, asset, 8 ether, 2000);
        engine.decreasePosition(id, -3 ether);
        (,,, int256 pSize,,) = _getPos(id);
        assertEq(pSize, 5 ether);
    }

    // --- 5. Position Closure Tests ---
    function test_ClosePosition() public {
        uint256 id = engine.openPosition(poolId, asset, -5 ether, 2000);

        vm.expectEmit(true, false, false, true);
        emit IPerpsEngine.PositionClosed(id, 2500 * 10 ** 18); // pnl of -5 * (1500 - 2000) = 2500

        engine.closePosition(id, 1500);

        (uint256 pId,,,,,) = _getPos(id);
        assertEq(pId, 0); // Deleted
        assertEq(engine.poolPosition(poolId), 0);
    }

    function test_CloseInvalidPosition_Reverts() public {
        vm.expectRevert(MockPerpsEngine.InvalidPosition.selector);
        engine.closePosition(999, 1000);
    }

    // --- 6. PnL Computation Tests ---
    function test_PnL_ShortProfit() public {
        uint256 id = engine.openPosition(poolId, asset, -5 ether, 2000);
        int256 pnl = engine.calculatePnL(id, 1500);
        assertEq(pnl, 2500 ether);
    }

    function test_PnL_ShortLoss() public {
        uint256 id = engine.openPosition(poolId, asset, -5 ether, 2000);
        int256 pnl = engine.calculatePnL(id, 2500);
        assertEq(pnl, -2500 ether);
    }

    function test_PnL_LongProfit() public {
        uint256 id = engine.openPosition(poolId, asset, 5 ether, 2000);
        int256 pnl = engine.calculatePnL(id, 2500);
        assertEq(pnl, 2500 ether);
    }

    function test_PnL_LongLoss() public {
        uint256 id = engine.openPosition(poolId, asset, 5 ether, 2000);
        int256 pnl = engine.calculatePnL(id, 1500);
        assertEq(pnl, -2500 ether);
    }

    // --- 7. Exposure Query Tests ---
    function test_GetPositionExposure() public {
        engine.openPosition(poolId, asset, -5 ether, 2000);
        assertEq(engine.getPositionExposure(poolId), -5 ether);
    }

    function test_GetExposure_NoPosition() public {
        assertEq(engine.getPositionExposure(poolId), 0);
    }

    // --- 8. Security Tests ---
    function test_OpenPositionUnauthorized_Reverts() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert(MockPerpsEngine.Unauthorized.selector);
        engine.openPosition(poolId, asset, 5, 1000);
    }

    function test_UpdateUnauthorized_Reverts() public {
        uint256 id = engine.openPosition(poolId, asset, 5, 1000);
        vm.prank(address(0xDEAD));
        vm.expectRevert(MockPerpsEngine.Unauthorized.selector);
        engine.increasePosition(id, 2, 1000);
    }

    function test_CloseUnauthorized_Reverts() public {
        uint256 id = engine.openPosition(poolId, asset, 5, 1000);
        vm.prank(address(0xDEAD));
        vm.expectRevert(MockPerpsEngine.Unauthorized.selector);
        engine.closePosition(id, 1000);
    }

    // --- 9. Edge Case Tests ---
    function test_OpenZeroSize_Reverts() public {
        vm.expectRevert(MockPerpsEngine.InvalidSize.selector);
        engine.openPosition(poolId, asset, 0, 1000);
    }

    function test_DecreaseMoreThanPosition() public {
        uint256 id = engine.openPosition(poolId, asset, -5 ether, 2000);
        // Decrease by 10
        engine.decreasePosition(id, 10 ether);

        // Should close position
        (uint256 pId,,,,,) = _getPos(id);
        assertEq(pId, 0);
    }

    function test_DuplicatePoolPosition_Reverts() public {
        engine.openPosition(poolId, asset, -5 ether, 2000);
        vm.expectRevert(MockPerpsEngine.PositionAlreadyExists.selector);
        engine.openPosition(poolId, asset, 10 ether, 2000);
    }

    // --- 10. Fuzz Testing ---
    function testFuzz_PnLCalculation(int256 size, uint256 entryPrice, uint256 currentPrice) public {
        vm.assume(size != 0 && size > -1e30 && size < 1e30);
        // Prevents overflow in fuzzing
        vm.assume(entryPrice > 0 && entryPrice < 1e18);
        vm.assume(currentPrice > 0 && currentPrice < 1e18);

        uint256 id = engine.openPosition(poolId, asset, size, entryPrice);
        int256 pnl = engine.calculatePnL(id, currentPrice);

        int256 expectedPnL = size * (int256(currentPrice) - int256(entryPrice));
        assertEq(pnl, expectedPnL);
    }

    function testFuzz_PositionSizeIntegrity(int256 sizeDelta) public {
        vm.assume(sizeDelta != 0 && sizeDelta > -1e30 && sizeDelta < 1e30);

        uint256 id = engine.openPosition(poolId, asset, 100 ether, 2000);
        if (sizeDelta > 0) {
            engine.increasePosition(id, sizeDelta, 2000);
            (,,, int256 pSize,,) = _getPos(id);
            assertEq(pSize, 100 ether + sizeDelta);
        } else {
            // sizeDelta is negative => reduction
            if (sizeDelta <= -100 ether) {
                engine.decreasePosition(id, sizeDelta);
                (uint256 pId,,,,,) = _getPos(id);
                assertEq(pId, 0);
            } else {
                engine.decreasePosition(id, sizeDelta);
                (,,, int256 pSize,,) = _getPos(id);
                assertEq(pSize, 100 ether + sizeDelta);
            }
        }
    }

    // Helper
    function _getPos(uint256 _id)
        internal
        view
        returns (uint256 id, bytes32 pId, address a, int256 s, uint256 ep, uint256 ts)
    {
        (id, pId, a, s, ep, ts) = engine.positions(_id);
    }
}
