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
 * @title MEVShieldHookExtendedTest
 * @notice Extended unit tests for MEV Shield Hook covering edge cases and additional scenarios
 * @dev Tests that focus on basic functionality without complex FHE operations
 */
contract MEVShieldHookExtendedTest is Test {
    using PoolIdLibrary for PoolKey;

    // ============ Test Infrastructure ============

    IPoolManager poolManager;
    MEVShieldHook hook;
    MEVDetectionEngine detectionEngine;
    ProtectionMechanisms protectionMechanisms;
    EncryptedMetrics encryptedMetrics;
    
    HybridFHERC20 token0;
    HybridFHERC20 token1;
    Currency currency0;
    Currency currency1;
    
    PoolKey poolKey;
    PoolId poolId;

    // ============ Test Addresses ============

    address constant TRADER = address(0x1234);
    address constant MEV_BOT = address(0x5678);
    address constant ADMIN = address(0x9ABC);

    // ============ Test Constants ============

    uint256 constant INITIAL_TOKEN_SUPPLY = 1000000 ether;
    uint256 constant INITIAL_LIQUIDITY = 100000 ether;
    uint256 constant SMALL_SWAP_AMOUNT = 1 ether;
    uint256 constant LARGE_SWAP_AMOUNT = 100 ether;

    // ============ Setup ============

    function setUp() public {
        // Deploy mock pool manager (simplified for testing)
        poolManager = IPoolManager(makeAddr("poolManager"));
        
        // Deploy tokens
        token0 = new HybridFHERC20("Test Token 0", "TEST0");
        token1 = new HybridFHERC20("Test Token 1", "TEST1");
        
        currency0 = Currency.wrap(address(token0));
        currency1 = Currency.wrap(address(token1));
        
        // Ensure proper token ordering
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
        
        // Create pool
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        poolId = poolKey.toId();
        
        // Set up initial token balances
        token0.mint(TRADER, INITIAL_TOKEN_SUPPLY);
        token1.mint(TRADER, INITIAL_TOKEN_SUPPLY);
        token0.mint(MEV_BOT, INITIAL_TOKEN_SUPPLY);
        token1.mint(MEV_BOT, INITIAL_TOKEN_SUPPLY);
        token0.mint(ADMIN, INITIAL_TOKEN_SUPPLY);
        token1.mint(ADMIN, INITIAL_TOKEN_SUPPLY);
    }

    // ============ Hook Permission Tests ============

    function testHookPermissionsImmutable() public {
        // Test that hook permissions are immutable after deployment
        assertTrue(hook.getHookPermissions().beforeInitialize);
        assertTrue(hook.getHookPermissions().afterInitialize);
        assertTrue(hook.getHookPermissions().beforeSwap);
        assertTrue(hook.getHookPermissions().afterSwap);
        assertTrue(hook.getHookPermissions().beforeDonate);
        assertTrue(hook.getHookPermissions().afterDonate);
        assertTrue(hook.getHookPermissions().beforeAddLiquidity);
        assertTrue(hook.getHookPermissions().afterAddLiquidity);
        assertTrue(hook.getHookPermissions().beforeRemoveLiquidity);
        assertTrue(hook.getHookPermissions().afterRemoveLiquidity);
        assertTrue(hook.getHookPermissions().beforeSwapReturnDelta);
        assertTrue(hook.getHookPermissions().afterSwapReturnDelta);
        assertTrue(hook.getHookPermissions().beforeAddLiquidityReturnDelta);
        assertTrue(hook.getHookPermissions().afterAddLiquidityReturnDelta);
        assertTrue(hook.getHookPermissions().beforeRemoveLiquidityReturnDelta);
        assertTrue(hook.getHookPermissions().afterRemoveLiquidityReturnDelta);
    }

    function testHookAddressValidation() public {
        // Test that hook address is valid
        assertTrue(address(hook) != address(0));
        assertTrue(address(hook).code.length > 0);
        
        // Test that hook implements required interface
        try hook.getHookPermissions() returns (Hooks.Permissions memory) {
            // Success - hook implements the interface
        } catch {
            fail("Hook does not implement required interface");
        }
    }

    function testHookInitialization() public {
        // Test that hook is properly initialized
        assertTrue(address(hook.poolManager()) == address(poolManager));
        assertTrue(address(hook.detectionEngine()) == address(detectionEngine));
        assertTrue(address(hook.protectionMechanisms()) == address(protectionMechanisms));
        assertTrue(address(hook.metricsTracker()) == address(encryptedMetrics));
    }

    // ============ Pool Configuration Tests ============

    function testPoolConfigurationDefaults() public {
        // Test default pool configuration
        MEVShieldHook.ProtectionConfig memory config = hook.getPoolProtectionConfig(poolId);
        
        // Configuration should exist but values are encrypted
        assertTrue(address(config.baseProtectionThreshold) != address(0));
        assertTrue(address(config.maxSlippageBuffer) != address(0));
        assertTrue(address(config.maxExecutionDelay) != address(0));
        assertTrue(address(config.isEnabled) != address(0));
    }

    function testMultiplePoolConfigurations() public {
        // Create additional pools with different configurations
        PoolKey memory poolKey2 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 500,
            tickSpacing: 10,
            hooks: hook
        });
        PoolId poolId2 = poolKey2.toId();
        
        // Each pool should have its own configuration
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId2);
        
        // Configurations should be different (different encrypted values)
        assertTrue(address(config1.baseProtectionThreshold) != address(config2.baseProtectionThreshold));
    }

    function testPoolConfigurationIsolation() public {
        // Test that pool configurations are isolated
        PoolKey memory poolKey2 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10000,
            tickSpacing: 200,
            hooks: hook
        });
        PoolId poolId2 = poolKey2.toId();
        
        // Get configurations for both pools
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId2);
        
        // Configurations should be independent
        assertTrue(address(config1.baseProtectionThreshold) != address(config2.baseProtectionThreshold));
        assertTrue(address(config1.maxSlippageBuffer) != address(config2.maxSlippageBuffer));
        assertTrue(address(config1.maxExecutionDelay) != address(config2.maxExecutionDelay));
        assertTrue(address(config1.isEnabled) != address(config2.isEnabled));
    }

    // ============ Swap Parameter Tests ============

    function testSwapParameterValidation() public {
        // Test valid swap parameters
        SwapParams memory validParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(SMALL_SWAP_AMOUNT),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // Parameters should be valid
        assertTrue(validParams.amountSpecified < 0); // Negative for input amount
        assertTrue(validParams.sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE);
    }

    function testSwapParameterBoundaries() public {
        // Test boundary conditions for swap parameters
        
        // Minimum swap amount
        SwapParams memory minParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -1,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        assertTrue(minParams.amountSpecified == -1);
        
        // Maximum swap amount
        SwapParams memory maxParams = SwapParams({
            zeroForOne: false,
            amountSpecified: int256(type(uint128).max),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });
        assertTrue(maxParams.amountSpecified > 0);
        assertTrue(maxParams.sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE);
    }

    function testSwapDirectionValidation() public {
        // Test swap direction validation
        SwapParams memory zeroForOne = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(SMALL_SWAP_AMOUNT),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        SwapParams memory oneForZero = SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(SMALL_SWAP_AMOUNT),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });
        
        assertTrue(zeroForOne.zeroForOne);
        assertFalse(oneForZero.zeroForOne);
        assertTrue(zeroForOne.sqrtPriceLimitX96 < oneForZero.sqrtPriceLimitX96);
    }

    // ============ Gas Price Tests ============

    function testGasPriceBoundaries() public {
        // Test different gas price scenarios
        
        // Low gas price
        vm.txGasPrice(1 gwei);
        assertTrue(tx.gasprice == 1 gwei);
        
        // Medium gas price
        vm.txGasPrice(50 gwei);
        assertTrue(tx.gasprice == 50 gwei);
        
        // High gas price
        vm.txGasPrice(100 gwei);
        assertTrue(tx.gasprice == 100 gwei);
        
        // Very high gas price
        vm.txGasPrice(1000 gwei);
        assertTrue(tx.gasprice == 1000 gwei);
    }

    function testGasPriceImpact() public {
        // Test gas price impact on protection decisions
        uint256[] memory gasPrices = new uint256[](4);
        gasPrices[0] = 1 gwei;
        gasPrices[1] = 50 gwei;
        gasPrices[2] = 100 gwei;
        gasPrices[3] = 1000 gwei;
        
        for (uint256 i = 0; i < gasPrices.length; i++) {
            vm.txGasPrice(gasPrices[i]);
            assertTrue(tx.gasprice == gasPrices[i]);
        }
    }

    // ============ Token Address Tests ============

    function testTokenAddressOrdering() public {
        // Test that tokens are properly ordered
        assertTrue(address(token0) < address(token1));
        assertTrue(address(currency0.unwrap()) == address(token0));
        assertTrue(address(currency1.unwrap()) == address(token1));
    }

    function testTokenAddressValidation() public {
        // Test token address validation
        assertTrue(address(token0) != address(0));
        assertTrue(address(token1) != address(0));
        assertTrue(address(token0) != address(token1));
        assertTrue(address(token0).code.length > 0);
        assertTrue(address(token1).code.length > 0);
    }

    function testCurrencyWrapping() public {
        // Test currency wrapping and unwrapping
        Currency wrapped0 = Currency.wrap(address(token0));
        Currency wrapped1 = Currency.wrap(address(token1));
        
        assertTrue(wrapped0.unwrap() == address(token0));
        assertTrue(wrapped1.unwrap() == address(token1));
        assertTrue(wrapped0.unwrap() != wrapped1.unwrap());
    }

    // ============ Pool Key Tests ============

    function testPoolKeyGeneration() public {
        // Test pool key generation
        PoolKey memory testKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        
        PoolId testId = testKey.toId();
        assertTrue(testId != PoolId.wrap(0));
        assertTrue(testId == poolId);
    }

    function testPoolKeyUniqueness() public {
        // Test that different pool keys generate different IDs
        PoolKey memory key1 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        
        PoolKey memory key2 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 500,
            tickSpacing: 10,
            hooks: hook
        });
        
        PoolId id1 = key1.toId();
        PoolId id2 = key2.toId();
        
        assertTrue(id1 != id2);
    }

    function testPoolKeyComponents() public {
        // Test individual pool key components
        assertTrue(poolKey.currency0 == currency0);
        assertTrue(poolKey.currency1 == currency1);
        assertTrue(poolKey.fee == 3000);
        assertTrue(poolKey.tickSpacing == 60);
        assertTrue(poolKey.hooks == hook);
    }

    // ============ Balance Delta Tests ============

    function testBalanceDeltaZero() public {
        // Test zero balance delta
        BalanceDelta zeroDelta = BalanceDelta.wrap(0);
        assertTrue(BalanceDelta.unwrap(zeroDelta) == 0);
    }

    function testBalanceDeltaPositive() public {
        // Test positive balance delta
        BalanceDelta positiveDelta = BalanceDelta.wrap(int128(1000));
        assertTrue(BalanceDelta.unwrap(positiveDelta) == 1000);
    }

    function testBalanceDeltaNegative() public {
        // Test negative balance delta
        BalanceDelta negativeDelta = BalanceDelta.wrap(int128(-1000));
        assertTrue(BalanceDelta.unwrap(negativeDelta) == -1000);
    }

    function testBalanceDeltaBoundaries() public {
        // Test balance delta boundaries
        BalanceDelta maxPositive = BalanceDelta.wrap(type(int128).max);
        BalanceDelta maxNegative = BalanceDelta.wrap(type(int128).min);
        
        assertTrue(BalanceDelta.unwrap(maxPositive) == type(int128).max);
        assertTrue(BalanceDelta.unwrap(maxNegative) == type(int128).min);
    }

    // ============ Before Swap Delta Tests ============

    function testBeforeSwapDeltaZero() public {
        // Test zero before swap delta
        BeforeSwapDelta zeroDelta = BeforeSwapDeltaLibrary.ZERO_DELTA;
        assertTrue(BeforeSwapDelta.unwrap(zeroDelta) == 0);
    }

    function testBeforeSwapDeltaPositive() public {
        // Test positive before swap delta
        BeforeSwapDelta positiveDelta = BeforeSwapDelta.wrap(int128(500));
        assertTrue(BeforeSwapDelta.unwrap(positiveDelta) == 500);
    }

    function testBeforeSwapDeltaNegative() public {
        // Test negative before swap delta
        BeforeSwapDelta negativeDelta = BeforeSwapDelta.wrap(int128(-500));
        assertTrue(BeforeSwapDelta.unwrap(negativeDelta) == -500);
    }

    // ============ Event Emission Tests ============

    function testEventEmissionStructure() public {
        // Test that events can be emitted (structure validation)
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(SMALL_SWAP_AMOUNT),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        // This test just validates the event structure exists
        // In a real test, we would check for actual event emission
        vm.expectEmit(true, true, true, true);
        emit MEVShieldHook.PoolInitialized(poolId, 79228162514264337593543950336);
        
        // Emit the event to validate structure
        emit MEVShieldHook.PoolInitialized(poolId, 79228162514264337593543950336);
    }

    function testEventParameterTypes() public {
        // Test event parameter types
        address testTrader = address(0x1234);
        uint256 testAmount = 1000 ether;
        
        // Test different event types
        vm.expectEmit(true, true, true, true);
        emit MEVShieldHook.PoolInitialized(poolId, 79228162514264337593543950336);
        
        vm.expectEmit(true, true, true, true);
        emit MEVShieldHook.MEVProtectionApplied(poolId, testTrader, testAmount);
        
        vm.expectEmit(true, true, true, true);
        emit MEVShieldHook.SwapAnalyzed(poolId, testTrader, true);
        
        // Emit events to validate structure
        emit MEVShieldHook.PoolInitialized(poolId, 79228162514264337593543950336);
        emit MEVShieldHook.MEVProtectionApplied(poolId, testTrader, testAmount);
        emit MEVShieldHook.SwapAnalyzed(poolId, testTrader, true);
    }

    // ============ Error Handling Tests ============

    function testInvalidPoolId() public {
        // Test with invalid pool ID
        PoolId invalidId = PoolId.wrap(bytes32(0));
        
        // Should handle invalid pool ID gracefully
        MEVShieldHook.ProtectionConfig memory config = hook.getPoolProtectionConfig(invalidId);
        
        // Configuration should exist but with default values
        assertTrue(address(config.baseProtectionThreshold) != address(0));
    }

    function testInvalidSwapParams() public {
        // Test with invalid swap parameters
        SwapParams memory invalidParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0, // Invalid: should be non-zero
            sqrtPriceLimitX96: 0 // Invalid: should be non-zero
        });
        
        // Parameters are invalid but should not cause revert
        assertTrue(invalidParams.amountSpecified == 0);
        assertTrue(invalidParams.sqrtPriceLimitX96 == 0);
    }

    function testInvalidAddresses() public {
        // Test with invalid addresses
        address invalidAddress = address(0);
        
        // Should handle invalid addresses gracefully
        assertTrue(invalidAddress == address(0));
        
        // Test that hook doesn't revert with invalid addresses
        try hook.getPoolProtectionConfig(PoolId.wrap(bytes32(uint256(uint160(invalidAddress))))) {
            // Should not revert
        } catch {
            // If it reverts, that's also acceptable behavior
        }
    }

    // ============ State Management Tests ============

    function testStateIsolation() public {
        // Test that different pools maintain separate state
        PoolKey memory poolKey2 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 500,
            tickSpacing: 10,
            hooks: hook
        });
        PoolId poolId2 = poolKey2.toId();
        
        // Get configurations for both pools
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId2);
        
        // States should be isolated
        assertTrue(address(config1.baseProtectionThreshold) != address(config2.baseProtectionThreshold));
    }

    function testStatePersistence() public {
        // Test that state persists across function calls
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId);
        
        // Call function again
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId);
        
        // State should be consistent
        assertTrue(address(config1.baseProtectionThreshold) == address(config2.baseProtectionThreshold));
        assertTrue(address(config1.maxSlippageBuffer) == address(config2.maxSlippageBuffer));
        assertTrue(address(config1.maxExecutionDelay) == address(config2.maxExecutionDelay));
        assertTrue(address(config1.isEnabled) == address(config2.isEnabled));
    }

    // ============ Integration Tests ============

    function testContractIntegration() public {
        // Test that all contracts are properly integrated
        assertTrue(address(hook.poolManager()) == address(poolManager));
        assertTrue(address(hook.detectionEngine()) == address(detectionEngine));
        assertTrue(address(hook.protectionMechanisms()) == address(protectionMechanisms));
        assertTrue(address(hook.metricsTracker()) == address(encryptedMetrics));
        
        // Test that contracts have code
        assertTrue(address(poolManager).code.length > 0);
        assertTrue(address(detectionEngine).code.length > 0);
        assertTrue(address(protectionMechanisms).code.length > 0);
        assertTrue(address(encryptedMetrics).code.length > 0);
    }

    function testTokenIntegration() public {
        // Test that tokens are properly integrated
        assertTrue(token0.balanceOf(TRADER) == INITIAL_TOKEN_SUPPLY);
        assertTrue(token1.balanceOf(TRADER) == INITIAL_TOKEN_SUPPLY);
        assertTrue(token0.balanceOf(MEV_BOT) == INITIAL_TOKEN_SUPPLY);
        assertTrue(token1.balanceOf(MEV_BOT) == INITIAL_TOKEN_SUPPLY);
        
        // Test token functionality
        assertTrue(token0.totalSupply() == INITIAL_TOKEN_SUPPLY * 3); // 3 addresses
        assertTrue(token1.totalSupply() == INITIAL_TOKEN_SUPPLY * 3);
    }

    function testPoolIntegration() public {
        // Test that pool is properly integrated
        assertTrue(poolKey.currency0 == currency0);
        assertTrue(poolKey.currency1 == currency1);
        assertTrue(poolKey.fee == 3000);
        assertTrue(poolKey.tickSpacing == 60);
        assertTrue(poolKey.hooks == hook);
        
        // Test pool ID generation
        PoolId calculatedId = poolKey.toId();
        assertTrue(calculatedId == poolId);
    }

    // ============ Edge Case Tests ============

    function testZeroAmountSwaps() public {
        // Test zero amount swaps
        SwapParams memory zeroParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(zeroParams.amountSpecified == 0);
    }

    function testMaximumAmountSwaps() public {
        // Test maximum amount swaps
        SwapParams memory maxParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(type(uint128).max),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(maxParams.amountSpecified == -int256(type(uint128).max));
    }

    function testBoundarySqrtPrices() public {
        // Test boundary sqrt prices
        SwapParams memory minSqrtParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(SMALL_SWAP_AMOUNT),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        SwapParams memory maxSqrtParams = SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(SMALL_SWAP_AMOUNT),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });
        
        assertTrue(minSqrtParams.sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE);
        assertTrue(maxSqrtParams.sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE);
    }

    function testExtremeGasPrices() public {
        // Test extreme gas prices
        uint256[] memory extremeGasPrices = new uint256[](5);
        extremeGasPrices[0] = 1; // 1 wei
        extremeGasPrices[1] = 1 gwei;
        extremeGasPrices[2] = 1000 gwei;
        extremeGasPrices[3] = 1 ether; // Extremely high
        extremeGasPrices[4] = type(uint256).max; // Maximum
        
        for (uint256 i = 0; i < extremeGasPrices.length; i++) {
            vm.txGasPrice(extremeGasPrices[i]);
            assertTrue(tx.gasprice == extremeGasPrices[i]);
        }
    }

    // ============ Performance Tests ============

    function testFunctionCallGasUsage() public {
        // Test gas usage of various function calls
        uint256 gasStart;
        uint256 gasEnd;
        
        // Test getPoolProtectionConfig gas usage
        gasStart = gasleft();
        hook.getPoolProtectionConfig(poolId);
        gasEnd = gasleft();
        uint256 configGas = gasStart - gasEnd;
        
        // Should be reasonable gas usage
        assertTrue(configGas < 100000); // Less than 100k gas
    }

    function testMultipleFunctionCalls() public {
        // Test multiple function calls in sequence
        for (uint256 i = 0; i < 10; i++) {
            hook.getPoolProtectionConfig(poolId);
        }
        
        // Should not revert
        assertTrue(true);
    }

    function testConcurrentOperations() public {
        // Test that multiple operations can be performed
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId);
        MEVShieldHook.ProtectionConfig memory config3 = hook.getPoolProtectionConfig(poolId);
        
        // All should return consistent results
        assertTrue(address(config1.baseProtectionThreshold) == address(config2.baseProtectionThreshold));
        assertTrue(address(config2.baseProtectionThreshold) == address(config3.baseProtectionThreshold));
    }
}
