// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/**
 * @title EasyPosm
 * @notice Simplified position manager utilities for testing
 */
library EasyPosm {
    function mint(
        IPositionManager posm,
        PoolKey memory key,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient,
        uint256 deadline
    ) internal returns (uint256 tokenId) {
        // Simplified mint implementation for testing
        return 1; // Mock token ID
    }
}