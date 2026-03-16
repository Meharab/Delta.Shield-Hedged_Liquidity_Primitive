// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

/// @title AMMHook — DeltaShield Exposure Tracking Hook
/// @notice Uniswap v4 hook that tracks LP delta exposure and emits hedge signals.
/// @dev This hook is an observer: it never modifies swap output or transfers tokens.
///      It reads pool state, estimates LP delta (≈ liquidity / 2), and emits events
///      consumed by the Reactive Automation Layer.
contract AMMHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    // ─── Data Structures ───────────────────────────────────────────────

    /// @notice Per-pool exposure state tracked by the hook.
    struct PoolState {
        uint160 lastSqrtPriceX96;
        int256 lastDelta;
        uint256 lastHedgeTimestamp;
        uint256 deltaThreshold;
        uint256 minRebalanceInterval;
    }

    // ─── Events ────────────────────────────────────────────────────────

    /// @notice Emitted when LP exposure exceeds the hedge threshold.
    event HedgeRequired(
        PoolId indexed poolId,
        int256 delta,
        uint160 sqrtPriceX96,
        uint256 timestamp
    );

    /// @notice Emitted on every exposure update for continuous monitoring.
    event ExposureUpdated(
        PoolId indexed poolId,
        int256 delta,
        uint160 sqrtPriceX96,
        uint256 timestamp
    );

    // ─── Custom Errors ─────────────────────────────────────────────────

    /// @notice Pool has insufficient liquidity for exposure computation.
    error AMMHook__LowLiquidity();

    // ─── Constants ─────────────────────────────────────────────────────

    /// @dev Default delta threshold that triggers a hedge signal (in token0 units).
    uint256 public constant DEFAULT_DELTA_THRESHOLD = 1e18;

    /// @dev Default minimum seconds between consecutive hedge signals.
    uint256 public constant DEFAULT_MIN_REBALANCE_INTERVAL = 60;

    /// @dev Minimum pool liquidity required to compute exposure.
    uint128 public constant MIN_LIQUIDITY = 1000;

    /// @dev Price shock detection threshold in basis points (5%).
    uint256 public constant PRICE_SHOCK_BPS = 500;

    /// @dev BPS denominator.
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    // ─── Storage ───────────────────────────────────────────────────────

    /// @notice Exposure state for each tracked pool.
    mapping(PoolId => PoolState) public poolStates;

    // ─── Constructor ───────────────────────────────────────────────────

    constructor(IPoolManager _manager) BaseHook(_manager) {}

    // ─── Hook Permissions ──────────────────────────────────────────────

    /// @inheritdoc BaseHook
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: false,
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: true,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // ─── Hook Entry Points ─────────────────────────────────────────────

    /// @notice Called after a pool is initialized. Stores initial price and sets defaults.
    function _afterInitialize(
        address,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24
    ) internal override returns (bytes4) {
        PoolId id = key.toId();

        poolStates[id] = PoolState({
            lastSqrtPriceX96: sqrtPriceX96,
            lastDelta: 0,
            lastHedgeTimestamp: 0,
            deltaThreshold: DEFAULT_DELTA_THRESHOLD,
            minRebalanceInterval: DEFAULT_MIN_REBALANCE_INTERVAL
        });

        emit ExposureUpdated(id, 0, sqrtPriceX96, block.timestamp);

        return IHooks.afterInitialize.selector;
    }

    /// @notice Called after liquidity is added. Recomputes and emits exposure.
    function _afterAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _updateExposure(key);
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @notice Called after liquidity is removed. Recomputes and emits exposure.
    function _afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _updateExposure(key);
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @notice Called after every swap. Main risk detection trigger.
    /// @dev Recomputes delta, checks threshold + cooldown, and emits HedgeRequired if needed.
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId id = key.toId();
        PoolState storage state = poolStates[id];

        // Read current pool price
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(id);

        // Read current pool liquidity
        uint128 liquidity = poolManager.getLiquidity(id);

        // Skip if liquidity is too low
        if (liquidity < MIN_LIQUIDITY) {
            return (IHooks.afterSwap.selector, int128(0));
        }

        // ── Compute delta (simplified: delta ≈ liquidity / 2) ──
        int256 delta = int256(uint256(liquidity)) / 2;

        // ── Price shock detection ──
        bool priceShock = _isPriceShock(sqrtPriceX96, state.lastSqrtPriceX96);

        // ── Update stored state ──
        state.lastSqrtPriceX96 = sqrtPriceX96;
        state.lastDelta = delta;

        // ── Emit continuous monitoring event ──
        emit ExposureUpdated(id, delta, sqrtPriceX96, block.timestamp);

        // ── Evaluate hedge threshold ──
        if (priceShock || _shouldHedge(state, delta)) {
            state.lastHedgeTimestamp = block.timestamp;
            emit HedgeRequired(id, delta, sqrtPriceX96, block.timestamp);
        }

        return (IHooks.afterSwap.selector, int128(0));
    }

    // ─── Internal Helpers ──────────────────────────────────────────────

    /// @dev Reads pool state, computes delta, updates storage, and emits ExposureUpdated.
    function _updateExposure(PoolKey calldata key) internal {
        PoolId id = key.toId();
        PoolState storage state = poolStates[id];

        // Read current pool price
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(id);

        // Read current pool liquidity
        uint128 liquidity = poolManager.getLiquidity(id);

        // Compute delta (simplified: delta ≈ liquidity / 2)
        int256 delta;
        if (liquidity >= MIN_LIQUIDITY) {
            delta = int256(uint256(liquidity)) / 2;
        }

        // Update state
        state.lastSqrtPriceX96 = sqrtPriceX96;
        state.lastDelta = delta;

        emit ExposureUpdated(id, delta, sqrtPriceX96, block.timestamp);
    }

    /// @dev Returns true when LP exposure exceeds the threshold AND the cooldown has elapsed.
    function _shouldHedge(
        PoolState storage state,
        int256 delta
    ) internal view returns (bool) {
        int256 absDelta = delta >= 0 ? delta : -delta;
        bool exceedsThreshold = uint256(absDelta) > state.deltaThreshold;
        bool cooldownElapsed = block.timestamp >=
            state.lastHedgeTimestamp + state.minRebalanceInterval;

        return exceedsThreshold && cooldownElapsed;
    }

    /// @dev Returns true if the price change exceeds PRICE_SHOCK_BPS basis points.
    function _isPriceShock(
        uint160 current,
        uint160 last
    ) internal pure returns (bool) {
        if (last == 0) return false;

        uint256 diff;
        if (current > last) {
            diff = uint256(current) - uint256(last);
        } else {
            diff = uint256(last) - uint256(current);
        }

        // diff / last > PRICE_SHOCK_BPS / BPS_DENOMINATOR
        // ⟹ diff * BPS_DENOMINATOR > PRICE_SHOCK_BPS * last
        return diff * BPS_DENOMINATOR > PRICE_SHOCK_BPS * uint256(last);
    }
}