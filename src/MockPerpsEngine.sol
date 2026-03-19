// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IPerpsEngine} from "./interfaces/IPerpsEngine.sol";

/// @title MockPerpsEngine
/// @notice A minimal synthetic derivatives ledger for managing and tracking the protocol's directional exposure
contract MockPerpsEngine is IPerpsEngine {
    error Unauthorized();
    error InvalidSize();
    error InvalidPosition();
    error PositionAlreadyExists();

    address public immutable controller;
    uint256 public nextPositionId;

    mapping(uint256 => Position) public positions;
    mapping(bytes32 => uint256) public poolPosition;

    modifier onlyController() {
        if (msg.sender != controller) revert Unauthorized();
        _;
    }

    constructor(address _controller) {
        controller = _controller;
        nextPositionId = 1; // Start IDs at 1 so 0 is null/empty
    }

    /// @inheritdoc IPerpsEngine
    function openPosition(bytes32 poolId, address asset, int256 size, uint256 price)
        external
        onlyController
        returns (uint256)
    {
        if (size == 0) revert InvalidSize();
        if (poolPosition[poolId] != 0) revert PositionAlreadyExists();

        uint256 positionId = nextPositionId++;

        Position memory newPosition = Position({
            id: positionId, poolId: poolId, asset: asset, size: size, entryPrice: price, timestamp: block.timestamp
        });

        positions[positionId] = newPosition;
        poolPosition[poolId] = positionId;

        emit PositionOpened(positionId, poolId, size, price);

        return positionId;
    }

    /// @inheritdoc IPerpsEngine
    function increasePosition(uint256 positionId, int256 sizeDelta, uint256 price) external onlyController {
        if (sizeDelta == 0) revert InvalidSize();
        Position storage position = positions[positionId];
        if (position.id == 0) revert InvalidPosition();

        // Enforce direction match (both positive or both negative)
        if ((position.size > 0 && sizeDelta < 0) || (position.size < 0 && sizeDelta > 0)) {
            revert InvalidSize();
        }

        int256 oldSize = position.size;
        uint256 oldEntry = position.entryPrice;
        int256 newSize = oldSize + sizeDelta;

        // Weighted average entry price calculation:
        // entry = (oldSize * oldEntry + delta * price) / (oldSize + delta)
        // Note: oldSize and sizeDelta have the same sign, so the math works gracefully.
        int256 totalCost = (oldSize * int256(oldEntry)) + (sizeDelta * int256(price));
        int256 newEntryPrice = totalCost / newSize;

        position.size = newSize;
        position.entryPrice = uint256(newEntryPrice);

        emit PositionUpdated(positionId, newSize);
    }

    /// @inheritdoc IPerpsEngine
    function decreasePosition(uint256 positionId, int256 sizeDelta) external onlyController {
        if (sizeDelta == 0) revert InvalidSize();
        Position storage position = positions[positionId];
        if (position.id == 0) revert InvalidPosition();

        // If decreasing, the delta must have the opposite sign of the position (or just conceptually push size towards 0)
        // Example: size = -8, sizeDelta = +3 -> newSize = -5.
        // If sizeDelta goes past 0 (e.g. -8 + 10 = +2), we just close the position completely.

        int256 newSize = position.size + sizeDelta;

        if ((position.size > 0 && newSize <= 0) || (position.size < 0 && newSize >= 0)) {
            // Oversized reduction closes the position (passing 0 for price since we don't have it here... Wait.
            // If we don't have price, we can't emit true PnL for the closed position.
            // In our system design, the controller usually just calls closeHedge and explicitly closes it if 0.
            // For a decrease that crosses zero, we will just set size to 0 and conceptually treat it as fully reduced.
            position.size = 0;
            emit PositionUpdated(positionId, 0);
            _closePosition(positionId, 0); // Gracefully close with 0 PnL, or rely on explicit closePosition calls.
        } else {
            position.size = newSize;
            emit PositionUpdated(positionId, newSize);
        }
    }

    /// @inheritdoc IPerpsEngine
    function closePosition(uint256 positionId, uint256 closingPrice) external onlyController {
        if (positions[positionId].id == 0) revert InvalidPosition();
        _closePosition(positionId, closingPrice);
    }

    function _closePosition(uint256 positionId, uint256 closingPrice) internal {
        Position memory position = positions[positionId];

        int256 pnl = 0;
        if (closingPrice != 0 && position.size != 0) {
            pnl = _computePnL(position.size, position.entryPrice, closingPrice);
        }

        // Clean up mappings
        delete poolPosition[position.poolId];
        delete positions[positionId];

        emit PositionClosed(positionId, pnl);
    }

    /// @inheritdoc IPerpsEngine
    function getPositionExposure(bytes32 poolId) external view returns (int256) {
        uint256 positionId = poolPosition[poolId];
        if (positionId == 0) return 0;
        return positions[positionId].size;
    }

    /// @inheritdoc IPerpsEngine
    function calculatePnL(uint256 positionId, uint256 currentPrice) external view returns (int256) {
        Position memory position = positions[positionId];
        if (position.id == 0) return 0;
        return _computePnL(position.size, position.entryPrice, currentPrice);
    }

    function _computePnL(int256 size, uint256 entryPrice, uint256 currentPrice) internal pure returns (int256) {
        // PnL = size * (currentPrice - entryPrice)
        return size * (int256(currentPrice) - int256(entryPrice));
    }
}
