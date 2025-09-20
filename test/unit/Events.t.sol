// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Events} from "../../src/utils/Events.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

contract EventsTest is Test {
    PoolId poolId = PoolId.wrap(bytes32(uint256(1)));
    address trader = makeAddr("trader");
    address admin = makeAddr("admin");

    function testMEVProtectionAppliedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.MEVProtectionApplied(poolId, trader, 85, 500, 2, 1e18);
        
        // Emit the event
        emit Events.MEVProtectionApplied(poolId, trader, 85, 500, 2, 1e18);
    }

    function testMEVThreatDetectedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Events.MEVThreatDetected(poolId, trader, 1, 85, 1e18);
        
        // Emit the event
        emit Events.MEVThreatDetected(poolId, trader, 1, 85, 1e18);
    }

    function testPoolProtectionConfiguredEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.PoolProtectionConfigured(poolId, admin, 75, 500, 2);
        
        // Emit the event
        emit Events.PoolProtectionConfigured(poolId, admin, 75, 500, 2);
    }

    function testDetectionCalibratedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.DetectionCalibrated(poolId, admin, 80, 75);
        
        // Emit the event
        emit Events.DetectionCalibrated(poolId, admin, 80, 75);
    }

    function testPoolMetricsUpdatedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.PoolMetricsUpdated(poolId, 1, block.number);
        
        // Emit the event
        emit Events.PoolMetricsUpdated(poolId, 1, block.number);
    }

    function testThreatAnalysisCompletedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Events.ThreatAnalysisCompleted(poolId, trader, 1, true);
        
        // Emit the event
        emit Events.ThreatAnalysisCompleted(poolId, trader, 1, true);
    }

    function testSlippageProtectionAppliedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.SlippageProtectionApplied(poolId, trader, 100, 150, 50);
        
        // Emit the event
        emit Events.SlippageProtectionApplied(poolId, trader, 100, 150, 50);
    }

    function testTimingProtectionAppliedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.TimingProtectionApplied(poolId, trader, block.number, block.number + 2, 2);
        
        // Emit the event
        emit Events.TimingProtectionApplied(poolId, trader, block.number, block.number + 2, 2);
    }

    function testGasPriceOptimizedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.GasPriceOptimized(poolId, trader, 50e9, 55e9, 110);
        
        // Emit the event
        emit Events.GasPriceOptimized(poolId, trader, 50e9, 55e9, 110);
    }

    function testSwapMetricsUpdatedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.SwapMetricsUpdated(poolId, trader, 85, 1e18, true);
        
        // Emit the event
        emit Events.SwapMetricsUpdated(poolId, trader, 85, 1e18, true);
    }

    function testUserAnalyticsUpdatedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.UserAnalyticsUpdated(trader, poolId, 5e18, 10);
        
        // Emit the event
        emit Events.UserAnalyticsUpdated(trader, poolId, 5e18, 10);
    }

    function testThreatProfileUpdatedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.ThreatProfileUpdated(poolId, 1, 10, 85);
        
        // Emit the event
        emit Events.ThreatProfileUpdated(poolId, 1, 10, 85);
    }

    function testGlobalEffectivenessCalculatedEvent() public {
        vm.expectEmit(false, false, false, true);
        emit Events.GlobalEffectivenessCalculated(1000, 100, 80, 80);
        
        // Emit the event
        emit Events.GlobalEffectivenessCalculated(1000, 100, 80, 80);
    }

    function testAnalyticsPermissionGrantedEvent() public {
        address grantee = makeAddr("grantee");
        vm.expectEmit(true, true, true, true);
        emit Events.AnalyticsPermissionGranted(poolId, admin, grantee, 1);
        
        // Emit the event
        emit Events.AnalyticsPermissionGranted(poolId, admin, grantee, 1);
    }

    function testAnalyticsPermissionRevokedEvent() public {
        address revokee = makeAddr("revokee");
        vm.expectEmit(true, true, true, true);
        emit Events.AnalyticsPermissionRevoked(poolId, admin, revokee, 1);
        
        // Emit the event
        emit Events.AnalyticsPermissionRevoked(poolId, admin, revokee, 1);
    }

    function testMetricsDecryptionRequestedEvent() public {
        bytes32 requestId = keccak256("test");
        vm.expectEmit(true, true, true, true);
        emit Events.MetricsDecryptionRequested(poolId, trader, 1, requestId);
        
        // Emit the event
        emit Events.MetricsDecryptionRequested(poolId, trader, 1, requestId);
    }

    function testMetricsDecryptionCompletedEvent() public {
        bytes32 requestId = keccak256("test");
        vm.expectEmit(true, true, true, true);
        emit Events.MetricsDecryptionCompleted(poolId, trader, 1, requestId, true);
        
        // Emit the event
        emit Events.MetricsDecryptionCompleted(poolId, trader, 1, requestId, true);
    }

    function testSystemConfigurationUpdatedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.SystemConfigurationUpdated(admin, 1, 100, 200);
        
        // Emit the event
        emit Events.SystemConfigurationUpdated(admin, 1, 100, 200);
    }

    function testSystemPauseStateChangedEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Events.SystemPauseStateChanged(admin, true, "Emergency pause");
        
        // Emit the event
        emit Events.SystemPauseStateChanged(admin, true, "Emergency pause");
    }
}