// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {AMMHook} from "../src/AMMHook.sol";

/// @title AMMHookTest — Comprehensive test suite for the DeltaShield hook
/// @dev Covers all test scenarios
contract AMMHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    MockERC20 token;

    // Native tokens are represented by address(0)
    Currency ethCurrency = Currency.wrap(address(0));
    Currency tokenCurrency;

    AMMHook hook;
    PoolId poolId;

    // ─── Events (redeclared for vm.expectEmit) ─────────────────────────

    event HedgeRequired(
        PoolId indexed poolId,
        int256 delta,
        uint160 sqrtPriceX96,
        uint256 timestamp
    );

    event ExposureUpdated(
        PoolId indexed poolId,
        int256 delta,
        uint160 sqrtPriceX96,
        uint256 timestamp
    );

    // ─── Setup ─────────────────────────────────────────────────────────

    function setUp() public {
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();

        // Deploy our TOKEN contract
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency = Currency.wrap(address(token));

        // Mint tokens
        token.mint(address(this), type(uint128).max);
        token.mint(address(1), type(uint128).max);

        // Deploy hook to an address that has the proper flags set
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG |
                Hooks.AFTER_SWAP_FLAG |
                Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );

        deployCodeTo(
            "AMMHook.sol",
            abi.encode(manager),
            address(flags)
        );
        hook = AMMHook(address(flags));

        // Approve our TOKEN for spending on the swap router and modify liquidity router
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);

        // Initialize a pool: ETH / TEST, fee = 3000, initial price = 1
        (key, ) = initPool(
            ethCurrency,
            tokenCurrency,
            hook,
            3000,
            SQRT_PRICE_1_1
        );

        poolId = key.toId();

        // Add initial liquidity around the current price
        _addLiquidity(-60, 60, 0.003 ether);
    }

    // ─── Test 1: Pool Initialization ───────────────────────────────────

    /// @notice Verify afterInitialize sets PoolState correctly.
    function test_poolInitialization() public view {
        (
            uint160 lastSqrtPriceX96,
            int256 lastDelta,
            uint256 lastHedgeTimestamp,
            uint256 deltaThreshold,
            uint256 minRebalanceInterval
        ) = hook.poolStates(poolId);

        // PoolState must exist with correct initial price
        assertGt(lastSqrtPriceX96, 0, "lastSqrtPriceX96 should be set");
        // After init + first addLiquidity, delta is updated
        // But initial afterInitialize sets delta to 0 and is then overwritten by afterAddLiquidity
        // deltaThreshold and minRebalanceInterval should be defaults
        assertEq(deltaThreshold, hook.DEFAULT_DELTA_THRESHOLD(), "threshold mismatch");
        assertEq(minRebalanceInterval, hook.DEFAULT_MIN_REBALANCE_INTERVAL(), "interval mismatch");
    }

    // ─── Test 2: Liquidity Addition ────────────────────────────────────

    /// @notice Adding liquidity must recalculate delta and emit ExposureUpdated.
    function test_liquidityAddition() public {
        // Capture state before
        (, int256 deltaBefore, , , ) = hook.poolStates(poolId);

        // Expect ExposureUpdated event
        vm.expectEmit(false, false, false, false);
        emit ExposureUpdated(poolId, 0, 0, 0);

        // Add more liquidity
        _addLiquidity(-60, 60, 0.005 ether);

        // Verify delta changed
        (, int256 deltaAfter, , , ) = hook.poolStates(poolId);
        assertGt(deltaAfter, deltaBefore, "delta should increase after adding liquidity");
    }

    // ─── Test 3: Liquidity Removal ─────────────────────────────────────

    /// @notice Removing liquidity must update poolState and recalculate delta.
    function test_liquidityRemoval() public {
        // First get current state
        (, int256 deltaBefore, , , ) = hook.poolStates(poolId);
        assertGt(deltaBefore, 0, "should have positive delta from setup liquidity");

        // Compute a small liquidity amount to remove
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);
        uint128 liqToRemove = LiquidityAmounts.getLiquidityForAmount0(
            SQRT_PRICE_1_1,
            sqrtPriceAtTickUpper,
            0.001 ether
        );

        // Expect ExposureUpdated event
        vm.expectEmit(false, false, false, false);
        emit ExposureUpdated(poolId, 0, 0, 0);

        // Remove liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: -int256(uint256(liqToRemove)),
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        // Verify delta decreased
        (, int256 deltaAfter, , , ) = hook.poolStates(poolId);
        assertLt(deltaAfter, deltaBefore, "delta should decrease after removing liquidity");
    }

    // ─── Test 4: Swap Trigger ──────────────────────────────────────────

    /// @notice A swap must trigger afterSwap, detect price change, and recalculate delta.
    function test_swapTrigger() public {
        // Capture price before swap
        (uint160 priceBefore, , , ) = manager.getSlot0(poolId);

        // Expect ExposureUpdated event
        vm.expectEmit(false, false, false, false);
        emit ExposureUpdated(poolId, 0, 0, 0);

        // Execute a swap: buy TOKEN with ETH (zeroForOne = true)
        _swap(true, 0.001 ether);

        // Verify new price different from before
        (uint160 priceAfter, , , ) = manager.getSlot0(poolId);
        assertNotEq(priceBefore, priceAfter, "price should change after swap");

        // Verify delta is updated in state
        (, int256 deltaAfter, , , ) = hook.poolStates(poolId);
        assertGt(deltaAfter, 0, "delta should be positive");
    }

    // ─── Test 5: Hedge Trigger ─────────────────────────────────────────

    /// @notice When delta exceeds threshold, HedgeRequired must be emitted.
    function test_hedgeTrigger() public {
        // We need a scenario where delta > threshold after a swap.
        // Add very large liquidity so that delta = liquidity/2 > DEFAULT_DELTA_THRESHOLD (1e18).
        _addLiquidity(-6000, 6000, 10 ether);

        // Warp time to ensure cooldown is met
        vm.warp(block.timestamp + 120);

        // Execute a swap — this should trigger HedgeRequired since liquidity/2 > 1e18
        // Check that HedgeRequired is emitted
        vm.expectEmit(false, false, false, false);
        emit HedgeRequired(poolId, 0, 0, 0);

        _swap(true, 0.1 ether);
    }

    // ─── Test 6: Threshold Hysteresis ──────────────────────────────────

    /// @notice Small swaps within the threshold band must NOT emit HedgeRequired.
    function test_thresholdHysteresis() public {
        // With the initial small liquidity (~0.003 ETH worth), delta should be well below 1e18.
        // We don't expect HedgeRequired.
        // Record logs to check no HedgeRequired emitted
        vm.recordLogs();

        _swap(true, 0.0001 ether);

        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 hedgeRequiredSelector = keccak256(
            "HedgeRequired(bytes32,int256,uint160,uint256)"
        );

        bool hedgeEmitted = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == hedgeRequiredSelector) {
                hedgeEmitted = true;
                break;
            }
        }
        assertFalse(hedgeEmitted, "HedgeRequired should not be emitted for small delta");
    }

    // ─── Test 7: Rebalance Interval ────────────────────────────────────

    /// @notice After hedge is triggered, an immediate second swap must NOT emit HedgeRequired.
    function test_rebalanceInterval() public {
        // Add large liquidity to exceed threshold
        _addLiquidity(-6000, 6000, 10 ether);

        // Warp to ensure first hedge is allowed
        vm.warp(block.timestamp + 120);

        // First swap: triggers hedge
        _swap(true, 0.1 ether);

        // Second swap immediately — should NOT trigger hedge (cooldown not elapsed)
        vm.recordLogs();
        _swap(false, 0.05 ether);

        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 hedgeRequiredSelector = keccak256(
            "HedgeRequired(bytes32,int256,uint160,uint256)"
        );

        bool secondHedge = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == hedgeRequiredSelector) {
                secondHedge = true;
                break;
            }
        }
        assertFalse(secondHedge, "second hedge should be blocked by cooldown");
    }

    // ─── Test 8: Price Shock Detection ─────────────────────────────────

    /// @notice A large swap causing price shock must emit HedgeRequired regardless of cooldown.
    function test_priceShock() public {
        // Add enough liquidity so trading can cause a large price movement
        _addLiquidity(-6000, 6000, 10 ether);

        // Warp to clear any cooldown
        vm.warp(block.timestamp + 120);

        // First trigger to set lastHedgeTimestamp
        _swap(true, 0.1 ether);

        // Now do an enormous swap that creates a price shock (>5% price move)
        // Even though we just hedged, price shock should bypass cooldown
        // We need enough liquidity-to-swap ratio for a >5% price move
        // Add narrow liquidity for the large swap to move price significantly
        _addLiquidity(-120, 120, 1 ether);

        vm.recordLogs();
        // Large swap relative to liquidity
        _swap(true, 5 ether);

        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        bytes32 hedgeRequiredSelector = keccak256(
            "HedgeRequired(bytes32,int256,uint160,uint256)"
        );

        // Check at least one HedgeRequired emitted from the large swap
        // Note: there may also be events from _addLiquidity, so we only care
        // about HedgeRequired events.
        bool shockHedge = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == hedgeRequiredSelector) {
                shockHedge = true;
                break;
            }
        }
        assertTrue(shockHedge, "price shock should emit HedgeRequired");
    }

    // ─── Test 9: Gas Cost ──────────────────────────────────────────────

    /// @notice Swap + hook execution must have acceptable gas overhead.
    function test_gasCost() public {
        _addLiquidity(-6000, 6000, 10 ether);

        // Measure gas for a swap (includes hook execution)
        uint256 gasBefore = gasleft();
        _swap(true, 0.001 ether);
        uint256 gasUsed = gasBefore - gasleft();

        // Log gas for visibility — the hook overhead should be < 40k.
        // Total swap gas will be higher due to pool logic itself.
        console.log("Total swap + hook gas:", gasUsed);

        // Sanity check: total swap should be under 300k (generous upper bound)
        assertLt(gasUsed, 300_000, "swap gas too high");
    }

    // ─── Helpers ───────────────────────────────────────────────────────

    /// @dev Adds liquidity to the pool around the given tick range.
    function _addLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint256 ethAmount
    ) internal {
        (uint160 currentSqrtPrice, , , ) = manager.getSlot0(poolId);
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(tickUpper);
        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(tickLower);

        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            currentSqrtPrice < sqrtPriceAtTickLower ? sqrtPriceAtTickLower : 
            (currentSqrtPrice > sqrtPriceAtTickUpper ? sqrtPriceAtTickUpper : currentSqrtPrice),
            sqrtPriceAtTickUpper,
            ethAmount
        );
        
        // If price is fully above the range, amount0 is 0. Give fallback liquidity from amount1.
        if (liquidityDelta == 0) {
            liquidityDelta = LiquidityAmounts.getLiquidityForAmount1(
                sqrtPriceAtTickLower,
                currentSqrtPrice > sqrtPriceAtTickUpper ? sqrtPriceAtTickUpper : 
                (currentSqrtPrice < sqrtPriceAtTickLower ? sqrtPriceAtTickLower : currentSqrtPrice),
                ethAmount // (assuming we just add a symmetric amount for testing)
            );
        }

        modifyLiquidityRouter.modifyLiquidity{value: ethAmount + 1 ether}(
            key,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    /// @dev Executes a swap on the pool.
    /// @param zeroForOne If true, swaps token0 (ETH) for token1 (TEST).
    /// @param amountIn Amount of input token.
    function _swap(bool zeroForOne, uint256 amountIn) internal {
        swapRouter.swap{value: zeroForOne ? amountIn : 0}(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne
                    ? TickMath.MIN_SQRT_PRICE + 1
                    : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ZERO_BYTES
        );
    }

}