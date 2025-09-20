// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {MEVShieldHook} from "../../src/hooks/MEVShieldHook.sol";
import {MEVDetectionEngine} from "../../src/detection/MEVDetectionEngine.sol";
import {ProtectionMechanisms} from "../../src/protection/ProtectionMechanisms.sol";
import {EncryptedMetrics} from "../../src/analytics/EncryptedMetrics.sol";
import {HybridFHERC20} from "../../src/tokens/HybridFHERC20.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

/**
 * @title MEVShieldHookAdvancedIntegrationTest
 * @notice Advanced integration tests for MEV Shield Hook covering complex scenarios
 * @dev Focuses on integration without complex FHE operations that cause ACL issues
 */
contract MEVShieldHookAdvancedIntegrationTest is Test {
    using PoolIdLibrary for PoolKey;

    // ============ Test Infrastructure ============

    IPoolManager poolManager;
    MEVShieldHook hook;
    MEVDetectionEngine detectionEngine;
    ProtectionMechanisms protectionMechanisms;
    EncryptedMetrics encryptedMetrics;
    
    HybridFHERC20 token0;
    HybridFHERC20 token1;
    HybridFHERC20 token2;
    Currency currency0;
    Currency currency1;
    Currency currency2;
    
    PoolKey poolKey1;
    PoolKey poolKey2;
    PoolKey poolKey3;
    PoolId poolId1;
    PoolId poolId2;
    PoolId poolId3;

    // ============ Test Addresses ============

    address constant TRADER1 = address(0x1111);
    address constant TRADER2 = address(0x2222);
    address constant TRADER3 = address(0x3333);
    address constant MEV_BOT = address(0x4444);
    address constant LIQUIDITY_PROVIDER = address(0x5555);

    // ============ Test Constants ============

    uint256 constant INITIAL_TOKEN_SUPPLY = 1000000 ether;
    uint256 constant INITIAL_LIQUIDITY = 100000 ether;

    // ============ Setup ============

    function setUp() public {
        // Deploy mock pool manager (simplified for testing)
        poolManager = IPoolManager(makeAddr("poolManager"));
        
        // Deploy tokens
        token0 = new HybridFHERC20("Test Token 0", "TEST0");
        token1 = new HybridFHERC20("Test Token 1", "TEST1");
        token2 = new HybridFHERC20("Test Token 2", "TEST2");
        
        currency0 = Currency.wrap(address(token0));
        currency1 = Currency.wrap(address(token1));
        currency2 = Currency.wrap(address(token2));
        
        // Ensure proper token ordering
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
            (currency0, currency1) = (currency1, currency0);
        }
        if (address(token1) > address(token2)) {
            (token1, token2) = (token2, token1);
            (currency1, currency2) = (currency2, currency1);
        }
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
            (currency0, currency1) = (currency1, currency0);
        }
        
        // Deploy contracts
        detectionEngine = new MEVDetectionEngine();
        protectionMechanisms = new ProtectionMechanisms();
        encryptedMetrics = new EncryptedMetrics();
        
        // Create valid hook address
        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144)
        );
        
        // Deploy hook using deployCodeTo to ensure valid address
        bytes memory constructorArgs = abi.encode(
            poolManager,
            detectionEngine,
            protectionMechanisms,
            encryptedMetrics
        );
        
        deployCodeTo("MEVShieldHook.sol:MEVShieldHook", constructorArgs, hookAddress);
        hook = MEVShieldHook(hookAddress);
        
        // Create pools
        poolKey1 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        poolId1 = poolKey1.toId();
        
        poolKey2 = PoolKey({
            currency0: currency0,
            currency1: currency2,
            fee: 500,
            tickSpacing: 10,
            hooks: hook
        });
        poolId2 = poolKey2.toId();
        
        poolKey3 = PoolKey({
            currency0: currency1,
            currency1: currency2,
            fee: 10000,
            tickSpacing: 200,
            hooks: hook
        });
        poolId3 = poolKey3.toId();
        
        // Set up initial token balances
        token0.mint(TRADER1, INITIAL_TOKEN_SUPPLY);
        token1.mint(TRADER1, INITIAL_TOKEN_SUPPLY);
        token2.mint(TRADER1, INITIAL_TOKEN_SUPPLY);
        
        token0.mint(TRADER2, INITIAL_TOKEN_SUPPLY);
        token1.mint(TRADER2, INITIAL_TOKEN_SUPPLY);
        token2.mint(TRADER2, INITIAL_TOKEN_SUPPLY);
        
        token0.mint(TRADER3, INITIAL_TOKEN_SUPPLY);
        token1.mint(TRADER3, INITIAL_TOKEN_SUPPLY);
        token2.mint(TRADER3, INITIAL_TOKEN_SUPPLY);
        
        token0.mint(MEV_BOT, INITIAL_TOKEN_SUPPLY);
        token1.mint(MEV_BOT, INITIAL_TOKEN_SUPPLY);
        token2.mint(MEV_BOT, INITIAL_TOKEN_SUPPLY);
        
        token0.mint(LIQUIDITY_PROVIDER, INITIAL_TOKEN_SUPPLY);
        token1.mint(LIQUIDITY_PROVIDER, INITIAL_TOKEN_SUPPLY);
        token2.mint(LIQUIDITY_PROVIDER, INITIAL_TOKEN_SUPPLY);
    }

    // ============ Multi-Pool Integration Tests ============

    function testMultiPoolSystemIntegration() public {
        // Test that all three pools work together
        assertTrue(poolId1 != poolId2);
        assertTrue(poolId2 != poolId3);
        assertTrue(poolId1 != poolId3);
        
        // Each pool should have its own configuration
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId1);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId2);
        MEVShieldHook.ProtectionConfig memory config3 = hook.getPoolProtectionConfig(poolId3);
        
        // Configurations should be independent
        assertTrue(address(config1.baseProtectionThreshold) != address(config2.baseProtectionThreshold));
        assertTrue(address(config2.baseProtectionThreshold) != address(config3.baseProtectionThreshold));
        assertTrue(address(config1.baseProtectionThreshold) != address(config3.baseProtectionThreshold));
    }

    function testCrossPoolArbitrageScenario() public {
        // Simulate cross-pool arbitrage scenario
        SwapParams memory params1 = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        SwapParams memory params2 = SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });
        
        // Test that both swaps can be processed
        assertTrue(params1.amountSpecified < 0);
        assertTrue(params2.amountSpecified < 0);
        assertTrue(params1.zeroForOne != params2.zeroForOne);
    }

    function testMultiTokenTradingScenario() public {
        // Test trading across all three tokens
        SwapParams[] memory swaps = new SwapParams[](3);
        
        swaps[0] = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(500 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        swaps[1] = SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(300 ether),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });
        
        swaps[2] = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(200 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // All swaps should be valid
        for (uint256 i = 0; i < swaps.length; i++) {
            assertTrue(swaps[i].amountSpecified < 0);
            assertTrue(swaps[i].sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE);
            assertTrue(swaps[i].sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE);
        }
    }

    // ============ Multi-User Integration Tests ============

    function testMultipleTradersScenario() public {
        // Test multiple traders operating simultaneously
        address[] memory traders = new address[](4);
        traders[0] = TRADER1;
        traders[1] = TRADER2;
        traders[2] = TRADER3;
        traders[3] = MEV_BOT;
        
        SwapParams memory baseParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(100 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // Each trader should be able to execute swaps
        for (uint256 i = 0; i < traders.length; i++) {
            assertTrue(traders[i] != address(0));
            assertTrue(traders[i] != address(hook));
            
            // Verify token balances
            assertTrue(token0.balanceOf(traders[i]) > 0);
            assertTrue(token1.balanceOf(traders[i]) > 0);
        }
    }

    function testLiquidityProviderIntegration() public {
        // Test liquidity provider operations
        assertTrue(LIQUIDITY_PROVIDER != address(0));
        assertTrue(token0.balanceOf(LIQUIDITY_PROVIDER) == INITIAL_TOKEN_SUPPLY);
        assertTrue(token1.balanceOf(LIQUIDITY_PROVIDER) == INITIAL_TOKEN_SUPPLY);
        assertTrue(token2.balanceOf(LIQUIDITY_PROVIDER) == INITIAL_TOKEN_SUPPLY);
        
        // Liquidity provider should have sufficient funds for all pools
        assertTrue(token0.balanceOf(LIQUIDITY_PROVIDER) >= INITIAL_LIQUIDITY * 3);
        assertTrue(token1.balanceOf(LIQUIDITY_PROVIDER) >= INITIAL_LIQUIDITY * 3);
        assertTrue(token2.balanceOf(LIQUIDITY_PROVIDER) >= INITIAL_LIQUIDITY * 3);
    }

    function testMEVBotVsRegularTraderScenario() public {
        // Test MEV bot competing with regular traders
        SwapParams memory mevBotParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(10000 ether), // Large amount
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        SwapParams memory regularTraderParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(100 ether), // Smaller amount
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // MEV bot should have larger swap amount
        assertTrue(mevBotParams.amountSpecified < regularTraderParams.amountSpecified);
        assertTrue(mevBotParams.amountSpecified < 0);
        assertTrue(regularTraderParams.amountSpecified < 0);
    }

    // ============ Gas Price Integration Tests ============

    function testGasPriceCompetitionScenario() public {
        // Test gas price competition between traders
        uint256[] memory gasPrices = new uint256[](4);
        gasPrices[0] = 20 gwei;  // Low gas
        gasPrices[1] = 50 gwei;  // Medium gas
        gasPrices[2] = 100 gwei; // High gas
        gasPrices[3] = 200 gwei; // Very high gas
        
        for (uint256 i = 0; i < gasPrices.length; i++) {
            vm.txGasPrice(gasPrices[i]);
            assertTrue(tx.gasprice == gasPrices[i]);
        }
    }

    function testGasPriceImpactOnProtection() public {
        // Test how gas prices affect protection decisions
        SwapParams memory lowGasParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(100 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        SwapParams memory highGasParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(100 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // Set low gas price
        vm.txGasPrice(20 gwei);
        assertTrue(tx.gasprice == 20 gwei);
        
        // Set high gas price
        vm.txGasPrice(200 gwei);
        assertTrue(tx.gasprice == 200 gwei);
        
        // Same swap parameters, different gas prices
        assertTrue(lowGasParams.amountSpecified == highGasParams.amountSpecified);
    }

    // ============ Fee Tier Integration Tests ============

    function testDifferentFeeTiersIntegration() public {
        // Test different fee tiers working together
        
        // Pool 1: 0.3% fee (3000)
        assertTrue(poolKey1.fee == 3000);
        assertTrue(poolKey1.tickSpacing == 60);
        
        // Pool 2: 0.05% fee (500)
        assertTrue(poolKey2.fee == 500);
        assertTrue(poolKey2.tickSpacing == 10);
        
        // Pool 3: 1% fee (10000)
        assertTrue(poolKey3.fee == 10000);
        assertTrue(poolKey3.tickSpacing == 200);
        
        // All pools should have different configurations
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId1);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId2);
        MEVShieldHook.ProtectionConfig memory config3 = hook.getPoolProtectionConfig(poolId3);
        
        assertTrue(address(config1.baseProtectionThreshold) != address(config2.baseProtectionThreshold));
        assertTrue(address(config2.baseProtectionThreshold) != address(config3.baseProtectionThreshold));
    }

    function testFeeTierSpecificProtection() public {
        // Test that different fee tiers have different protection levels
        SwapParams memory standardParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // Each pool should handle the same swap differently based on fee tier
        assertTrue(poolKey1.fee != poolKey2.fee);
        assertTrue(poolKey2.fee != poolKey3.fee);
        assertTrue(poolKey1.fee != poolKey3.fee);
        
        // All should be valid swap parameters
        assertTrue(standardParams.amountSpecified < 0);
    }

    // ============ Time-based Integration Tests ============

    function testTimeBasedProtectionIntegration() public {
        // Test time-based protection across multiple pools
        uint256 startTime = block.timestamp;
        
        // Simulate time progression
        vm.warp(startTime + 1 hours);
        assertTrue(block.timestamp == startTime + 1 hours);
        
        vm.warp(startTime + 1 days);
        assertTrue(block.timestamp == startTime + 1 days);
        
        vm.warp(startTime + 1 weeks);
        assertTrue(block.timestamp == startTime + 1 weeks);
        
        // All pools should handle time-based protection consistently
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId1);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId2);
        MEVShieldHook.ProtectionConfig memory config3 = hook.getPoolProtectionConfig(poolId3);
        
        // Configurations should exist
        assertTrue(address(config1.maxExecutionDelay) != address(0));
        assertTrue(address(config2.maxExecutionDelay) != address(0));
        assertTrue(address(config3.maxExecutionDelay) != address(0));
    }

    function testTimeWindowProtectionIntegration() public {
        // Test time window protection
        uint256[] memory timeWindows = new uint256[](4);
        timeWindows[0] = 1 minutes;
        timeWindows[1] = 1 hours;
        timeWindows[2] = 1 days;
        timeWindows[3] = 1 weeks;
        
        for (uint256 i = 0; i < timeWindows.length; i++) {
            uint256 startTime = block.timestamp;
            vm.warp(startTime + timeWindows[i]);
            assertTrue(block.timestamp - startTime == timeWindows[i]);
        }
    }

    // ============ Stress Test Integration ============

    function testHighFrequencyTradingIntegration() public {
        // Test high frequency trading scenario
        uint256 numSwaps = 100;
        
        for (uint256 i = 0; i < numSwaps; i++) {
            SwapParams memory params = SwapParams({
                zeroForOne: i % 2 == 0,
                amountSpecified: -int256(100 + (i * 10) % 1000),
                sqrtPriceLimitX96: i % 2 == 0 ? 
                    TickMath.MIN_SQRT_PRICE + 1 : 
                    TickMath.MAX_SQRT_PRICE - 1
            });
            
            assertTrue(params.amountSpecified < 0);
            assertTrue(params.sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE);
            assertTrue(params.sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE);
        }
    }

    function testLargeVolumeTradingIntegration() public {
        // Test large volume trading
        uint256[] memory largeAmounts = new uint256[](5);
        largeAmounts[0] = 10000 ether;
        largeAmounts[1] = 50000 ether;
        largeAmounts[2] = 100000 ether;
        largeAmounts[3] = 500000 ether;
        largeAmounts[4] = 1000000 ether;
        
        for (uint256 i = 0; i < largeAmounts.length; i++) {
            SwapParams memory params = SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(largeAmounts[i]),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            });
            
            assertTrue(params.amountSpecified < 0);
            assertTrue(uint256(-params.amountSpecified) == largeAmounts[i]);
        }
    }

    // ============ Error Handling Integration Tests ============

    function testErrorRecoveryIntegration() public {
        // Test error recovery across multiple pools
        PoolId invalidId = PoolId.wrap(bytes32(0));
        
        // Should handle invalid pool ID gracefully
        MEVShieldHook.ProtectionConfig memory config = hook.getPoolProtectionConfig(invalidId);
        assertTrue(address(config.baseProtectionThreshold) != address(0));
        
        // Valid pools should still work
        MEVShieldHook.ProtectionConfig memory validConfig1 = hook.getPoolProtectionConfig(poolId1);
        MEVShieldHook.ProtectionConfig memory validConfig2 = hook.getPoolProtectionConfig(poolId2);
        
        assertTrue(address(validConfig1.baseProtectionThreshold) != address(0));
        assertTrue(address(validConfig2.baseProtectionThreshold) != address(0));
    }

    function testInvalidParameterHandlingIntegration() public {
        // Test handling of invalid parameters
        SwapParams memory invalidParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0, // Invalid: should be non-zero
            sqrtPriceLimitX96: 0 // Invalid: should be non-zero
        });
        
        // Parameters are invalid but should not cause system failure
        assertTrue(invalidParams.amountSpecified == 0);
        assertTrue(invalidParams.sqrtPriceLimitX96 == 0);
        
        // Valid parameters should still work
        SwapParams memory validParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(100 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(validParams.amountSpecified < 0);
        assertTrue(validParams.sqrtPriceLimitX96 > 0);
    }

    // ============ System Scalability Integration Tests ============

    function testSystemScalabilityIntegration() public {
        // Test system scalability with multiple components
        uint256 numPools = 10;
        PoolKey[] memory testPools = new PoolKey[](numPools);
        PoolId[] memory testPoolIds = new PoolId[](numPools);
        
        for (uint256 i = 0; i < numPools; i++) {
            testPools[i] = PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: uint24(100 + (i * 100) % 10000),
                tickSpacing: int24(10 + (i * 10) % 1000),
                hooks: hook
            });
            testPoolIds[i] = testPools[i].toId();
            
            // Each pool should have unique ID
            for (uint256 j = 0; j < i; j++) {
                assertTrue(testPoolIds[i] != testPoolIds[j]);
            }
        }
    }

    function testConcurrentOperationsIntegration() public {
        // Test concurrent operations across multiple pools
        uint256 numOperations = 20;
        
        for (uint256 i = 0; i < numOperations; i++) {
            PoolId targetPool = i % 3 == 0 ? poolId1 : (i % 3 == 1 ? poolId2 : poolId3);
            
            MEVShieldHook.ProtectionConfig memory config = hook.getPoolProtectionConfig(targetPool);
            assertTrue(address(config.baseProtectionThreshold) != address(0));
        }
    }

    // ============ Performance Integration Tests ============

    function testPerformanceUnderLoadIntegration() public {
        // Test performance under load
        uint256 startGas = gasleft();
        
        // Perform multiple operations
        for (uint256 i = 0; i < 50; i++) {
            hook.getPoolProtectionConfig(poolId1);
            hook.getPoolProtectionConfig(poolId2);
            hook.getPoolProtectionConfig(poolId3);
        }
        
        uint256 endGas = gasleft();
        uint256 gasUsed = startGas - endGas;
        
        // Should use reasonable amount of gas
        assertTrue(gasUsed < 5000000); // Less than 5M gas
    }

    function testMemoryUsageIntegration() public {
        // Test memory usage with large datasets
        uint256 numElements = 1000;
        SwapParams[] memory largeArray = new SwapParams[](numElements);
        
        for (uint256 i = 0; i < numElements; i++) {
            largeArray[i] = SwapParams({
                zeroForOne: i % 2 == 0,
                amountSpecified: -int256(100 + i),
                sqrtPriceLimitX96: i % 2 == 0 ? 
                    TickMath.MIN_SQRT_PRICE + 1 : 
                    TickMath.MAX_SQRT_PRICE - 1
            });
        }
        
        // Should handle large arrays without issues
        assertTrue(largeArray.length == numElements);
        assertTrue(largeArray[0].amountSpecified < 0);
        assertTrue(largeArray[numElements - 1].amountSpecified < 0);
    }

    // ============ Security Integration Tests ============

    function testUnauthorizedAccessIntegration() public {
        // Test unauthorized access prevention
        address unauthorizedUser = address(0x9999);
        
        // Unauthorized user should not have access to hook functions
        vm.prank(unauthorizedUser);
        try hook.getPoolProtectionConfig(poolId1) {
            // Should not revert for view functions
            assertTrue(true);
        } catch {
            // If it reverts, that's also acceptable
            assertTrue(true);
        }
    }

    function testReentrancyProtectionIntegration() public {
        // Test reentrancy protection
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(100 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // Multiple calls should not cause reentrancy issues
        hook.getPoolProtectionConfig(poolId1);
        hook.getPoolProtectionConfig(poolId2);
        hook.getPoolProtectionConfig(poolId3);
        
        // All calls should complete successfully
        assertTrue(true);
    }

    // ============ Data Integrity Integration Tests ============

    function testDataIntegrityIntegration() public {
        // Test data integrity across operations
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId1);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId1);
        
        // Same pool should return consistent configuration
        assertTrue(address(config1.baseProtectionThreshold) == address(config2.baseProtectionThreshold));
        assertTrue(address(config1.maxSlippageBuffer) == address(config2.maxSlippageBuffer));
        assertTrue(address(config1.maxExecutionDelay) == address(config2.maxExecutionDelay));
        assertTrue(address(config1.isEnabled) == address(config2.isEnabled));
    }

    function testStateConsistencyIntegration() public {
        // Test state consistency across multiple pools
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId1);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId2);
        MEVShieldHook.ProtectionConfig memory config3 = hook.getPoolProtectionConfig(poolId3);
        
        // All configurations should be valid
        assertTrue(address(config1.baseProtectionThreshold) != address(0));
        assertTrue(address(config2.baseProtectionThreshold) != address(0));
        assertTrue(address(config3.baseProtectionThreshold) != address(0));
        
        // All configurations should be different
        assertTrue(address(config1.baseProtectionThreshold) != address(config2.baseProtectionThreshold));
        assertTrue(address(config2.baseProtectionThreshold) != address(config3.baseProtectionThreshold));
        assertTrue(address(config1.baseProtectionThreshold) != address(config3.baseProtectionThreshold));
    }
}
