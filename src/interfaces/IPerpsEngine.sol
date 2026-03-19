// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

/// @title IPerpsEngine
/// @notice Minimal deterministic perpetual exposure ledger for hackathon system
interface IPerpsEngine {
    struct Position {
        uint256 id;
        bytes32 poolId;
        address asset;
        int256 size;
        uint256 entryPrice;
        uint256 timestamp;
    }

    event PositionOpened(uint256 indexed positionId, bytes32 indexed poolId, int256 size, uint256 entryPrice);
    event PositionUpdated(uint256 indexed positionId, int256 newSize);
    event PositionClosed(uint256 indexed positionId, int256 pnl);

    /// @notice Initiates a synthetic derivative position
    function openPosition(bytes32 poolId, address asset, int256 size, uint256 price)
        external
        returns (uint256 positionId);

    /// @notice Upsizes mathematical net exposure
    function increasePosition(uint256 positionId, int256 sizeDelta, uint256 price) external;

    /// @notice Downsizes mathematical net exposure
    function decreasePosition(uint256 positionId, int256 sizeDelta) external;

    /// @notice Neutralizes all synthetic bounds matching the ID
    function closePosition(uint256 positionId, uint256 closingPrice) external;

    /// @notice Reads standard un-leveraged directional delta
    function getPositionExposure(bytes32 poolId) external view returns (int256);

    /// @notice Computes stateless theoretical deterministic profit and loss offset
    function calculatePnL(uint256 positionId, uint256 currentPrice) external view returns (int256);
}
