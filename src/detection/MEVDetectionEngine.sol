// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {FHE, euint128, euint64, euint32, ebool, InEuint128, InEuint64, InEuint32} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

import {IMEVDetectionEngine} from "../hooks/interfaces/IMEVDetectionEngine.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title MEVDetectionEngine
 * @notice FHE-based MEV detection and threat analysis engine
 * @dev Analyzes encrypted transaction patterns to detect sandwich attacks and other MEV
 */
contract MEVDetectionEngine is IMEVDetectionEngine {
    using PoolIdLibrary for PoolKey;
    using FHE for uint256;

    // ============ State Variables ============

    /// @notice Pool metrics for MEV analysis
    mapping(PoolId => PoolMetrics) public poolMetrics;
    
    /// @notice Detection sensitivity per pool (0-100)
    mapping(PoolId => uint8) public detectionSensitivity;
    
    /// @notice Historical swap data for pattern analysis
    mapping(PoolId => HistoricalSwapData[]) private swapHistory;
    
    /// @notice Authorized addresses that can update metrics
    mapping(address => bool) public authorizedUpdaters;
    
    /// @notice Pool initialization status
    mapping(PoolId => bool) public poolInitialized;

    /// @notice Contract owner
    address public owner;

    /// @notice System pause state
    bool public paused;

    // ============ Constants ============

    /// @notice Maximum number of historical swaps to store per pool
    uint256 private constant MAX_HISTORY_SIZE = 100;
    
    /// @notice Default detection sensitivity
    uint8 private constant DEFAULT_SENSITIVITY = 75;

    // ============ Structs ============

    struct HistoricalSwapData {
        euint128 amount;
        euint64 gasPrice;
        euint32 timestamp;
        euint64 computedRisk;
        bool wasProtected;
    }

    struct RiskFactors {
        euint64 sizeRisk;        // Risk from swap size relative to pool
        euint64 timingRisk;      // Risk from timing patterns
        euint64 gasRisk;         // Risk from gas price patterns
        euint64 volatilityRisk;  // Risk from pool volatility
    }

    // ============ Modifiers ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert Errors.Unauthorized(msg.sender, owner);
        _;
    }

    modifier onlyAuthorized() {
        if (!authorizedUpdaters[msg.sender] && msg.sender != owner) {
            revert Errors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Errors.SystemPaused();
        _;
    }

    modifier poolExists(PoolKey calldata poolKey) {
        PoolId poolId = poolKey.toId();
        if (!poolInitialized[poolId]) revert Errors.PoolNotInitialized(PoolId.unwrap(poolId));
        _;
    }

    // ============ Constructor ============

    constructor() {
        owner = msg.sender;
        authorizedUpdaters[msg.sender] = true;
    }

    // ============ External Functions ============

    /**
     * @notice Initialize a pool for MEV detection
     * @param poolKey Pool identifier
     */
    function initializePool(PoolKey calldata poolKey) external {
        PoolId poolId = poolKey.toId();
        
        if (poolInitialized[poolId]) {
            return; // Already initialized
        }
        
        // Initialize pool metrics with default values
        poolMetrics[poolId] = PoolMetrics({
            averageSwapSize: FHE.asEuint128(0),
            averageGasPrice: FHE.asEuint64(50 * 1e9), // Default 50 gwei
            lastLargeSwapTimestamp: FHE.asEuint32(0),
            volatilityScore: FHE.asEuint64(0),
            totalVolume24h: FHE.asEuint128(0)
        });
        
        // Set up FHE permissions
        FHE.allowThis(poolMetrics[poolId].averageSwapSize);
        FHE.allowThis(poolMetrics[poolId].averageGasPrice);
        FHE.allowThis(poolMetrics[poolId].lastLargeSwapTimestamp);
        FHE.allowThis(poolMetrics[poolId].volatilityScore);
        FHE.allowThis(poolMetrics[poolId].totalVolume24h);
        
        // Set default sensitivity
        detectionSensitivity[poolId] = DEFAULT_SENSITIVITY;
        
        // Mark as initialized
        poolInitialized[poolId] = true;
        
        emit Events.PoolMetricsUpdated(poolId, 1, block.number);
    }

    /**
     * @inheritdoc IMEVDetectionEngine
     */
    function analyzeSwapThreat(
        EncryptedSwapData calldata swapData,
        PoolKey calldata poolKey
    ) external override whenNotPaused poolExists(poolKey) returns (ThreatAssessment memory) {
        PoolId poolId = poolKey.toId();
        PoolMetrics memory metrics = poolMetrics[poolId];

        // Calculate individual risk factors
        RiskFactors memory risks = _calculateRiskFactors(swapData, metrics);

        // Combine risk factors into overall score
        euint64 overallRisk = _combineRiskFactors(risks);

        // Apply sensitivity adjustment
        euint64 adjustedRisk = _applySensitivityAdjustment(overallRisk, poolId);

        // Determine if this is a MEV threat
        ebool isThreat = FHE.gte(adjustedRisk, FHE.asEuint64(Constants.DEFAULT_PROTECTION_THRESHOLD));

        // Calculate protection recommendations
        (euint64 slippageBuffer, euint32 executionDelay) = _calculateProtectionRecommendations(
            adjustedRisk, 
            swapData
        );

        // Estimate potential MEV loss
        euint128 estimatedLoss = _estimateMevLoss(swapData, adjustedRisk, metrics);

        return ThreatAssessment({
            riskScore: adjustedRisk,
            isMevThreat: isThreat,
            recommendedSlippageBuffer: slippageBuffer,
            recommendedDelay: executionDelay,
            estimatedMevLoss: estimatedLoss
        });
    }

    /**
     * @inheritdoc IMEVDetectionEngine
     */
    function updatePoolMetrics(
        PoolKey calldata poolKey,
        EncryptedSwapData calldata swapData
    ) external override onlyAuthorized whenNotPaused {
        PoolId poolId = poolKey.toId();
        
        if (!poolInitialized[poolId]) {
            _initializePool(poolId);
        }

        PoolMetrics storage metrics = poolMetrics[poolId];
        
        // Update running averages using FHE operations
        _updateRunningAverages(metrics, swapData);
        
        // Update volatility score
        _updateVolatilityScore(metrics, swapData);
        
        // Store historical data
        _storeHistoricalData(poolId, swapData);
        
        emit Events.PoolMetricsUpdated(poolId, 0, block.number);
    }

    /**
     * @inheritdoc IMEVDetectionEngine
     */
    function getPoolMetrics(
        PoolKey calldata poolKey
    ) external override returns (PoolMetrics memory) {
        return poolMetrics[poolKey.toId()];
    }

    /**
     * @inheritdoc IMEVDetectionEngine
     */
    function calibrateDetection(
        PoolKey calldata poolKey,
        uint8 sensitivityLevel
    ) external override onlyAuthorized {
        if (sensitivityLevel > 100) revert Errors.InvalidSensitivityLevel(sensitivityLevel);
        
        PoolId poolId = poolKey.toId();
        uint8 oldLevel = detectionSensitivity[poolId];
        detectionSensitivity[poolId] = sensitivityLevel;
        
        emit Events.DetectionCalibrated(poolId, msg.sender, sensitivityLevel, oldLevel);
    }

    // ============ Internal Risk Analysis Functions ============

    function _calculateRiskFactors(
        EncryptedSwapData calldata swapData,
        PoolMetrics memory metrics
    ) internal returns (RiskFactors memory) {
        return RiskFactors({
            sizeRisk: _analyzeSizeRisk(swapData.encryptedAmount, metrics.averageSwapSize),
            timingRisk: _analyzeTimingRisk(swapData.encryptedTimestamp, metrics.lastLargeSwapTimestamp),
            gasRisk: _analyzeGasRisk(swapData.encryptedGasPrice, metrics.averageGasPrice),
            volatilityRisk: _analyzeVolatilityRisk(metrics.volatilityScore)
        });
    }

    function _analyzeSizeRisk(
        euint128 swapAmount,
        euint128 averageSize
    ) internal returns (euint64) {
        // Calculate ratio: swapAmount / averageSize
        euint128 ratio = FHE.div(swapAmount, averageSize);
        
        // Convert to risk score (0-100)
        // If ratio > 5x average, risk = 100
        // If ratio < 0.5x average, risk = 10
        euint128 maxRatio = FHE.asEuint128(500); // 5x in percentage
        euint128 ratioPct = FHE.mul(ratio, FHE.asEuint128(100));
        
        // High risk for very large swaps
        ebool isVeryLarge = FHE.gte(ratioPct, maxRatio);
        euint64 highRisk = FHE.asEuint64(100);
        
        // Medium risk calculation for normal range
        euint64 mediumRisk = FHE.asEuint64(
            FHE.div(
                FHE.mul(ratioPct, FHE.asEuint128(80)), // Max 80 for normal swaps
                FHE.asEuint128(300) // 3x average = 80 risk
            )
        );
        
        // Minimum risk for small swaps
        euint64 minRisk = FHE.asEuint64(10);
        
        return FHE.select(
            isVeryLarge,
            highRisk,
            FHE.select(
                FHE.gte(ratioPct, FHE.asEuint128(50)), // Above 0.5x average
                mediumRisk,
                minRisk
            )
        );
    }

    function _analyzeTimingRisk(
        euint32 currentTimestamp,
        euint32 lastLargeTimestamp
    ) internal returns (euint64) {
        // Calculate time difference
        euint32 timeDiff = FHE.sub(currentTimestamp, lastLargeTimestamp);
        
        // High risk if within MEV analysis window
        euint32 riskWindow = FHE.asEuint32(Constants.MEV_ANALYSIS_WINDOW * Constants.SECONDS_PER_BLOCK);
        
        ebool withinRiskWindow = FHE.lte(timeDiff, riskWindow);
        
        // Calculate inverse risk - closer to recent large swap = higher risk
        euint64 maxRisk = FHE.asEuint64(90);
        euint64 calculatedRisk = FHE.asEuint64(
            FHE.div(
                FHE.mul(
                    FHE.sub(riskWindow, timeDiff),
                    FHE.asEuint32(90)
                ),
                riskWindow
            )
        );
        
        return FHE.select(withinRiskWindow, calculatedRisk, FHE.asEuint64(5));
    }

    function _analyzeGasRisk(
        euint64 currentGasPrice,
        euint64 averageGasPrice
    ) internal returns (euint64) {
        // Calculate gas price ratio
        euint64 gasRatio = FHE.div(
            FHE.mul(currentGasPrice, FHE.asEuint64(100)),
            averageGasPrice
        );
        
        // High risk for significantly elevated gas prices (indication of MEV competition)
        euint64 mevGasThreshold = FHE.asEuint64(Constants.MIN_MEV_GAS_PREMIUM);
        
        ebool isElevatedGas = FHE.gte(gasRatio, mevGasThreshold);
        
        // Calculate risk based on how much gas price exceeds average
        euint64 excessRatio = FHE.sub(gasRatio, FHE.asEuint64(100));
        euint64 gasRisk = FHE.div(
            FHE.mul(excessRatio, FHE.asEuint64(2)), // 2x multiplier for gas risk
            FHE.asEuint64(1)
        );
        
        // Cap at maximum risk
        euint64 cappedRisk = FHE.select(
            FHE.gte(gasRisk, FHE.asEuint64(80)),
            FHE.asEuint64(80),
            gasRisk
        );
        
        return FHE.select(isElevatedGas, cappedRisk, FHE.asEuint64(5));
    }

    function _analyzeVolatilityRisk(euint64 volatilityScore) internal returns (euint64) {
        // Higher volatility increases MEV opportunity and risk
        // Volatility score is 0-100, we scale it to risk contribution
        return FHE.div(
            FHE.mul(volatilityScore, FHE.asEuint64(60)), // Max 60% contribution from volatility
            FHE.asEuint64(100)
        );
    }

    function _combineRiskFactors(RiskFactors memory risks) internal returns (euint64) {
        // Weighted combination of risk factors
        euint64 sizeWeight = FHE.asEuint64(40);    // 40% weight
        euint64 timingWeight = FHE.asEuint64(30);  // 30% weight
        euint64 gasWeight = FHE.asEuint64(20);     // 20% weight
        euint64 volWeight = FHE.asEuint64(10);     // 10% weight
        
        euint64 combinedRisk = FHE.add(
            FHE.add(
                FHE.div(FHE.mul(risks.sizeRisk, sizeWeight), FHE.asEuint64(100)),
                FHE.div(FHE.mul(risks.timingRisk, timingWeight), FHE.asEuint64(100))
            ),
            FHE.add(
                FHE.div(FHE.mul(risks.gasRisk, gasWeight), FHE.asEuint64(100)),
                FHE.div(FHE.mul(risks.volatilityRisk, volWeight), FHE.asEuint64(100))
            )
        );
        
        // Ensure risk doesn't exceed 100
        return FHE.select(
            FHE.gte(combinedRisk, FHE.asEuint64(100)),
            FHE.asEuint64(100),
            combinedRisk
        );
    }

    function _applySensitivityAdjustment(
        euint64 baseRisk,
        PoolId poolId
    ) internal returns (euint64) {
        uint8 sensitivity = detectionSensitivity[poolId];
        if (sensitivity == 0) sensitivity = DEFAULT_SENSITIVITY;
        
        // Adjust risk based on sensitivity
        // Higher sensitivity = higher risk scores
        euint64 adjustmentFactor = FHE.asEuint64(uint64(sensitivity));
        euint64 adjustedRisk = FHE.div(
            FHE.mul(baseRisk, adjustmentFactor),
            FHE.asEuint64(75) // Base sensitivity level
        );
        
        return FHE.select(
            FHE.gte(adjustedRisk, FHE.asEuint64(100)),
            FHE.asEuint64(100),
            adjustedRisk
        );
    }

    function _calculateProtectionRecommendations(
        euint64 riskScore,
        EncryptedSwapData calldata swapData
    ) internal returns (euint64 slippageBuffer, euint32 executionDelay) {
        // Calculate slippage buffer based on risk score
        // Risk 0-50: minimal buffer (0.1-0.5%)
        // Risk 50-75: moderate buffer (0.5-2%)
        // Risk 75-100: high buffer (2-5%)
        
        euint64 baseBuffer = FHE.div(
            FHE.mul(riskScore, FHE.asEuint64(Constants.DEFAULT_MAX_SLIPPAGE_BUFFER)),
            FHE.asEuint64(100)
        );
        
        slippageBuffer = FHE.select(
            FHE.gte(baseBuffer, FHE.asEuint64(Constants.MAX_SLIPPAGE_BUFFER)),
            FHE.asEuint64(Constants.MAX_SLIPPAGE_BUFFER),
            FHE.select(
                FHE.lte(baseBuffer, FHE.asEuint64(Constants.MIN_SLIPPAGE_BUFFER)),
                FHE.asEuint64(Constants.MIN_SLIPPAGE_BUFFER),
                baseBuffer
            )
        );
        
        // Calculate execution delay based on risk score
        euint32 baseDelay = FHE.asEuint32(
            FHE.div(
                FHE.mul(riskScore, FHE.asEuint64(Constants.DEFAULT_MAX_EXECUTION_DELAY)),
                FHE.asEuint64(100)
            )
        );
        
        executionDelay = FHE.select(
            FHE.gte(baseDelay, FHE.asEuint32(Constants.MAX_EXECUTION_DELAY)),
            FHE.asEuint32(Constants.MAX_EXECUTION_DELAY),
            FHE.select(
                FHE.lte(baseDelay, FHE.asEuint32(Constants.MIN_EXECUTION_DELAY)),
                FHE.asEuint32(Constants.MIN_EXECUTION_DELAY),
                baseDelay
            )
        );
    }

    function _estimateMevLoss(
        EncryptedSwapData calldata swapData,
        euint64 riskScore,
        PoolMetrics memory metrics
    ) internal returns (euint128) {
        // Estimate potential MEV loss based on swap size and risk
        // This is a conservative estimate for decision making
        
        euint128 swapValue = swapData.encryptedAmount;
        
        // Base MEV extraction rate: 0.1% for low risk, up to 3% for high risk
        euint64 mevRate = FHE.div(
            FHE.mul(riskScore, FHE.asEuint64(300)), // Max 3% in basis points
            FHE.asEuint64(100)
        );
        
        // Minimum MEV rate
        mevRate = FHE.select(
            FHE.lte(mevRate, FHE.asEuint64(10)),
            FHE.asEuint64(10), // 0.1% minimum
            mevRate
        );
        
        return FHE.div(
            FHE.mul(swapValue, FHE.asEuint128(mevRate)),
            FHE.asEuint128(10000) // Convert from basis points
        );
    }

    // ============ Pool Management Functions ============

    function _initializePool(PoolId poolId) internal {
        poolMetrics[poolId] = PoolMetrics({
            averageSwapSize: FHE.asEuint128(0),
            averageGasPrice: FHE.asEuint64(0),
            lastLargeSwapTimestamp: FHE.asEuint32(uint32(block.timestamp)),
            volatilityScore: FHE.asEuint64(0),
            totalVolume24h: FHE.asEuint128(0)
        });
        
        detectionSensitivity[poolId] = DEFAULT_SENSITIVITY;
        poolInitialized[poolId] = true;
        
        // Allow this contract to access the metrics
        FHE.allowThis(poolMetrics[poolId].averageSwapSize);
        FHE.allowThis(poolMetrics[poolId].averageGasPrice);
        FHE.allowThis(poolMetrics[poolId].lastLargeSwapTimestamp);
        FHE.allowThis(poolMetrics[poolId].volatilityScore);
        FHE.allowThis(poolMetrics[poolId].totalVolume24h);
    }

    function _updateRunningAverages(
        PoolMetrics storage metrics,
        EncryptedSwapData calldata swapData
    ) internal {
        // Simple exponential moving average with decay factor
        euint128 decayFactor = FHE.asEuint128(90); // 90% weight to previous average
        euint128 newFactor = FHE.asEuint128(10);   // 10% weight to new data
        
        // Update average swap size
        metrics.averageSwapSize = FHE.div(
            FHE.add(
                FHE.mul(metrics.averageSwapSize, decayFactor),
                FHE.mul(swapData.encryptedAmount, newFactor)
            ),
            FHE.asEuint128(100)
        );
        
        // Update average gas price
        metrics.averageGasPrice = FHE.div(
            FHE.add(
                FHE.mul(metrics.averageGasPrice, FHE.asEuint64(90)),
                FHE.mul(swapData.encryptedGasPrice, FHE.asEuint64(10))
            ),
            FHE.asEuint64(100)
        );
        
        FHE.allowThis(metrics.averageSwapSize);
        FHE.allowThis(metrics.averageGasPrice);
    }

    function _updateVolatilityScore(
        PoolMetrics storage metrics,
        EncryptedSwapData calldata swapData
    ) internal {
        // Update volatility based on swap size relative to average
        // Large deviations from average increase volatility score
        
        euint128 sizeRatio = FHE.div(
            FHE.mul(swapData.encryptedAmount, FHE.asEuint128(100)),
            metrics.averageSwapSize
        );
        
        // Calculate volatility contribution (0-20 points per swap)
        euint64 volContribution = FHE.asEuint64(10); // Base contribution
        
        // Higher contribution for larger deviations
        ebool isLargeDeviation = FHE.gte(sizeRatio, FHE.asEuint128(200)); // 2x average
        volContribution = FHE.select(
            isLargeDeviation,
            FHE.asEuint64(20),
            volContribution
        );
        
        // Update volatility with decay
        metrics.volatilityScore = FHE.div(
            FHE.add(
                FHE.mul(metrics.volatilityScore, FHE.asEuint64(95)),
                FHE.mul(volContribution, FHE.asEuint64(5))
            ),
            FHE.asEuint64(100)
        );
        
        FHE.allowThis(metrics.volatilityScore);
    }

    function _storeHistoricalData(
        PoolId poolId,
        EncryptedSwapData calldata swapData
    ) internal {
        HistoricalSwapData[] storage history = swapHistory[poolId];
        
        // Remove oldest entry if at capacity
        if (history.length >= MAX_HISTORY_SIZE) {
            for (uint256 i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history.pop();
        }
        
        // Add new entry
        history.push(HistoricalSwapData({
            amount: swapData.encryptedAmount,
            gasPrice: swapData.encryptedGasPrice,
            timestamp: swapData.encryptedTimestamp,
            computedRisk: FHE.asEuint64(0), // Will be updated by analysis
            wasProtected: false // Will be updated after protection decision
        }));
    }

    // ============ Admin Functions ============

    function setAuthorizedUpdater(address updater, bool authorized) external onlyOwner {
        authorizedUpdaters[updater] = authorized;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Events.SystemPauseStateChanged(msg.sender, _paused, "Admin action");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert Errors.ZeroAddress("newOwner");
        owner = newOwner;
    }
}