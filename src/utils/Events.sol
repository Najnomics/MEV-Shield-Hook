// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

/**
 * @title Events
 * @notice Event definitions for MEV Shield Hook system
 */
library Events {
    
    // ============ Hook Events ============
    
    /**
     * @notice Emitted when MEV protection is applied to a swap
     * @param poolId Pool identifier
     * @param trader Address of the trader
     * @param riskScore Risk score that triggered protection (0-100)
     * @param slippageBuffer Applied slippage buffer (basis points)
     * @param executionDelay Applied execution delay (blocks)
     * @param estimatedSavings Estimated MEV savings (wei)
     */
    event MEVProtectionApplied(
        PoolId indexed poolId,
        address indexed trader,
        uint64 riskScore,
        uint64 slippageBuffer,
        uint32 executionDelay,
        uint128 estimatedSavings
    );
    
    /**
     * @notice Emitted when a MEV threat is detected
     * @param poolId Pool identifier
     * @param trader Address of the trader
     * @param threatType Type of MEV threat detected
     * @param riskScore Risk score (0-100)
     * @param estimatedLoss Estimated potential loss if unprotected (wei)
     */
    event MEVThreatDetected(
        PoolId indexed poolId,
        address indexed trader,
        uint8 indexed threatType,
        uint64 riskScore,
        uint128 estimatedLoss
    );
    
    /**
     * @notice Emitted when pool protection configuration is updated
     * @param poolId Pool identifier
     * @param admin Address that updated the configuration
     * @param threshold New protection threshold
     * @param maxSlippageBuffer New maximum slippage buffer
     * @param maxExecutionDelay New maximum execution delay
     */
    event PoolProtectionConfigured(
        PoolId indexed poolId,
        address indexed admin,
        uint64 threshold,
        uint64 maxSlippageBuffer,
        uint32 maxExecutionDelay
    );
    
    // ============ Detection Engine Events ============
    
    /**
     * @notice Emitted when detection algorithm is calibrated
     * @param poolId Pool identifier
     * @param calibrator Address that performed calibration
     * @param sensitivityLevel New sensitivity level (0-100)
     * @param previousLevel Previous sensitivity level
     */
    event DetectionCalibrated(
        PoolId indexed poolId,
        address indexed calibrator,
        uint8 sensitivityLevel,
        uint8 previousLevel
    );
    
    /**
     * @notice Emitted when pool metrics are updated
     * @param poolId Pool identifier
     * @param updateType Type of metric updated
     * @param blockNumber Block number of update
     */
    event PoolMetricsUpdated(
        PoolId indexed poolId,
        uint8 indexed updateType,
        uint256 blockNumber
    );
    
    /**
     * @notice Emitted when threat analysis is completed
     * @param poolId Pool identifier
     * @param trader Address analyzed
     * @param analysisType Type of analysis performed
     * @param result Analysis result
     */
    event ThreatAnalysisCompleted(
        PoolId indexed poolId,
        address indexed trader,
        uint8 indexed analysisType,
        bool result
    );
    
    // ============ Protection Mechanism Events ============
    
    /**
     * @notice Emitted when slippage protection is applied
     * @param poolId Pool identifier
     * @param trader Address of the trader
     * @param originalSlippage Original slippage tolerance
     * @param adjustedSlippage Adjusted slippage tolerance
     * @param protectionBuffer Applied protection buffer
     */
    event SlippageProtectionApplied(
        PoolId indexed poolId,
        address indexed trader,
        uint64 originalSlippage,
        uint64 adjustedSlippage,
        uint64 protectionBuffer
    );
    
    /**
     * @notice Emitted when timing protection is applied
     * @param poolId Pool identifier
     * @param trader Address of the trader
     * @param originalBlock Original execution block
     * @param delayedBlock Delayed execution block
     * @param delayBlocks Number of blocks delayed
     */
    event TimingProtectionApplied(
        PoolId indexed poolId,
        address indexed trader,
        uint256 originalBlock,
        uint256 delayedBlock,
        uint32 delayBlocks
    );
    
    /**
     * @notice Emitted when gas price is optimized
     * @param poolId Pool identifier
     * @param trader Address of the trader
     * @param originalGasPrice Original gas price
     * @param optimizedGasPrice Optimized gas price
     * @param optimizationFactor Factor applied
     */
    event GasPriceOptimized(
        PoolId indexed poolId,
        address indexed trader,
        uint64 originalGasPrice,
        uint64 optimizedGasPrice,
        uint64 optimizationFactor
    );
    
    // ============ Analytics Events ============
    
    /**
     * @notice Emitted when swap metrics are updated
     * @param poolId Pool identifier
     * @param trader Address of the trader
     * @param riskScore Risk score of the swap
     * @param mevSavings MEV savings achieved
     * @param wasProtected Whether protection was applied
     */
    event SwapMetricsUpdated(
        PoolId indexed poolId,
        address indexed trader,
        uint64 riskScore,
        uint128 mevSavings,
        bool wasProtected
    );
    
    /**
     * @notice Emitted when user analytics are updated
     * @param user User address
     * @param poolId Pool identifier
     * @param totalSavings Updated total savings
     * @param swapsProtected Updated number of protected swaps
     */
    event UserAnalyticsUpdated(
        address indexed user,
        PoolId indexed poolId,
        uint128 totalSavings,
        uint128 swapsProtected
    );
    
    /**
     * @notice Emitted when threat profile is updated
     * @param poolId Pool identifier
     * @param threatType Type of threat
     * @param frequency Updated frequency
     * @param severity Updated severity
     */
    event ThreatProfileUpdated(
        PoolId indexed poolId,
        uint8 indexed threatType,
        uint64 frequency,
        uint64 severity
    );
    
    /**
     * @notice Emitted when global effectiveness is calculated
     * @param timeWindow Time window for calculation
     * @param totalSwaps Total swaps analyzed
     * @param protectedSwaps Number of protected swaps
     * @param effectiveness Calculated effectiveness (0-100)
     */
    event GlobalEffectivenessCalculated(
        uint256 timeWindow,
        uint256 totalSwaps,
        uint256 protectedSwaps,
        uint64 effectiveness
    );
    
    // ============ Permission & Access Events ============
    
    /**
     * @notice Emitted when analytics permissions are granted
     * @param poolId Pool identifier
     * @param grantor Address that granted permission
     * @param grantee Address that received permission
     * @param permissionType Type of permission granted
     */
    event AnalyticsPermissionGranted(
        PoolId indexed poolId,
        address indexed grantor,
        address indexed grantee,
        uint8 permissionType
    );
    
    /**
     * @notice Emitted when analytics permissions are revoked
     * @param poolId Pool identifier
     * @param revoker Address that revoked permission
     * @param revokee Address that lost permission
     * @param permissionType Type of permission revoked
     */
    event AnalyticsPermissionRevoked(
        PoolId indexed poolId,
        address indexed revoker,
        address indexed revokee,
        uint8 permissionType
    );
    
    /**
     * @notice Emitted when metrics decryption is requested
     * @param poolId Pool identifier
     * @param requester Address requesting decryption
     * @param metricsType Type of metrics to decrypt
     * @param requestId Unique request identifier
     */
    event MetricsDecryptionRequested(
        PoolId indexed poolId,
        address indexed requester,
        uint8 indexed metricsType,
        bytes32 requestId
    );
    
    /**
     * @notice Emitted when metrics decryption is completed
     * @param poolId Pool identifier
     * @param requester Address that requested decryption
     * @param metricsType Type of metrics decrypted
     * @param requestId Unique request identifier
     * @param success Whether decryption was successful
     */
    event MetricsDecryptionCompleted(
        PoolId indexed poolId,
        address indexed requester,
        uint8 indexed metricsType,
        bytes32 requestId,
        bool success
    );
    
    // ============ System Events ============
    
    /**
     * @notice Emitted when system configuration is updated
     * @param admin Address that updated configuration
     * @param configType Type of configuration updated
     * @param oldValue Previous value
     * @param newValue New value
     */
    event SystemConfigurationUpdated(
        address indexed admin,
        uint8 indexed configType,
        uint256 oldValue,
        uint256 newValue
    );
    
    /**
     * @notice Emitted when system is paused or unpaused
     * @param admin Address that changed pause state
     * @param isPaused New pause state
     * @param reason Reason for pause/unpause
     */
    event SystemPauseStateChanged(
        address indexed admin,
        bool isPaused,
        string reason
    );
}