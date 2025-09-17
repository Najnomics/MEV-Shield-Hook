// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {euint128, euint64, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title IEncryptedMetrics
 * @notice Interface for privacy-preserving MEV protection analytics
 */
interface IEncryptedMetrics {
    
    struct PoolAnalytics {
        euint128 totalSwapsProtected;     // Total number of protected swaps
        euint128 totalMevPrevented;       // Total MEV value prevented (wei)
        euint64 averageRiskScore;         // Average risk score of threats detected
        euint64 protectionEffectiveness;  // Protection success rate (0-100)
        euint32 lastUpdated;              // Last update timestamp
    }

    struct ThreatProfile {
        euint64 sandwichAttackFrequency;  // Frequency of sandwich attacks (per 1000 swaps)
        euint64 frontrunAttackFrequency;  // Frequency of front-running attacks
        euint64 averageMevLoss;           // Average MEV loss per attack
        euint32 peakRiskPeriod;           // Time period with highest risk
        ebool isHighRiskPool;             // Whether pool is classified as high-risk
    }

    struct UserAnalytics {
        euint128 totalSavings;            // Total MEV savings for user
        euint128 swapsProtected;          // Number of swaps protected
        euint64 averageRiskExposure;      // Average risk score of user's swaps
        euint32 firstProtectionDate;      // Timestamp of first protection
    }

    /**
     * @notice Updates metrics after a swap analysis
     * @param poolId Pool identifier
     * @param riskScore Risk score of the swap
     * @param mevSavings Amount of MEV prevented
     * @param wasProtected Whether protection was applied
     */
    function updateSwapMetrics(
        PoolId poolId,
        euint64 riskScore,
        euint128 mevSavings,
        ebool wasProtected
    ) external;

    /**
     * @notice Updates user-specific analytics
     * @param user User address
     * @param poolId Pool identifier
     * @param mevSavings Amount saved
     * @param riskScore Risk score of the swap
     */
    function updateUserAnalytics(
        address user,
        PoolId poolId,
        euint128 mevSavings,
        euint64 riskScore
    ) external;

    /**
     * @notice Gets encrypted analytics for a pool
     * @param poolId Pool identifier
     * @return analytics Encrypted pool analytics
     */
    function getPoolAnalytics(
        PoolId poolId
    ) external returns (PoolAnalytics memory analytics);

    /**
     * @notice Gets threat profile for a pool
     * @param poolId Pool identifier
     * @return profile Encrypted threat profile
     */
    function getThreatProfile(
        PoolId poolId
    ) external returns (ThreatProfile memory profile);

    /**
     * @notice Gets user analytics
     * @param user User address
     * @return analytics Encrypted user analytics
     */
    function getUserAnalytics(
        address user
    ) external returns (UserAnalytics memory analytics);

    /**
     * @notice Calculates global protection effectiveness
     * @param timeWindow Time window for calculation (in blocks)
     * @return effectiveness Global effectiveness score (0-100)
     */
    function calculateGlobalEffectiveness(
        uint256 timeWindow
    ) external returns (euint64 effectiveness);

    /**
     * @notice Generates encrypted report for a time period
     * @param poolId Pool identifier
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @return report Encrypted analytics report
     */
    function generateEncryptedReport(
        PoolId poolId,
        uint256 startTime,
        uint256 endTime
    ) external returns (bytes memory report);

    /**
     * @notice Requests decryption of specific metrics (with proper permissions)
     * @param poolId Pool identifier
     * @param metricsType Type of metrics to decrypt
     * @param requester Address requesting decryption
     */
    function requestMetricsDecryption(
        PoolId poolId,
        uint8 metricsType,
        address requester
    ) external;

    /**
     * @notice Gets decrypted metrics result (if authorized)
     * @param poolId Pool identifier
     * @param metricsType Type of metrics
     * @param requester Address that requested decryption
     * @return result Decrypted value
     * @return isReady Whether decryption is complete
     */
    function getDecryptedMetrics(
        PoolId poolId,
        uint8 metricsType,
        address requester
    ) external returns (uint256 result, bool isReady);

    /**
     * @notice Configures analytics permissions for a pool
     * @param poolId Pool identifier
     * @param authorizedAddresses Addresses authorized to view analytics
     */
    function configureAnalyticsPermissions(
        PoolId poolId,
        address[] calldata authorizedAddresses
    ) external;

    // Events
    event SwapMetricsUpdated(
        PoolId indexed poolId,
        address indexed trader,
        bool wasProtected
    );

    event ThreatProfileUpdated(
        PoolId indexed poolId,
        uint8 threatType,
        uint64 frequency
    );

    event AnalyticsPermissionGranted(
        PoolId indexed poolId,
        address indexed authorized
    );

    event MetricsDecryptionRequested(
        PoolId indexed poolId,
        address indexed requester,
        uint8 metricsType
    );

    event GlobalEffectivenessCalculated(
        uint256 timeWindow,
        uint64 effectiveness
    );
}