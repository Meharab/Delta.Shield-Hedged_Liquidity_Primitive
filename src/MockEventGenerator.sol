// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.26;

/// @title MockEventGenerator
/// @notice A simple contract to emit HedgeRequired events for testing the Reactive Automation Layer.
/// @dev This contract bridges the gap between the complex v4 PoolManager and the AutomationController.
/// @dev It uses explicit uint256 for the PoolId to avoid deep imports from Uniswap v4-core in a pure test environment.
///      PoolId in Uniswap v4 is a bytes32 wrapper, so uint256 is fully compatible for event emission and testing.
contract MockEventGenerator {
    event HedgeRequired(uint256 indexed poolId, int256 delta, uint160 sqrtPriceX96, uint256 timestamp);

    function emitHedgeRequired(uint256 _poolId, int256 _delta, uint160 _sqrtPriceX96) external {
        emit HedgeRequired(_poolId, _delta, _sqrtPriceX96, block.timestamp);
    }
}
