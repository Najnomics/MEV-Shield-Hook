// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Errors} from "../../src/utils/Errors.sol";

contract ErrorReverter {
    function revertWithUnauthorized(address caller, address required) external pure {
        revert Errors.Unauthorized(caller, required);
    }
    
    function revertWithPoolNotInitialized(bytes32 poolId) external pure {
        revert Errors.PoolNotInitialized(poolId);
    }
    
    function revertWithSystemPaused() external pure {
        revert Errors.SystemPaused();
    }
    
    function revertWithInvalidThreshold(uint64 threshold, uint64 min, uint64 max) external pure {
        revert Errors.InvalidProtectionThreshold(threshold, min, max);
    }
    
    function revertWithZeroAddress(string memory param) external pure {
        revert Errors.ZeroAddress(param);
    }
    
    function revertWithInvalidSlippageBuffer(uint64 buffer, uint64 max) external pure {
        revert Errors.InvalidSlippageBuffer(buffer, max);
    }
    
    function revertWithInvalidExecutionDelay(uint32 delay, uint32 max) external pure {
        revert Errors.InvalidExecutionDelay(delay, max);
    }
    
    function revertWithInvalidSensitivityLevel(uint8 level) external pure {
        revert Errors.InvalidSensitivityLevel(level);
    }
    
    function revertWithAnalyticsAccessDenied(address caller_, bytes32 poolId) external pure {
        revert Errors.AnalyticsAccessDenied(caller_, poolId);
    }
    
    function revertWithMetricsPermissionDenied(address requester, bytes32 poolId) external pure {
        revert Errors.MetricsPermissionDenied(requester, poolId);
    }
}

contract ErrorsTest is Test {
    ErrorReverter reverter;
    address caller = makeAddr("caller");
    address required = makeAddr("required");
    bytes32 poolId = bytes32(uint256(1));

    function setUp() public {
        reverter = new ErrorReverter();
    }

    function testUnauthorizedError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, caller, required));
        reverter.revertWithUnauthorized(caller, required);
    }

    function testPoolNotInitializedError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.PoolNotInitialized.selector, poolId));
        reverter.revertWithPoolNotInitialized(poolId);
    }

    function testSystemPausedError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.SystemPaused.selector));
        reverter.revertWithSystemPaused();
    }

    function testInvalidProtectionThresholdError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidProtectionThreshold.selector, 150, 25, 95));
        reverter.revertWithInvalidThreshold(150, 25, 95);
    }

    function testZeroAddressError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroAddress.selector, "owner"));
        reverter.revertWithZeroAddress("owner");
    }

    function testInvalidSlippageBufferError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSlippageBuffer.selector, 2000, 1000));
        reverter.revertWithInvalidSlippageBuffer(2000, 1000);
    }

    function testInvalidExecutionDelayError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidExecutionDelay.selector, 10, 5));
        reverter.revertWithInvalidExecutionDelay(10, 5);
    }

    function testInvalidSensitivityLevelError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidSensitivityLevel.selector, 150));
        reverter.revertWithInvalidSensitivityLevel(150);
    }

    function testAnalyticsAccessDeniedError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AnalyticsAccessDenied.selector, caller, poolId));
        reverter.revertWithAnalyticsAccessDenied(caller, poolId);
    }

    function testMetricsPermissionDeniedError() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.MetricsPermissionDenied.selector, caller, poolId));
        reverter.revertWithMetricsPermissionDenied(caller, poolId);
    }

    // Test that error library compiles and selectors are accessible
    function testErrorSelectorsExist() public {
        // Test some key error selectors exist
        assertTrue(Errors.Unauthorized.selector != bytes4(0));
        assertTrue(Errors.PoolNotInitialized.selector != bytes4(0));
        assertTrue(Errors.SystemPaused.selector != bytes4(0));
        assertTrue(Errors.InvalidProtectionThreshold.selector != bytes4(0));
        assertTrue(Errors.ZeroAddress.selector != bytes4(0));
        assertTrue(Errors.AnalyticsAccessDenied.selector != bytes4(0));
        assertTrue(Errors.MetricsPermissionDenied.selector != bytes4(0));
        assertTrue(Errors.InvalidDecryptionRequest.selector != bytes4(0));
        assertTrue(Errors.ThreatAnalysisFailed.selector != bytes4(0));
        assertTrue(Errors.MathOverflow.selector != bytes4(0));
    }
}