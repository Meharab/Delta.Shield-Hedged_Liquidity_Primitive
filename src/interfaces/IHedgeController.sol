// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

/// @title IHedgeController Protocol Interface
/// @notice Actuator layer that translates risk signals into execution via the PerpsEngine
interface IHedgeController {
    event HedgeOpened(bytes32 indexed poolId, int256 size);
    event HedgeAdjusted(bytes32 indexed poolId, int256 newSize);
    event HedgeClosed(bytes32 indexed poolId);

    /// @notice Core execution router entry point invoked natively by the Automation layer
    /// @param poolId Identifier of the liquidity pool risk bounds breached
    /// @param lpDelta The calculated exposure of the LP (must open inverse)
    /// @param price The execution entry price point
    function executeHedge(bytes32 poolId, int256 lpDelta, uint256 price) external;

    /// @notice Exclusively rebalance existing tracking position offsets
    function rebalanceHedge(bytes32 poolId, int256 newDelta) external;

    /// @notice Liquidates and zeroes all tracking offsets bounds tied to a pool
    function closeHedge(bytes32 poolId) external;
}
