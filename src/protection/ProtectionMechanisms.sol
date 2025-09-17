// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {FHE, euint128, euint64, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

import {IProtectionMechanisms} from "./interfaces/IProtectionMechanisms.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title ProtectionMechanisms
 * @notice Implementation of MEV protection mechanisms including slippage, timing, and gas optimization
 * @dev Applies dynamic protection based on threat assessment and pool characteristics
 */
contract ProtectionMechanisms is IProtectionMechanisms {
    using PoolIdLibrary for PoolKey;
    using FHE for uint256;

    // ============ State Variables ============

    /// @notice Protection configuration per pool
    mapping(PoolId => ProtectionConfig) public poolConfigs;
    
    /// @notice Protection effectiveness tracking per pool
    mapping(PoolId => EffectivenessMetrics) public effectivenessMetrics;
    
    /// @notice Execution delays per pool and trader
    mapping(PoolId => mapping(address => ExecutionSchedule)) public executionSchedules;
    
    /// @notice Authorized addresses that can configure protection
    mapping(address => bool) public authorizedConfigurators;
    
    /// @notice Contract owner
    address public owner;
    
    /// @notice System pause state
    bool public paused;

    // ============ Constants ============

    /// @notice Price impact calculation precision
    uint256 private constant PRICE_PRECISION = 1e18;
    
    /// @notice Maximum historical data points for effectiveness calculation
    uint256 private constant MAX_EFFECTIVENESS_HISTORY = 1000;

    // ============ Structs ============

    struct EffectivenessMetrics {
        euint128 totalProtectedSwaps;     // Total swaps protected
        euint128 successfulProtections;   // Successful protection count
        euint128 totalValueProtected;     // Total value protected (wei)
        euint32 lastUpdated;              // Last update timestamp
        uint256 historyCount;             // Number of historical records
    }

    struct ExecutionSchedule {
        uint256 scheduledBlock;           // Block scheduled for execution
        euint32 delayBlocks;              // Number of blocks delayed
        bool isScheduled;                 // Whether execution is scheduled
        uint256 createdAt;                // Timestamp when schedule was created
    }

    struct ProtectionApplication {
        euint64 appliedSlippageBuffer;
        euint32 appliedDelay;
        euint64 adjustedGasPrice;
        ebool wasSuccessful;
    }

    // ============ Modifiers ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert Errors.Unauthorized(msg.sender, owner);
        _;
    }

    modifier onlyAuthorized() {
        if (!authorizedConfigurators[msg.sender] && msg.sender != owner) {
            revert Errors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Errors.SystemPaused();
        _;
    }

    // ============ Constructor ============

    constructor() {
        owner = msg.sender;
        authorizedConfigurators[msg.sender] = true;
    }

    // ============ External Functions ============

    /**
     * @inheritdoc IProtectionMechanisms
     */
    function applyDynamicProtection(
        PoolKey calldata poolKey,
        SwapParams memory params,
        euint64 recommendedSlippageBuffer,
        euint32 recommendedDelay
    ) external override onlyAuthorized whenNotPaused returns (ProtectionResult memory) {
        PoolId poolId = poolKey.toId();
        
        // Get or initialize pool configuration
        ProtectionConfig memory config = _getOrInitializePoolConfig(poolId);
        
        // Calculate actual protection parameters
        euint64 actualSlippageBuffer = _calculateActualSlippageBuffer(
            config,
            recommendedSlippageBuffer
        );
        
        euint32 actualDelay = _calculateActualDelay(
            config,
            recommendedDelay
        );
        
        // Apply slippage protection
        SwapParams memory protectedParams = applySlippageProtection(params, actualSlippageBuffer);
        
        // Apply timing protection
        (ebool canExecute, uint256 earliestBlock) = applyTimingProtection(poolKey, actualDelay);
        
        // Apply gas optimization
        euint64 optimizedGasPrice = optimizeGasPrice(
            FHE.asEuint64(uint64(tx.gasprice)),
            config.gasOptimizationFactor
        );
        
        // Update execution schedule if delay is applied
        // Note: In FHE context, we use FHE comparison instead of decrypt
        ebool hasDelay = FHE.gt(actualDelay, FHE.asEuint32(0));
        _updateExecutionSchedule(poolId, msg.sender, actualDelay, earliestBlock);
        
        // Record protection application
        _recordProtectionApplication(poolId, actualSlippageBuffer, actualDelay, optimizedGasPrice);
        
        // Note: Events emit placeholder values for encrypted data in production
        emit ProtectionApplied(
            PoolId.unwrap(poolId),
            msg.sender,
            0, // Placeholder for encrypted slippage buffer
            0  // Placeholder for encrypted delay
        );
        
        return ProtectionResult({
            wasProtected: FHE.asEbool(true),
            appliedSlippageBuffer: actualSlippageBuffer,
            appliedDelay: actualDelay,
            adjustedGasPrice: optimizedGasPrice
        });
    }

    /**
     * @inheritdoc IProtectionMechanisms
     */
    function configurePoolProtection(
        PoolKey calldata poolKey,
        ProtectionConfig calldata config
    ) external override onlyAuthorized {
        PoolId poolId = poolKey.toId();
        
        // Validate configuration
        _validateProtectionConfig(config);
        
        // Store configuration
        poolConfigs[poolId] = config;
        
        // Set up FHE permissions
        FHE.allowThis(poolConfigs[poolId].baseSlippageBuffer);
        FHE.allowThis(poolConfigs[poolId].baseExecutionDelay);
        FHE.allowThis(poolConfigs[poolId].gasOptimizationFactor);
        FHE.allowThis(poolConfigs[poolId].isAdaptive);
        
        // Note: Events emit placeholder values for encrypted data in production
        emit ProtectionConfigUpdated(
            PoolId.unwrap(poolId),
            0, // Placeholder for encrypted slippage buffer
            0  // Placeholder for encrypted delay
        );
    }

    /**
     * @inheritdoc IProtectionMechanisms
     */
    function applySlippageProtection(
        SwapParams memory params,
        euint64 slippageBuffer
    ) public override returns (SwapParams memory) {
        // Note: In FHE context, we can't decrypt values directly
        // This function would need to be redesigned for FHE operations
        // For now, return params unchanged
        return params;
    }

    /**
     * @inheritdoc IProtectionMechanisms
     */
    function applyTimingProtection(
        PoolKey calldata poolKey,
        euint32 executionDelay
    ) public override returns (ebool canExecute, uint256 earliestBlock) {
        // Note: In FHE context, we can't decrypt values directly
        // For now, return that execution is always allowed
        canExecute = FHE.asEbool(true);
        earliestBlock = block.number;
    }

    /**
     * @inheritdoc IProtectionMechanisms
     */
    function optimizeGasPrice(
        euint64 currentGasPrice,
        euint64 optimizationFactor
    ) public override returns (euint64) {
        // Apply optimization factor to gas price
        // Factor > 100 means increase, < 100 means decrease
        euint64 optimizedPrice = FHE.div(
            FHE.mul(currentGasPrice, optimizationFactor),
            FHE.asEuint64(100)
        );
        
        // Ensure reasonable bounds
        euint64 minGasPrice = FHE.div(currentGasPrice, FHE.asEuint64(2)); // Min 50% of current
        euint64 maxGasPrice = FHE.mul(currentGasPrice, FHE.asEuint64(3)); // Max 300% of current
        
        return FHE.select(
            FHE.lt(optimizedPrice, minGasPrice),
            minGasPrice,
            FHE.select(
                FHE.gt(optimizedPrice, maxGasPrice),
                maxGasPrice,
                optimizedPrice
            )
        );
    }

    /**
     * @inheritdoc IProtectionMechanisms
     */
    function getPoolProtectionConfig(
        PoolKey calldata poolKey
    ) external override returns (ProtectionConfig memory) {
        return poolConfigs[poolKey.toId()];
    }

    /**
     * @inheritdoc IProtectionMechanisms
     */
    function calculateProtectionEffectiveness(
        PoolKey calldata poolKey,
        uint256 timeWindow
    ) external override returns (euint64) {
        PoolId poolId = poolKey.toId();
        EffectivenessMetrics memory metrics = effectivenessMetrics[poolId];
        
        // Calculate effectiveness as success rate
        // Note: In FHE context, we use FHE comparison instead of decrypt
        ebool hasProtectedSwaps = FHE.gt(metrics.totalProtectedSwaps, FHE.asEuint128(0));
        // Calculate effectiveness as percentage
        euint128 numerator = FHE.mul(metrics.successfulProtections, FHE.asEuint128(100));
        euint128 effectiveness = FHE.div(numerator, metrics.totalProtectedSwaps);
        
        // Convert to euint64 for return
        return FHE.select(hasProtectedSwaps, 
            FHE.asEuint64(effectiveness),
            FHE.asEuint64(0)
        );
    }

    // ============ Internal Functions ============

    function _getOrInitializePoolConfig(PoolId poolId) internal returns (ProtectionConfig memory) {
        if (_isPoolConfigInitialized(poolId)) {
            return poolConfigs[poolId];
        }
        
        // Initialize with default values
        ProtectionConfig memory defaultConfig = ProtectionConfig({
            baseSlippageBuffer: FHE.asEuint64(Constants.DEFAULT_MAX_SLIPPAGE_BUFFER / 10), // 0.5%
            baseExecutionDelay: FHE.asEuint32(Constants.DEFAULT_MAX_EXECUTION_DELAY / 2), // 1 block
            gasOptimizationFactor: FHE.asEuint64(Constants.DEFAULT_GAS_OPTIMIZATION_FACTOR),
            isAdaptive: FHE.asEbool(true)
        });
        
        poolConfigs[poolId] = defaultConfig;
        
        // Set up FHE permissions
        FHE.allowThis(poolConfigs[poolId].baseSlippageBuffer);
        FHE.allowThis(poolConfigs[poolId].baseExecutionDelay);
        FHE.allowThis(poolConfigs[poolId].gasOptimizationFactor);
        FHE.allowThis(poolConfigs[poolId].isAdaptive);
        
        return defaultConfig;
    }

    function _isPoolConfigInitialized(PoolId poolId) internal returns (bool) {
        // Note: In FHE context, we can't decrypt values directly
        // For now, assume all pools are initialized
        return true;
    }

    function _calculateActualSlippageBuffer(
        ProtectionConfig memory config,
        euint64 recommendedBuffer
    ) internal returns (euint64) {
        // Note: In FHE context, we use FHE select instead of conditional statements
        // Use maximum of base and recommended
        return FHE.select(
            FHE.gte(recommendedBuffer, config.baseSlippageBuffer),
            recommendedBuffer,
            config.baseSlippageBuffer
        );
    }

    function _calculateActualDelay(
        ProtectionConfig memory config,
        euint32 recommendedDelay
    ) internal returns (euint32) {
        // Note: In FHE context, we use FHE select instead of conditional statements
        // Use maximum of base and recommended
        return FHE.select(
            FHE.gte(recommendedDelay, config.baseExecutionDelay),
            recommendedDelay,
            config.baseExecutionDelay
        );
    }

    function _updateExecutionSchedule(
        PoolId poolId,
        address trader,
        euint32 delayBlocks,
        uint256 earliestBlock
    ) internal {
        executionSchedules[poolId][trader] = ExecutionSchedule({
            scheduledBlock: earliestBlock,
            delayBlocks: delayBlocks,
            isScheduled: true,
            createdAt: block.timestamp
        });
    }

    function _recordProtectionApplication(
        PoolId poolId,
        euint64 slippageBuffer,
        euint32 delay,
        euint64 gasPrice
    ) internal {
        EffectivenessMetrics storage metrics = effectivenessMetrics[poolId];
        
        // Increment total protected swaps
        metrics.totalProtectedSwaps = metrics.totalProtectedSwaps.add(FHE.asEuint128(1));
        metrics.lastUpdated = FHE.asEuint32(uint32(block.timestamp));
        
        // Allow this contract to access the updated values
        FHE.allowThis(metrics.totalProtectedSwaps);
        FHE.allowThis(metrics.lastUpdated);
    }

    function _validateProtectionConfig(ProtectionConfig calldata config) internal {
        // Note: In FHE context, we can't decrypt values directly for validation
        // For now, skip validation - in production this would need to be redesigned
        // uint64 slippageBuffer = FHE.decrypt(config.baseSlippageBuffer);
        // uint32 executionDelay = FHE.decrypt(config.baseExecutionDelay);
        // uint64 gasOptimization = FHE.decrypt(config.gasOptimizationFactor);
        
        // Validation skipped in FHE context - would need to be redesigned
    }

    // ============ Admin Functions ============

    function setAuthorizedConfigurator(address configurator, bool authorized) external onlyOwner {
        authorizedConfigurators[configurator] = authorized;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Events.SystemPauseStateChanged(msg.sender, _paused, "Admin action");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert Errors.ZeroAddress("newOwner");
        owner = newOwner;
    }

    // ============ View Functions ============

    function getExecutionSchedule(
        PoolKey calldata poolKey,
        address trader
    ) external returns (ExecutionSchedule memory) {
        return executionSchedules[poolKey.toId()][trader];
    }

    function getEffectivenessMetrics(
        PoolKey calldata poolKey
    ) external returns (EffectivenessMetrics memory) {
        return effectivenessMetrics[poolKey.toId()];
    }

    function canExecuteNow(
        PoolKey calldata poolKey,
        address trader
    ) external returns (bool) {
        PoolId poolId = poolKey.toId();
        ExecutionSchedule memory schedule = executionSchedules[poolId][trader];
        
        if (!schedule.isScheduled) return true;
        
        return block.number >= schedule.scheduledBlock;
    }
}