// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {euint128, euint64, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title IMEVDetectionEngine
 * @notice Interface for FHE-based MEV detection and analysis
 */
interface IMEVDetectionEngine {
    
    struct EncryptedSwapData {
        euint128 encryptedAmount;         // Encrypted swap amount
        euint64 encryptedSlippage;        // Encrypted slippage tolerance (basis points)
        euint64 encryptedGasPrice;        // Encrypted gas price
        euint32 encryptedTimestamp;       // Encrypted timestamp
        address trader;                   // Trader address (not encrypted)
    }

    struct ThreatAssessment {
        euint64 riskScore;                // 0-100 encrypted risk score
        ebool isMevThreat;                // Boolean threat indicator
        euint64 recommendedSlippageBuffer;// Suggested additional slippage
        euint32 recommendedDelay;         // Suggested execution delay
        euint128 estimatedMevLoss;        // Estimated potential MEV loss
    }

    struct PoolMetrics {
        euint128 averageSwapSize;         // Average swap size for the pool
        euint64 averageGasPrice;          // Average gas price for recent swaps
        euint32 lastLargeSwapTimestamp;   // Timestamp of last large swap
        euint64 volatilityScore;          // Pool volatility score (0-100)
        euint128 totalVolume24h;          // Total volume in last 24 hours
    }

    /**
     * @notice Analyzes a swap for MEV threats using FHE
     * @param swapData Encrypted swap parameters
     * @param poolKey Pool identifier
     * @return threat Threat assessment with encrypted values
     */
    function analyzeSwapThreat(
        EncryptedSwapData calldata swapData,
        PoolKey calldata poolKey
    ) external returns (ThreatAssessment memory threat);

    /**
     * @notice Updates pool metrics with new swap data
     * @param poolKey Pool identifier
     * @param swapData Encrypted swap data
     */
    function updatePoolMetrics(
        PoolKey calldata poolKey,
        EncryptedSwapData calldata swapData
    ) external;

    /**
     * @notice Gets encrypted pool metrics
     * @param poolKey Pool identifier
     * @return metrics Encrypted pool metrics
     */
    function getPoolMetrics(
        PoolKey calldata poolKey
    ) external returns (PoolMetrics memory metrics);

    /**
     * @notice Calibrates detection sensitivity for a pool
     * @param poolKey Pool identifier
     * @param sensitivityLevel New sensitivity level (0-100)
     */
    function calibrateDetection(
        PoolKey calldata poolKey,
        uint8 sensitivityLevel
    ) external;

    // Events
    event DetectionCalibratedForPool(bytes32 indexed poolId, uint8 sensitivityLevel);
    event PoolMetricsUpdated(bytes32 indexed poolId);
    event ThreatAnalysisCompleted(bytes32 indexed poolId, address indexed trader);
}