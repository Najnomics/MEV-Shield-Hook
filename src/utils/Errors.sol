// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Errors
 * @notice Custom error definitions for MEV Shield Hook system
 */
library Errors {
    
    // ============ Access Control Errors ============
    
    /// @notice Thrown when caller is not authorized to perform action
    error Unauthorized(address caller, address required);
    
    /// @notice Thrown when caller is not the pool manager
    error OnlyPoolManager(address caller);
    
    /// @notice Thrown when caller is not authorized for pool operations
    error UnauthorizedForPool(address caller, bytes32 poolId);
    
    /// @notice Thrown when trying to access restricted analytics
    error AnalyticsAccessDenied(address caller, bytes32 poolId);
    
    // ============ Configuration Errors ============
    
    /// @notice Thrown when protection threshold is out of valid range
    error InvalidProtectionThreshold(uint64 threshold, uint64 min, uint64 max);
    
    /// @notice Thrown when slippage buffer exceeds maximum allowed
    error InvalidSlippageBuffer(uint64 buffer, uint64 max);
    
    /// @notice Thrown when execution delay exceeds maximum allowed
    error InvalidExecutionDelay(uint32 delay, uint32 max);
    
    /// @notice Thrown when gas optimization factor is out of range
    error InvalidGasOptimizationFactor(uint64 factor, uint64 min, uint64 max);
    
    /// @notice Thrown when sensitivity level is out of valid range
    error InvalidSensitivityLevel(uint8 level);
    
    /// @notice Thrown when configuration is invalid or incomplete
    error InvalidConfiguration(string reason);
    
    // ============ Pool Errors ============
    
    /// @notice Thrown when pool is not initialized for MEV protection
    error PoolNotInitialized(bytes32 poolId);
    
    /// @notice Thrown when pool protection is disabled
    error PoolProtectionDisabled(bytes32 poolId);
    
    /// @notice Thrown when pool already has protection configured
    error PoolAlreadyConfigured(bytes32 poolId);
    
    /// @notice Thrown when insufficient pool data for analysis
    error InsufficientPoolData(bytes32 poolId, uint256 required, uint256 available);
    
    // ============ Protection Errors ============
    
    /// @notice Thrown when protection cannot be applied
    error ProtectionApplicationFailed(bytes32 poolId, string reason);
    
    /// @notice Thrown when swap is already protected
    error SwapAlreadyProtected(bytes32 poolId, address trader);
    
    /// @notice Thrown when protection parameters are invalid
    error InvalidProtectionParameters(string parameter, uint256 value);
    
    /// @notice Thrown when protection deadline has passed
    error ProtectionDeadlineExpired(uint256 deadline, uint256 current);
    
    // ============ Detection Errors ============
    
    /// @notice Thrown when threat analysis fails
    error ThreatAnalysisFailed(bytes32 poolId, string reason);
    
    /// @notice Thrown when encrypted data cannot be processed
    error EncryptedDataProcessingFailed(string operation);
    
    /// @notice Thrown when FHE operation fails
    error FHEOperationFailed(string operation, bytes data);
    
    /// @notice Thrown when detection engine is not calibrated
    error DetectionNotCalibrated(bytes32 poolId);
    
    // ============ Metrics Errors ============
    
    /// @notice Thrown when metrics update fails
    error MetricsUpdateFailed(bytes32 poolId, string reason);
    
    /// @notice Thrown when requesting metrics without permission
    error MetricsPermissionDenied(address requester, bytes32 poolId);
    
    /// @notice Thrown when decryption request is invalid
    error InvalidDecryptionRequest(bytes32 requestId, string reason);
    
    /// @notice Thrown when decryption result is not ready
    error DecryptionNotReady(bytes32 requestId);
    
    /// @notice Thrown when analytics calculation fails
    error AnalyticsCalculationFailed(string calculation, bytes32 poolId);
    
    // ============ Data Validation Errors ============
    
    /// @notice Thrown when swap data is invalid or corrupted
    error InvalidSwapData(string field, bytes data);
    
    /// @notice Thrown when encrypted values are out of expected range
    error EncryptedValueOutOfRange(string field, uint256 min, uint256 max);
    
    /// @notice Thrown when timestamp is invalid
    error InvalidTimestamp(uint256 timestamp, uint256 current);
    
    /// @notice Thrown when address is zero where not allowed
    error ZeroAddress(string parameter);
    
    /// @notice Thrown when array lengths don't match
    error ArrayLengthMismatch(uint256 expected, uint256 actual);
    
    // ============ State Errors ============
    
    /// @notice Thrown when operation is attempted while system is paused
    error SystemPaused();
    
    /// @notice Thrown when trying to pause already paused system
    error AlreadyPaused();
    
    /// @notice Thrown when trying to unpause already active system
    error AlreadyUnpaused();
    
    /// @notice Thrown when contract is in invalid state for operation
    error InvalidContractState(string expected, string actual);
    
    // ============ Computation Errors ============
    
    /// @notice Thrown when mathematical operation would overflow
    error MathOverflow(string operation);
    
    /// @notice Thrown when mathematical operation would underflow
    error MathUnderflow(string operation);
    
    /// @notice Thrown when division by zero is attempted
    error DivisionByZero(string operation);
    
    /// @notice Thrown when result is outside expected bounds
    error ResultOutOfBounds(uint256 result, uint256 min, uint256 max);
    
    // ============ Timing Errors ============
    
    /// @notice Thrown when operation is attempted too early
    error TooEarly(uint256 current, uint256 required);
    
    /// @notice Thrown when operation is attempted too late
    error TooLate(uint256 current, uint256 deadline);
    
    /// @notice Thrown when insufficient time has passed
    error InsufficientTimeElapsed(uint256 elapsed, uint256 required);
    
    /// @notice Thrown when execution window has closed
    error ExecutionWindowClosed(uint256 current, uint256 windowEnd);
    
    // ============ Integration Errors ============
    
    /// @notice Thrown when external contract call fails
    error ExternalCallFailed(address target, bytes4 selector);
    
    /// @notice Thrown when hook callback fails
    error HookCallbackFailed(bytes4 selector, bytes returnData);
    
    /// @notice Thrown when Uniswap V4 operation fails
    error UniswapOperationFailed(string operation, bytes returnData);
    
    /// @notice Thrown when FHE library operation fails
    error FHELibraryError(string function_, bytes errorData);
    
    // ============ Resource Errors ============
    
    /// @notice Thrown when insufficient gas for operation
    error InsufficientGas(uint256 required, uint256 available);
    
    /// @notice Thrown when storage limit is exceeded
    error StorageLimitExceeded(uint256 current, uint256 limit);
    
    /// @notice Thrown when rate limit is exceeded
    error RateLimitExceeded(address caller, uint256 limit);
    
    /// @notice Thrown when operation exceeds computational limits
    error ComputationalLimitExceeded(string operation, uint256 complexity);
}