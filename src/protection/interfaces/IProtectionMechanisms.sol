// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {euint64, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title IProtectionMechanisms
 * @notice Interface for MEV protection mechanisms
 */
interface IProtectionMechanisms {
    
    struct ProtectionConfig {
        euint64 baseSlippageBuffer;       // Base protection buffer (basis points)
        euint32 baseExecutionDelay;       // Base execution delay (blocks)
        euint64 gasOptimizationFactor;    // Gas price adjustment factor
        ebool isAdaptive;                 // Whether to use adaptive protection
    }

    struct ProtectionResult {
        ebool wasProtected;               // Whether protection was applied
        euint64 appliedSlippageBuffer;    // Actual slippage buffer applied
        euint32 appliedDelay;             // Actual execution delay applied
        euint64 adjustedGasPrice;         // Adjusted gas price
    }

    /**
     * @notice Applies dynamic protection based on threat assessment
     * @param poolKey Pool identifier
     * @param params Swap parameters to protect
     * @param recommendedSlippageBuffer Recommended slippage buffer from detection
     * @param recommendedDelay Recommended execution delay from detection
     * @return result Protection application result
     */
    function applyDynamicProtection(
        PoolKey calldata poolKey,
        SwapParams memory params,
        euint64 recommendedSlippageBuffer,
        euint32 recommendedDelay
    ) external returns (ProtectionResult memory result);

    /**
     * @notice Configures protection parameters for a specific pool
     * @param poolKey Pool identifier
     * @param config Protection configuration
     */
    function configurePoolProtection(
        PoolKey calldata poolKey,
        ProtectionConfig calldata config
    ) external;

    /**
     * @notice Applies slippage protection to swap parameters
     * @param params Swap parameters to adjust
     * @param slippageBuffer Additional slippage buffer (basis points)
     * @return adjustedParams Modified swap parameters
     */
    function applySlippageProtection(
        SwapParams memory params,
        euint64 slippageBuffer
    ) external returns (SwapParams memory adjustedParams);

    /**
     * @notice Applies timing protection by introducing execution delay
     * @param poolKey Pool identifier
     * @param executionDelay Delay in blocks
     * @return canExecute Whether the swap can execute now
     * @return earliestBlock Earliest block for execution
     */
    function applyTimingProtection(
        PoolKey calldata poolKey,
        euint32 executionDelay
    ) external returns (ebool canExecute, uint256 earliestBlock);

    /**
     * @notice Optimizes gas price to prevent front-running
     * @param currentGasPrice Current gas price
     * @param optimizationFactor Optimization factor
     * @return optimizedGasPrice Adjusted gas price
     */
    function optimizeGasPrice(
        euint64 currentGasPrice,
        euint64 optimizationFactor
    ) external returns (euint64 optimizedGasPrice);

    /**
     * @notice Gets protection configuration for a pool
     * @param poolKey Pool identifier
     * @return config Current protection configuration
     */
    function getPoolProtectionConfig(
        PoolKey calldata poolKey
    ) external returns (ProtectionConfig memory config);

    /**
     * @notice Calculates protection effectiveness score
     * @param poolKey Pool identifier
     * @param timeWindow Time window for calculation (in blocks)
     * @return effectivenessScore Score from 0-100
     */
    function calculateProtectionEffectiveness(
        PoolKey calldata poolKey,
        uint256 timeWindow
    ) external returns (euint64 effectivenessScore);

    // Events
    event ProtectionApplied(
        bytes32 indexed poolId, 
        address indexed trader,
        uint64 slippageBuffer,
        uint32 executionDelay
    );

    event ProtectionConfigUpdated(
        bytes32 indexed poolId,
        uint64 baseSlippageBuffer,
        uint32 baseExecutionDelay
    );

    event GasPriceOptimized(
        bytes32 indexed poolId,
        address indexed trader,
        uint64 originalGasPrice,
        uint64 optimizedGasPrice
    );
}