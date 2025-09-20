// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Constants} from "../../src/utils/Constants.sol";

contract ConstantsTest is Test {
    function testProtectionThresholds() public {
        assertEq(Constants.DEFAULT_PROTECTION_THRESHOLD, 75);
        assertEq(Constants.MAX_PROTECTION_THRESHOLD, 95);
        assertEq(Constants.MIN_PROTECTION_THRESHOLD, 25);
        assertTrue(Constants.MIN_PROTECTION_THRESHOLD < Constants.DEFAULT_PROTECTION_THRESHOLD);
        assertTrue(Constants.DEFAULT_PROTECTION_THRESHOLD < Constants.MAX_PROTECTION_THRESHOLD);
    }

    function testSlippageProtection() public {
        assertEq(Constants.DEFAULT_MAX_SLIPPAGE_BUFFER, 500); // 5%
        assertEq(Constants.MAX_SLIPPAGE_BUFFER, 1000); // 10%
        assertEq(Constants.MIN_SLIPPAGE_BUFFER, 50); // 0.5%
        assertTrue(Constants.MIN_SLIPPAGE_BUFFER < Constants.DEFAULT_MAX_SLIPPAGE_BUFFER);
        assertTrue(Constants.DEFAULT_MAX_SLIPPAGE_BUFFER < Constants.MAX_SLIPPAGE_BUFFER);
    }

    function testTimingProtection() public {
        assertEq(Constants.DEFAULT_MAX_EXECUTION_DELAY, 2);
        assertEq(Constants.MAX_EXECUTION_DELAY, 5);
        assertEq(Constants.MIN_EXECUTION_DELAY, 1);
        assertTrue(Constants.MIN_EXECUTION_DELAY < Constants.DEFAULT_MAX_EXECUTION_DELAY);
        assertTrue(Constants.DEFAULT_MAX_EXECUTION_DELAY < Constants.MAX_EXECUTION_DELAY);
    }

    function testGasOptimization() public {
        assertEq(Constants.DEFAULT_GAS_OPTIMIZATION_FACTOR, 110); // 1.1x
        assertEq(Constants.MAX_GAS_OPTIMIZATION_FACTOR, 150); // 1.5x
        assertEq(Constants.MIN_GAS_OPTIMIZATION_FACTOR, 100); // 1.0x
        assertTrue(Constants.MIN_GAS_OPTIMIZATION_FACTOR <= Constants.DEFAULT_GAS_OPTIMIZATION_FACTOR);
        assertTrue(Constants.DEFAULT_GAS_OPTIMIZATION_FACTOR < Constants.MAX_GAS_OPTIMIZATION_FACTOR);
    }

    function testRiskAssessment() public {
        assertEq(Constants.HIGH_RISK_THRESHOLD, 85);
        assertEq(Constants.MEDIUM_RISK_THRESHOLD, 65);
        assertEq(Constants.LOW_RISK_THRESHOLD, 35);
        assertTrue(Constants.LOW_RISK_THRESHOLD < Constants.MEDIUM_RISK_THRESHOLD);
        assertTrue(Constants.MEDIUM_RISK_THRESHOLD < Constants.HIGH_RISK_THRESHOLD);
    }

    function testPoolAnalysis() public {
        assertEq(Constants.LARGE_SWAP_THRESHOLD, 300); // 3% of pool
        assertEq(Constants.MEV_ANALYSIS_WINDOW, 10);
        assertEq(Constants.MIN_TIME_BETWEEN_LARGE_SWAPS, 2);
        assertTrue(Constants.MIN_TIME_BETWEEN_LARGE_SWAPS < Constants.MEV_ANALYSIS_WINDOW);
    }

    function testEffectivenessCalculation() public {
        assertEq(Constants.EFFECTIVENESS_WINDOW, 1000);
        assertEq(Constants.MIN_EFFECTIVENESS_SAMPLES, 10);
        assertTrue(Constants.MIN_EFFECTIVENESS_SAMPLES < Constants.EFFECTIVENESS_WINDOW);
    }

    function testPercentageCalculations() public {
        assertEq(Constants.BASIS_POINTS, 10000);
        assertEq(Constants.PERCENTAGE, 100);
        assertTrue(Constants.PERCENTAGE < Constants.BASIS_POINTS);
    }

    function testFHEConstants() public {
        assertEq(Constants.MAX_RISK_SCORE, 100);
        assertEq(Constants.ENCRYPTED_ZERO, 0);
        assertEq(Constants.ENCRYPTED_ONE, 1);
        assertTrue(Constants.ENCRYPTED_ZERO < Constants.ENCRYPTED_ONE);
        assertTrue(Constants.ENCRYPTED_ONE < Constants.MAX_RISK_SCORE);
    }

    function testTimeConstants() public {
        assertEq(Constants.SECONDS_PER_BLOCK, 12);
        assertEq(Constants.BLOCKS_PER_HOUR, 300);
        assertEq(Constants.BLOCKS_PER_DAY, 7200);
        assertTrue(Constants.SECONDS_PER_BLOCK > 0);
        assertTrue(Constants.BLOCKS_PER_HOUR == 3600 / Constants.SECONDS_PER_BLOCK);
        assertTrue(Constants.BLOCKS_PER_DAY == 24 * Constants.BLOCKS_PER_HOUR);
    }

    function testMEVPatternConstants() public {
        assertEq(Constants.MAX_FRONTRUN_WINDOW, 3);
        assertEq(Constants.SANDWICH_DETECTION_WINDOW, 5);
        assertEq(Constants.MIN_MEV_GAS_PREMIUM, 110); // 1.1x
        assertTrue(Constants.MAX_FRONTRUN_WINDOW < Constants.SANDWICH_DETECTION_WINDOW);
        assertTrue(Constants.MIN_MEV_GAS_PREMIUM > 100); // Should be > 1.0x
    }

    function testPoolClassification() public {
        assertEq(Constants.HIGH_VOLATILITY_THRESHOLD, 50); // 0.5% per block
        assertEq(Constants.LOW_LIQUIDITY_THRESHOLD, 100); // 1% of total supply
        assertTrue(Constants.HIGH_VOLATILITY_THRESHOLD > 0);
        assertTrue(Constants.LOW_LIQUIDITY_THRESHOLD > 0);
    }

    function testAnalyticsConstants() public {
        assertEq(Constants.MAX_HISTORICAL_POINTS, 1000);
        assertEq(Constants.MIN_CONFIDENCE_LEVEL, 9000); // 90%
        assertEq(Constants.DEFAULT_ANALYTICS_WINDOW, 100);
        assertTrue(Constants.DEFAULT_ANALYTICS_WINDOW < Constants.MAX_HISTORICAL_POINTS);
        assertTrue(Constants.MIN_CONFIDENCE_LEVEL > 8000); // Should be high confidence
    }
}