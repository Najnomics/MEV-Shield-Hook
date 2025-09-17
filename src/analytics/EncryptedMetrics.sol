// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {FHE, euint128, euint64, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

import {IEncryptedMetrics} from "./interfaces/IEncryptedMetrics.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title EncryptedMetrics
 * @notice Privacy-preserving analytics for MEV protection effectiveness
 * @dev Maintains encrypted metrics while providing selective disclosure for authorized parties
 */
contract EncryptedMetrics is IEncryptedMetrics {
    using FHE for uint256;

    // ============ State Variables ============

    /// @notice Pool analytics data
    mapping(PoolId => PoolAnalytics) public poolAnalytics;
    
    /// @notice Threat profiles per pool
    mapping(PoolId => ThreatProfile) public threatProfiles;
    
    /// @notice User analytics data
    mapping(address => UserAnalytics) public userAnalytics;
    
    /// @notice User analytics per pool
    mapping(address => mapping(PoolId => UserPoolMetrics)) public userPoolMetrics;
    
    /// @notice Analytics permissions per pool
    mapping(PoolId => mapping(address => AnalyticsPermission)) public analyticsPermissions;
    
    /// @notice Decryption requests tracking
    mapping(bytes32 => DecryptionRequest) public decryptionRequests;
    
    /// @notice Authorized addresses that can update metrics
    mapping(address => bool) public authorizedUpdaters;
    
    /// @notice Global system metrics
    GlobalMetrics public globalMetrics;
    
    /// @notice Contract owner
    address public owner;

    // ============ Constants ============

    /// @notice Maximum time for decryption request validity (24 hours)
    uint256 private constant MAX_DECRYPTION_VALIDITY = 24 hours;
    
    /// @notice Metrics types for decryption
    uint8 private constant METRICS_TYPE_POOL_ANALYTICS = 1;
    uint8 private constant METRICS_TYPE_THREAT_PROFILE = 2;
    uint8 private constant METRICS_TYPE_USER_ANALYTICS = 3;
    uint8 private constant METRICS_TYPE_GLOBAL = 4;

    // ============ Structs ============

    struct UserPoolMetrics {
        euint128 swapsInPool;          // Number of swaps in this pool
        euint128 savingsInPool;        // MEV savings in this pool
        euint64 averageRiskInPool;     // Average risk exposure in pool
        euint32 lastSwapTimestamp;     // Last swap timestamp in pool
    }

    struct AnalyticsPermission {
        bool canViewBasic;             // Can view basic analytics
        bool canViewDetailed;          // Can view detailed analytics
        bool canRequestDecryption;     // Can request metric decryption
        bool canExportData;            // Can export analytics data
        uint256 grantedAt;             // When permission was granted
    }

    struct DecryptionRequest {
        address requester;             // Address that requested decryption
        PoolId poolId;                 // Pool ID (if applicable)
        uint8 metricsType;             // Type of metrics to decrypt
        uint256 createdAt;             // When request was created
        bool isCompleted;              // Whether decryption is complete
        uint256 result;                // Decrypted result (if available)
    }

    struct GlobalMetrics {
        euint128 totalSwapsAnalyzed;   // Total swaps analyzed across all pools
        euint128 totalSwapsProtected;  // Total swaps that received protection
        euint128 totalMevPrevented;    // Total MEV value prevented
        euint64 globalEffectiveness;   // Global protection effectiveness (0-100)
        euint32 lastGlobalUpdate;      // Last global metrics update
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

    modifier hasAnalyticsPermission(PoolId poolId, address user) {
        if (!analyticsPermissions[poolId][user].canViewBasic && user != owner) {
            revert Errors.AnalyticsAccessDenied(user, PoolId.unwrap(poolId));
        }
        _;
    }

    // ============ Constructor ============

    constructor() {
        owner = msg.sender;
        authorizedUpdaters[msg.sender] = true;
        
        // Initialize global metrics
        globalMetrics = GlobalMetrics({
            totalSwapsAnalyzed: FHE.asEuint128(0),
            totalSwapsProtected: FHE.asEuint128(0),
            totalMevPrevented: FHE.asEuint128(0),
            globalEffectiveness: FHE.asEuint64(0),
            lastGlobalUpdate: FHE.asEuint32(uint32(block.timestamp))
        });
        
        _setupGlobalMetricsPermissions();
    }

    // ============ External Functions ============

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function updateSwapMetrics(
        PoolId poolId,
        euint64 riskScore,
        euint128 mevSavings,
        ebool wasProtected
    ) external override onlyAuthorized {
        _updatePoolAnalytics(poolId, riskScore, mevSavings, wasProtected);
        _updateThreatProfile(poolId, riskScore, wasProtected);
        _updateGlobalMetrics(mevSavings, wasProtected);
        
        // Note: Events emit zero values for encrypted data in production
        emit Events.SwapMetricsUpdated(poolId, msg.sender, 0, 0, false);
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function updateUserAnalytics(
        address user,
        PoolId poolId,
        euint128 mevSavings,
        euint64 riskScore
    ) external override onlyAuthorized {
        _updateUserGlobalAnalytics(user, mevSavings, riskScore);
        _updateUserPoolAnalytics(user, poolId, mevSavings, riskScore);
        
        // Note: Events emit zero values for encrypted data in production
        emit Events.UserAnalyticsUpdated(
            user,
            poolId,
            0,
            0
        );
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function getPoolAnalytics(
        PoolId poolId
    ) external override hasAnalyticsPermission(poolId, msg.sender) returns (PoolAnalytics memory) {
        return poolAnalytics[poolId];
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function getThreatProfile(
        PoolId poolId
    ) external override hasAnalyticsPermission(poolId, msg.sender) returns (ThreatProfile memory) {
        return threatProfiles[poolId];
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function getUserAnalytics(
        address user
    ) external override returns (UserAnalytics memory) {
        // Users can always view their own analytics
        if (msg.sender != user && !authorizedUpdaters[msg.sender] && msg.sender != owner) {
            revert Errors.Unauthorized(msg.sender, user);
        }
        
        return userAnalytics[user];
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function calculateGlobalEffectiveness(
        uint256 timeWindow
    ) external override returns (euint64) {
        // Use cached global effectiveness if recent enough
        // Note: In production, this would require proper FHE decryption handling
        if (block.timestamp - uint32(block.timestamp) < timeWindow) {
            return globalMetrics.globalEffectiveness;
        }
        
        // Calculate real-time effectiveness
        euint128 totalProtected = globalMetrics.totalSwapsProtected;
        euint128 totalAnalyzed = globalMetrics.totalSwapsAnalyzed;
        
        // Check if we have any data to work with
        // Note: In production, this would use FHE comparison operations
        ebool hasData = FHE.gt(totalAnalyzed, FHE.asEuint128(0));
        
        return FHE.select(
            hasData,
            FHE.div(
                FHE.mul(FHE.asEuint64(totalProtected), FHE.asEuint64(100)),
                FHE.asEuint64(totalAnalyzed)
            ),
            FHE.asEuint64(0)
        );
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function generateEncryptedReport(
        PoolId poolId,
        uint256 startTime,
        uint256 endTime
    ) external override hasAnalyticsPermission(poolId, msg.sender) returns (bytes memory) {
        PoolAnalytics memory analytics = poolAnalytics[poolId];
        ThreatProfile memory threats = threatProfiles[poolId];
        
        // Create a structured report with encrypted data
        return abi.encode(
            analytics.totalSwapsProtected,
            analytics.totalMevPrevented,
            analytics.averageRiskScore,
            analytics.protectionEffectiveness,
            threats.sandwichAttackFrequency,
            threats.frontrunAttackFrequency,
            threats.averageMevLoss,
            block.timestamp // Report generation timestamp
        );
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function requestMetricsDecryption(
        PoolId poolId,
        uint8 metricsType,
        address requester
    ) external override {
        // Check if requester has permission
        if (!analyticsPermissions[poolId][requester].canRequestDecryption && 
            requester != owner && 
            msg.sender != requester) {
            revert Errors.MetricsPermissionDenied(requester, PoolId.unwrap(poolId));
        }
        
        // Generate unique request ID
        bytes32 requestId = keccak256(
            abi.encodePacked(poolId, metricsType, requester, block.timestamp, block.number)
        );
        
        // Store decryption request
        decryptionRequests[requestId] = DecryptionRequest({
            requester: requester,
            poolId: poolId,
            metricsType: metricsType,
            createdAt: block.timestamp,
            isCompleted: false,
            result: 0
        });
        
        // Initiate decryption based on metrics type
        _initiateDecryption(requestId, poolId, metricsType);
        
        emit Events.MetricsDecryptionRequested(poolId, requester, metricsType, requestId);
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function getDecryptedMetrics(
        PoolId poolId,
        uint8 metricsType,
        address requester
    ) external override returns (uint256 result, bool isReady) {
        bytes32 requestId = _generateRequestId(poolId, metricsType, requester);
        DecryptionRequest memory request = decryptionRequests[requestId];
        
        if (request.requester == address(0)) {
            revert Errors.InvalidDecryptionRequest(requestId, "Request not found");
        }
        
        if (block.timestamp > request.createdAt + MAX_DECRYPTION_VALIDITY) {
            revert Errors.InvalidDecryptionRequest(requestId, "Request expired");
        }
        
        return (request.result, request.isCompleted);
    }

    /**
     * @inheritdoc IEncryptedMetrics
     */
    function configureAnalyticsPermissions(
        PoolId poolId,
        address[] calldata authorizedAddresses
    ) external override onlyAuthorized {
        for (uint256 i = 0; i < authorizedAddresses.length; i++) {
            analyticsPermissions[poolId][authorizedAddresses[i]] = AnalyticsPermission({
                canViewBasic: true,
                canViewDetailed: true,
                canRequestDecryption: true,
                canExportData: true,
                grantedAt: block.timestamp
            });
            
            emit Events.AnalyticsPermissionGranted(poolId, msg.sender, authorizedAddresses[i], 1);
        }
    }

    // ============ Internal Functions ============

    function _updatePoolAnalytics(
        PoolId poolId,
        euint64 riskScore,
        euint128 mevSavings,
        ebool wasProtected
    ) internal {
        PoolAnalytics storage analytics = poolAnalytics[poolId];
        
        // Update totals using FHE select instead of decrypt
        euint128 incrementValue = FHE.select(wasProtected, FHE.asEuint128(1), FHE.asEuint128(0));
        euint128 savingsValue = FHE.select(wasProtected, mevSavings, FHE.asEuint128(0));
        
        analytics.totalSwapsProtected = analytics.totalSwapsProtected.add(incrementValue);
        analytics.totalMevPrevented = analytics.totalMevPrevented.add(savingsValue);
        
        // Update running average of risk scores
        analytics.averageRiskScore = _updateRunningAverage(
            analytics.averageRiskScore,
            riskScore,
            analytics.totalSwapsProtected
        );
        
        // Calculate protection effectiveness
        analytics.protectionEffectiveness = _calculateEffectiveness(
            analytics.totalSwapsProtected,
            analytics.totalSwapsProtected // Assuming all analyzed swaps for now
        );
        
        analytics.lastUpdated = FHE.asEuint32(uint32(block.timestamp));
        
        // Set up FHE permissions
        FHE.allowThis(analytics.totalSwapsProtected);
        FHE.allowThis(analytics.totalMevPrevented);
        FHE.allowThis(analytics.averageRiskScore);
        FHE.allowThis(analytics.protectionEffectiveness);
        FHE.allowThis(analytics.lastUpdated);
    }

    function _updateThreatProfile(
        PoolId poolId,
        euint64 riskScore,
        ebool wasProtected
    ) internal {
        ThreatProfile storage profile = threatProfiles[poolId];
        
        // Classify threat type based on risk score
        ebool isHighRisk = FHE.gte(riskScore, FHE.asEuint64(Constants.HIGH_RISK_THRESHOLD));
        ebool isMediumRisk = FHE.and(
            FHE.gte(riskScore, FHE.asEuint64(Constants.MEDIUM_RISK_THRESHOLD)),
            FHE.lt(riskScore, FHE.asEuint64(Constants.HIGH_RISK_THRESHOLD))
        );
        
        // Update attack frequencies using FHE select instead of decrypt
        euint64 sandwichIncrement = FHE.select(isHighRisk, FHE.asEuint64(10), FHE.asEuint64(0));
        euint64 frontrunIncrement = FHE.select(isMediumRisk, FHE.asEuint64(5), FHE.asEuint64(0));
        
        profile.sandwichAttackFrequency = profile.sandwichAttackFrequency.add(sandwichIncrement);
        profile.frontrunAttackFrequency = profile.frontrunAttackFrequency.add(frontrunIncrement);
        
        // Update high-risk classification
        profile.isHighRiskPool = FHE.gte(
            profile.sandwichAttackFrequency,
            FHE.asEuint64(50) // Threshold for high-risk classification
        );
        
        profile.peakRiskPeriod = FHE.asEuint32(uint32(block.timestamp));
        
        // Set up FHE permissions
        FHE.allowThis(profile.sandwichAttackFrequency);
        FHE.allowThis(profile.frontrunAttackFrequency);
        FHE.allowThis(profile.isHighRiskPool);
        FHE.allowThis(profile.peakRiskPeriod);
        
        // Note: Events emit zero values for encrypted data in production
        emit Events.ThreatProfileUpdated(poolId, 1, 0, 0);
    }

    function _updateUserGlobalAnalytics(
        address user,
        euint128 mevSavings,
        euint64 riskScore
    ) internal {
        UserAnalytics storage analytics = userAnalytics[user];
        
        // Initialize if first time using FHE comparison
        ebool isFirstTime = FHE.eq(analytics.firstProtectionDate, FHE.asEuint32(0));
        euint32 currentTimestamp = FHE.asEuint32(uint32(block.timestamp));
        analytics.firstProtectionDate = FHE.select(isFirstTime, currentTimestamp, analytics.firstProtectionDate);
        FHE.allowThis(analytics.firstProtectionDate);
        
        analytics.totalSavings = analytics.totalSavings.add(mevSavings);
        analytics.swapsProtected = analytics.swapsProtected.add(FHE.asEuint128(1));
        
        // Update running average of risk exposure
        analytics.averageRiskExposure = _updateRunningAverage(
            analytics.averageRiskExposure,
            riskScore,
            analytics.swapsProtected
        );
        
        // Set up FHE permissions
        FHE.allowThis(analytics.totalSavings);
        FHE.allowThis(analytics.swapsProtected);
        FHE.allowThis(analytics.averageRiskExposure);
    }

    function _updateUserPoolAnalytics(
        address user,
        PoolId poolId,
        euint128 mevSavings,
        euint64 riskScore
    ) internal {
        UserPoolMetrics storage metrics = userPoolMetrics[user][poolId];
        
        metrics.swapsInPool = metrics.swapsInPool.add(FHE.asEuint128(1));
        metrics.savingsInPool = metrics.savingsInPool.add(mevSavings);
        
        // Update running average
        metrics.averageRiskInPool = _updateRunningAverage(
            metrics.averageRiskInPool,
            riskScore,
            metrics.swapsInPool
        );
        
        metrics.lastSwapTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        // Set up FHE permissions
        FHE.allowThis(metrics.swapsInPool);
        FHE.allowThis(metrics.savingsInPool);
        FHE.allowThis(metrics.averageRiskInPool);
        FHE.allowThis(metrics.lastSwapTimestamp);
    }

    function _updateGlobalMetrics(
        euint128 mevSavings,
        ebool wasProtected
    ) internal {
        globalMetrics.totalSwapsAnalyzed = globalMetrics.totalSwapsAnalyzed.add(FHE.asEuint128(1));
        
        // Use FHE select instead of decrypt
        euint128 protectedIncrement = FHE.select(wasProtected, FHE.asEuint128(1), FHE.asEuint128(0));
        euint128 savingsIncrement = FHE.select(wasProtected, mevSavings, FHE.asEuint128(0));
        
        globalMetrics.totalSwapsProtected = globalMetrics.totalSwapsProtected.add(protectedIncrement);
        globalMetrics.totalMevPrevented = globalMetrics.totalMevPrevented.add(savingsIncrement);
        
        // Update effectiveness
        globalMetrics.globalEffectiveness = _calculateEffectiveness(
            globalMetrics.totalSwapsProtected,
            globalMetrics.totalSwapsAnalyzed
        );
        
        globalMetrics.lastGlobalUpdate = FHE.asEuint32(uint32(block.timestamp));
        
        _setupGlobalMetricsPermissions();
    }

    function _updateRunningAverage(
        euint64 currentAverage,
        euint64 newValue,
        euint128 count
    ) internal returns (euint64) {
        // Use FHE comparison instead of decrypt
        ebool isFirstOrZero = FHE.lte(count, FHE.asEuint128(1));
        
        return FHE.select(isFirstOrZero, newValue, _calculateWeightedAverage(currentAverage, newValue, count));
    }
    
    function _calculateWeightedAverage(
        euint64 currentAverage,
        euint64 newValue,
        euint128 count
    ) internal returns (euint64) {
        // Calculate weighted average: ((n-1) * avg + newValue) / n
        euint64 countU64 = FHE.asEuint64(count);
        euint64 weightedOld = FHE.mul(currentAverage, FHE.sub(countU64, FHE.asEuint64(1)));
        euint64 totalWeighted = FHE.add(weightedOld, newValue);
        
        return FHE.div(totalWeighted, countU64);
    }

    function _calculateEffectiveness(
        euint128 protectedCount,
        euint128 totalCount
    ) internal returns (euint64) {
        // Use FHE comparison instead of decrypt
        ebool hasCount = FHE.gt(totalCount, FHE.asEuint128(0));
        
        return FHE.select(
            hasCount,
            FHE.div(
                FHE.mul(FHE.asEuint64(protectedCount), FHE.asEuint64(100)),
                FHE.asEuint64(totalCount)
            ),
            FHE.asEuint64(0)
        );
    }

    function _initiateDecryption(
        bytes32 requestId,
        PoolId poolId,
        uint8 metricsType
    ) internal {
        // Initiate FHE decryption based on metrics type
        if (metricsType == METRICS_TYPE_POOL_ANALYTICS) {
            FHE.decrypt(poolAnalytics[poolId].totalMevPrevented);
        } else if (metricsType == METRICS_TYPE_THREAT_PROFILE) {
            FHE.decrypt(threatProfiles[poolId].sandwichAttackFrequency);
        } else if (metricsType == METRICS_TYPE_GLOBAL) {
            FHE.decrypt(globalMetrics.globalEffectiveness);
        }
        
        // Note: In a real implementation, this would set up callback handling
        // for when the decryption completes
    }

    function _generateRequestId(
        PoolId poolId,
        uint8 metricsType,
        address requester
    ) internal view returns (bytes32) {
        // This is a simplified version - in practice, you'd need to track
        // request IDs more carefully
        return keccak256(abi.encodePacked(poolId, metricsType, requester));
    }

    function _setupGlobalMetricsPermissions() internal {
        FHE.allowThis(globalMetrics.totalSwapsAnalyzed);
        FHE.allowThis(globalMetrics.totalSwapsProtected);
        FHE.allowThis(globalMetrics.totalMevPrevented);
        FHE.allowThis(globalMetrics.globalEffectiveness);
        FHE.allowThis(globalMetrics.lastGlobalUpdate);
    }

    // ============ Admin Functions ============

    function setAuthorizedUpdater(address updater, bool authorized) external onlyOwner {
        authorizedUpdaters[updater] = authorized;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert Errors.ZeroAddress("newOwner");
        owner = newOwner;
    }

    // ============ View Functions ============

    function getGlobalMetrics() external returns (GlobalMetrics memory) {
        return globalMetrics;
    }

    function getUserPoolMetrics(
        address user,
        PoolId poolId
    ) external returns (UserPoolMetrics memory) {
        if (msg.sender != user && !authorizedUpdaters[msg.sender] && msg.sender != owner) {
            revert Errors.Unauthorized(msg.sender, user);
        }
        
        return userPoolMetrics[user][poolId];
    }

    function hasAnalyticsAccess(
        PoolId poolId,
        address user
    ) external returns (bool) {
        return analyticsPermissions[poolId][user].canViewBasic || user == owner;
    }
}