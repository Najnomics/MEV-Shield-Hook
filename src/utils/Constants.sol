// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Constants
 * @notice System-wide constants for MEV Shield Hook
 */
library Constants {
    
    // ============ Protection Thresholds ============
    
    /// @notice Default MEV detection threshold (risk score 0-100)
    uint64 internal constant DEFAULT_PROTECTION_THRESHOLD = 75;
    
    /// @notice Maximum protection threshold allowed
    uint64 internal constant MAX_PROTECTION_THRESHOLD = 95;
    
    /// @notice Minimum protection threshold allowed
    uint64 internal constant MIN_PROTECTION_THRESHOLD = 25;
    
    // ============ Slippage Protection ============
    
    /// @notice Default maximum slippage buffer (basis points)
    uint64 internal constant DEFAULT_MAX_SLIPPAGE_BUFFER = 500; // 5%
    
    /// @notice Maximum slippage buffer allowed (basis points)
    uint64 internal constant MAX_SLIPPAGE_BUFFER = 1000; // 10%
    
    /// @notice Minimum slippage buffer (basis points)
    uint64 internal constant MIN_SLIPPAGE_BUFFER = 50; // 0.5%
    
    // ============ Timing Protection ============
    
    /// @notice Default maximum execution delay (blocks)
    uint32 internal constant DEFAULT_MAX_EXECUTION_DELAY = 2;
    
    /// @notice Maximum execution delay allowed (blocks)
    uint32 internal constant MAX_EXECUTION_DELAY = 5;
    
    /// @notice Minimum execution delay (blocks)
    uint32 internal constant MIN_EXECUTION_DELAY = 1;
    
    // ============ Gas Optimization ============
    
    /// @notice Default gas optimization factor (basis points)
    uint64 internal constant DEFAULT_GAS_OPTIMIZATION_FACTOR = 110; // 1.1x
    
    /// @notice Maximum gas optimization factor (basis points)
    uint64 internal constant MAX_GAS_OPTIMIZATION_FACTOR = 150; // 1.5x
    
    /// @notice Minimum gas optimization factor (basis points)
    uint64 internal constant MIN_GAS_OPTIMIZATION_FACTOR = 100; // 1.0x
    
    // ============ Risk Assessment ============
    
    /// @notice High risk threshold for sandwich attacks
    uint64 internal constant HIGH_RISK_THRESHOLD = 85;
    
    /// @notice Medium risk threshold
    uint64 internal constant MEDIUM_RISK_THRESHOLD = 65;
    
    /// @notice Low risk threshold
    uint64 internal constant LOW_RISK_THRESHOLD = 35;
    
    // ============ Pool Analysis ============
    
    /// @notice Minimum swap size ratio for large transaction detection (basis points)
    uint64 internal constant LARGE_SWAP_THRESHOLD = 300; // 3% of pool
    
    /// @notice Time window for MEV pattern analysis (blocks)
    uint32 internal constant MEV_ANALYSIS_WINDOW = 10;
    
    /// @notice Minimum time between large swaps for timing risk (blocks)
    uint32 internal constant MIN_TIME_BETWEEN_LARGE_SWAPS = 2;
    
    // ============ Effectiveness Calculation ============
    
    /// @notice Time window for effectiveness calculation (blocks)
    uint256 internal constant EFFECTIVENESS_WINDOW = 1000;
    
    /// @notice Minimum samples required for effectiveness calculation
    uint256 internal constant MIN_EFFECTIVENESS_SAMPLES = 10;
    
    // ============ Percentage Calculations ============
    
    /// @notice Basis points divisor (10000 = 100%)
    uint256 internal constant BASIS_POINTS = 10000;
    
    /// @notice Percentage divisor (100 = 100%)
    uint256 internal constant PERCENTAGE = 100;
    
    // ============ FHE Constants ============
    
    /// @notice Maximum encrypted value for risk scores
    uint64 internal constant MAX_RISK_SCORE = 100;
    
    /// @notice Zero constant for encrypted comparisons
    uint128 internal constant ENCRYPTED_ZERO = 0;
    
    /// @notice One constant for encrypted arithmetic
    uint128 internal constant ENCRYPTED_ONE = 1;
    
    // ============ Time Constants ============
    
    /// @notice Approximate seconds per block (12 seconds for Ethereum)
    uint32 internal constant SECONDS_PER_BLOCK = 12;
    
    /// @notice Blocks per hour
    uint32 internal constant BLOCKS_PER_HOUR = 300;
    
    /// @notice Blocks per day
    uint32 internal constant BLOCKS_PER_DAY = 7200;
    
    // ============ MEV Pattern Constants ============
    
    /// @notice Maximum acceptable front-running window (blocks)
    uint32 internal constant MAX_FRONTRUN_WINDOW = 3;
    
    /// @notice Sandwich attack detection window (blocks)
    uint32 internal constant SANDWICH_DETECTION_WINDOW = 5;
    
    /// @notice Minimum gas price premium for MEV detection (basis points)
    uint64 internal constant MIN_MEV_GAS_PREMIUM = 110; // 1.1x
    
    // ============ Pool Classification ============
    
    /// @notice High volatility threshold (basis points per block)
    uint64 internal constant HIGH_VOLATILITY_THRESHOLD = 50; // 0.5% per block
    
    /// @notice Low liquidity threshold (basis points of total supply)
    uint64 internal constant LOW_LIQUIDITY_THRESHOLD = 100; // 1% of total supply
    
    // ============ Analytics Constants ============
    
    /// @notice Maximum number of historical data points to store
    uint256 internal constant MAX_HISTORICAL_POINTS = 1000;
    
    /// @notice Minimum confidence level for analytics (basis points)
    uint64 internal constant MIN_CONFIDENCE_LEVEL = 9000; // 90%
    
    /// @notice Default analytics window (blocks)
    uint256 internal constant DEFAULT_ANALYTICS_WINDOW = 100;
}