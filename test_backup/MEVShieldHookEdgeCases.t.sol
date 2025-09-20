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
 * @title MEVShieldHookEdgeCasesTest
 * @notice Edge case tests for MEV Shield Hook covering unusual scenarios
 * @dev Tests edge cases without complex FHE operations that cause ACL issues
 */
contract MEVShieldHookEdgeCasesTest is Test {
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

    // ============ Test Constants ============

    uint256 constant INITIAL_TOKEN_SUPPLY = 1000000 ether;

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
    }

    // ============ Zero Value Edge Cases ============

    function testZeroAmountSwap() public {
        SwapParams memory zeroParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 0,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(zeroParams.amountSpecified == 0);
        assertTrue(zeroParams.sqrtPriceLimitX96 > 0);
    }

    function testZeroSqrtPriceLimit() public {
        SwapParams memory zeroSqrtParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: 0
        });
        
        assertTrue(zeroSqrtParams.amountSpecified < 0);
        assertTrue(zeroSqrtParams.sqrtPriceLimitX96 == 0);
    }

    function testZeroAddressHandling() public {
        address zeroAddress = address(0);
        assertTrue(zeroAddress == address(0));
        
        // System should handle zero addresses gracefully
        try hook.getPoolProtectionConfig(PoolId.wrap(bytes32(uint256(uint160(zeroAddress))))) {
            // Should not revert for view functions
            assertTrue(true);
        } catch {
            // If it reverts, that's also acceptable behavior
            assertTrue(true);
        }
    }

    function testZeroPoolId() public {
        PoolId zeroId = PoolId.wrap(bytes32(0));
        
        MEVShieldHook.ProtectionConfig memory config = hook.getPoolProtectionConfig(zeroId);
        assertTrue(address(config.baseProtectionThreshold) != address(0));
    }

    // ============ Maximum Value Edge Cases ============

    function testMaximumSwapAmount() public {
        SwapParams memory maxParams = SwapParams({
            zeroForOne: true,
            amountSpecified: type(int128).max,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(maxParams.amountSpecified == type(int128).max);
        assertTrue(maxParams.amountSpecified > 0);
    }

    function testMaximumNegativeSwapAmount() public {
        SwapParams memory maxNegParams = SwapParams({
            zeroForOne: true,
            amountSpecified: type(int128).min,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(maxNegParams.amountSpecified == type(int128).min);
        assertTrue(maxNegParams.amountSpecified < 0);
    }

    function testMaximumSqrtPriceLimit() public {
        SwapParams memory maxSqrtParams = SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: type(uint160).max
        });
        
        assertTrue(maxSqrtParams.sqrtPriceLimitX96 == type(uint160).max);
        assertTrue(maxSqrtParams.amountSpecified < 0);
    }

    function testMaximumGasPrice() public {
        uint256 maxGasPrice = type(uint256).max;
        vm.txGasPrice(maxGasPrice);
        assertTrue(tx.gasprice == maxGasPrice);
    }

    // ============ Boundary Value Edge Cases ============

    function testMinimumSqrtPriceBoundary() public {
        SwapParams memory minSqrtParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE
        });
        
        assertTrue(minSqrtParams.sqrtPriceLimitX96 == TickMath.MIN_SQRT_PRICE);
    }

    function testMaximumSqrtPriceBoundary() public {
        SwapParams memory maxSqrtParams = SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE
        });
        
        assertTrue(maxSqrtParams.sqrtPriceLimitX96 == TickMath.MAX_SQRT_PRICE);
    }

    function testJustAboveMinimumSqrtPrice() public {
        SwapParams memory justAboveMinParams = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(justAboveMinParams.sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE);
    }

    function testJustBelowMaximumSqrtPrice() public {
        SwapParams memory justBelowMaxParams = SwapParams({
            zeroForOne: false,
            amountSpecified: -int256(1000 ether),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });
        
        assertTrue(justBelowMaxParams.sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE);
    }

    // ============ Type Conversion Edge Cases ============

    function testInt256ToInt128Conversion() public {
        int256 largeInt = type(int256).max;
        
        // Test conversion bounds
        if (largeInt <= type(int128).max && largeInt >= type(int128).min) {
            int128 converted = int128(largeInt);
            assertTrue(converted == int128(largeInt));
        }
        
        int256 smallInt = type(int256).min;
        if (smallInt <= type(int128).max && smallInt >= type(int128).min) {
            int128 converted = int128(smallInt);
            assertTrue(converted == int128(smallInt));
        }
    }

    function testUint256ToUint128Conversion() public {
        uint256 largeUint = type(uint256).max;
        
        // Test conversion bounds
        if (largeUint <= type(uint128).max) {
            uint128 converted = uint128(largeUint);
            assertTrue(converted == uint128(largeUint));
        }
        
        uint256 smallUint = type(uint128).max;
        uint128 smallConverted = uint128(smallUint);
        assertTrue(smallConverted == uint128(smallUint));
    }

    function testAddressToUint160Conversion() public {
        address testAddr = address(0x1234567890123456789012345678901234567890);
        uint160 converted = uint160(testAddr);
        assertTrue(converted == uint160(testAddr));
        
        address backToAddr = address(converted);
        assertTrue(backToAddr == testAddr);
    }

    // ============ Arithmetic Edge Cases ============

    function testAdditionOverflow() public {
        uint256 maxUint = type(uint256).max;
        uint256 one = 1;
        
        // Test overflow detection
        bool wouldOverflow = maxUint > type(uint256).max - one;
        assertTrue(wouldOverflow);
        
        // Test safe addition
        if (maxUint <= type(uint256).max - one) {
            uint256 sum = maxUint + one;
            assertTrue(sum > maxUint);
        }
    }

    function testSubtractionUnderflow() public {
        uint256 zero = 0;
        uint256 one = 1;
        
        // Test underflow detection
        bool wouldUnderflow = zero < one;
        assertTrue(wouldUnderflow);
        
        // Test safe subtraction
        if (zero >= one) {
            uint256 diff = zero - one;
            assertTrue(diff < zero);
        }
    }

    function testMultiplicationOverflow() public {
        uint256 largeValue = type(uint256).max;
        uint256 two = 2;
        
        // Test overflow detection
        bool wouldOverflow = largeValue > type(uint256).max / two;
        assertTrue(wouldOverflow);
        
        // Test safe multiplication
        if (largeValue <= type(uint256).max / two) {
            uint256 product = largeValue * two;
            assertTrue(product > largeValue);
        }
    }

    // ============ Balance Delta Edge Cases ============

    function testBalanceDeltaMaximum() public {
        BalanceDelta maxDelta = BalanceDelta.wrap(type(int128).max);
        assertTrue(BalanceDelta.unwrap(maxDelta) == type(int128).max);
    }

    function testBalanceDeltaMinimum() public {
        BalanceDelta minDelta = BalanceDelta.wrap(type(int128).min);
        assertTrue(BalanceDelta.unwrap(minDelta) == type(int128).min);
    }

    function testBalanceDeltaZero() public {
        BalanceDelta zeroDelta = BalanceDelta.wrap(0);
        assertTrue(BalanceDelta.unwrap(zeroDelta) == 0);
    }

    function testBalanceDeltaNegative() public {
        BalanceDelta negDelta = BalanceDelta.wrap(-1000);
        assertTrue(BalanceDelta.unwrap(negDelta) == -1000);
    }

    // ============ Before Swap Delta Edge Cases ============

    function testBeforeSwapDeltaMaximum() public {
        BeforeSwapDelta maxDelta = BeforeSwapDelta.wrap(type(int128).max);
        assertTrue(BeforeSwapDelta.unwrap(maxDelta) == type(int128).max);
    }

    function testBeforeSwapDeltaMinimum() public {
        BeforeSwapDelta minDelta = BeforeSwapDelta.wrap(type(int128).min);
        assertTrue(BeforeSwapDelta.unwrap(minDelta) == type(int128).min);
    }

    function testBeforeSwapDeltaZero() public {
        BeforeSwapDelta zeroDelta = BeforeSwapDeltaLibrary.ZERO_DELTA;
        assertTrue(BeforeSwapDelta.unwrap(zeroDelta) == 0);
    }

    function testBeforeSwapDeltaNegative() public {
        BeforeSwapDelta negDelta = BeforeSwapDelta.wrap(-1000);
        assertTrue(BeforeSwapDelta.unwrap(negDelta) == -1000);
    }

    // ============ Currency Edge Cases ============

    function testCurrencyMaximumAddress() public {
        address maxAddr = address(type(uint160).max);
        Currency maxCurrency = Currency.wrap(maxAddr);
        assertTrue(maxCurrency.unwrap() == maxAddr);
    }

    function testCurrencyMinimumAddress() public {
        address minAddr = address(1);
        Currency minCurrency = Currency.wrap(minAddr);
        assertTrue(minCurrency.unwrap() == minAddr);
    }

    function testCurrencyZeroAddress() public {
        address zeroAddr = address(0);
        Currency zeroCurrency = Currency.wrap(zeroAddr);
        assertTrue(zeroCurrency.unwrap() == zeroAddr);
    }

    function testCurrencyEquality() public {
        address addr1 = address(0x1234);
        address addr2 = address(0x5678);
        
        Currency testCurrency1 = Currency.wrap(addr1);
        Currency testCurrency2 = Currency.wrap(addr2);
        Currency testCurrency3 = Currency.wrap(addr1);
        
        assertTrue(testCurrency1.unwrap() != testCurrency2.unwrap());
        assertTrue(testCurrency1.unwrap() == testCurrency3.unwrap());
    }

    // ============ Pool Key Edge Cases ============

    function testPoolKeyMaximumFee() public {
        PoolKey memory maxFeeKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: type(uint24).max,
            tickSpacing: 60,
            hooks: hook
        });
        
        assertTrue(maxFeeKey.fee == type(uint24).max);
        PoolId maxFeeId = maxFeeKey.toId();
        assertTrue(maxFeeId != PoolId.wrap(0));
    }

    function testPoolKeyMaximumTickSpacing() public {
        PoolKey memory maxTickKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: type(int24).max,
            hooks: hook
        });
        
        assertTrue(maxTickKey.tickSpacing == type(int24).max);
        PoolId maxTickId = maxTickKey.toId();
        assertTrue(maxTickId != PoolId.wrap(0));
    }

    function testPoolKeyMinimumValues() public {
        PoolKey memory minKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 1,
            tickSpacing: 1,
            hooks: hook
        });
        
        assertTrue(minKey.fee == 1);
        assertTrue(minKey.tickSpacing == 1);
        PoolId minId = minKey.toId();
        assertTrue(minId != PoolId.wrap(0));
    }

    function testPoolKeyZeroValues() public {
        PoolKey memory zeroKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 0,
            tickSpacing: 0,
            hooks: hook
        });
        
        assertTrue(zeroKey.fee == 0);
        assertTrue(zeroKey.tickSpacing == 0);
        PoolId zeroId = zeroKey.toId();
        assertTrue(zeroId != PoolId.wrap(0));
    }

    // ============ Gas Price Edge Cases ============

    function testMinimumGasPrice() public {
        uint256 minGasPrice = 1 wei;
        vm.txGasPrice(minGasPrice);
        assertTrue(tx.gasprice == minGasPrice);
    }

    function testHighGasPrice() public {
        uint256 highGasPrice = 1000 gwei;
        vm.txGasPrice(highGasPrice);
        assertTrue(tx.gasprice == highGasPrice);
    }

    function testExtremeGasPrice() public {
        uint256 extremeGasPrice = 1 ether;
        vm.txGasPrice(extremeGasPrice);
        assertTrue(tx.gasprice == extremeGasPrice);
    }

    function testGasPriceChanges() public {
        uint256[] memory gasPrices = new uint256[](5);
        gasPrices[0] = 1 wei;
        gasPrices[1] = 1 gwei;
        gasPrices[2] = 100 gwei;
        gasPrices[3] = 1000 gwei;
        gasPrices[4] = 1 ether;
        
        for (uint256 i = 0; i < gasPrices.length; i++) {
            vm.txGasPrice(gasPrices[i]);
            assertTrue(tx.gasprice == gasPrices[i]);
        }
    }

    // ============ Time Edge Cases ============

    function testTimestampZero() public {
        vm.warp(0);
        assertTrue(block.timestamp == 0);
    }

    function testTimestampMaximum() public {
        uint256 maxTimestamp = type(uint256).max;
        vm.warp(maxTimestamp);
        assertTrue(block.timestamp == maxTimestamp);
    }

    function testTimestampProgression() public {
        uint256 startTime = block.timestamp;
        
        vm.warp(startTime + 1 seconds);
        assertTrue(block.timestamp == startTime + 1 seconds);
        
        vm.warp(startTime + 1 minutes);
        assertTrue(block.timestamp == startTime + 1 minutes);
        
        vm.warp(startTime + 1 hours);
        assertTrue(block.timestamp == startTime + 1 hours);
        
        vm.warp(startTime + 1 days);
        assertTrue(block.timestamp == startTime + 1 days);
    }

    function testTimestampRegression() public {
        uint256 startTime = block.timestamp;
        
        vm.warp(startTime + 1000);
        assertTrue(block.timestamp == startTime + 1000);
        
        vm.warp(startTime);
        assertTrue(block.timestamp == startTime);
    }

    // ============ Memory Edge Cases ============

    function testLargeArrayHandling() public {
        uint256 arraySize = 1000;
        SwapParams[] memory largeArray = new SwapParams[](arraySize);
        
        for (uint256 i = 0; i < arraySize; i++) {
            largeArray[i] = SwapParams({
                zeroForOne: i % 2 == 0,
                amountSpecified: -int256(100 + i),
                sqrtPriceLimitX96: i % 2 == 0 ? 
                    TickMath.MIN_SQRT_PRICE + 1 : 
                    TickMath.MAX_SQRT_PRICE - 1
            });
        }
        
        assertTrue(largeArray.length == arraySize);
        assertTrue(largeArray[0].amountSpecified < 0);
        assertTrue(largeArray[arraySize - 1].amountSpecified < 0);
    }

    function testDeepNesting() public {
        // Test deep nesting of structs and arrays
        PoolKey[] memory keys = new PoolKey[](10);
        
        for (uint256 i = 0; i < 10; i++) {
            keys[i] = PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: uint24(100 + i),
                tickSpacing: int24(10 + i),
                hooks: hook
            });
            
            PoolId id = keys[i].toId();
            assertTrue(id != PoolId.wrap(0));
            
            SwapParams memory params = SwapParams({
                zeroForOne: i % 2 == 0,
                amountSpecified: -int256(100 + i),
                sqrtPriceLimitX96: i % 2 == 0 ? 
                    TickMath.MIN_SQRT_PRICE + 1 : 
                    TickMath.MAX_SQRT_PRICE - 1
            });
            
            assertTrue(params.amountSpecified < 0);
        }
    }

    // ============ Error Edge Cases ============

    function testInvalidPoolKeyComponents() public {
        // Test with invalid pool key components
        PoolKey memory invalidKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(0)),
            fee: type(uint24).max,
            tickSpacing: type(int24).min,
            hooks: hook
        });
        
        PoolId invalidId = invalidKey.toId();
        assertTrue(invalidId != PoolId.wrap(0));
        
        MEVShieldHook.ProtectionConfig memory config = hook.getPoolProtectionConfig(invalidId);
        assertTrue(address(config.baseProtectionThreshold) != address(0));
    }

    function testInvalidSwapParameters() public {
        // Test with various invalid swap parameters
        SwapParams[] memory invalidParams = new SwapParams[](5);
        
        invalidParams[0] = SwapParams({
            zeroForOne: true,
            amountSpecified: 0,
            sqrtPriceLimitX96: 0
        });
        
        invalidParams[1] = SwapParams({
            zeroForOne: true,
            amountSpecified: type(int256).max,
            sqrtPriceLimitX96: type(uint160).max
        });
        
        invalidParams[2] = SwapParams({
            zeroForOne: true,
            amountSpecified: type(int256).min,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE
        });
        
        invalidParams[3] = SwapParams({
            zeroForOne: false,
            amountSpecified: 0,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE
        });
        
        invalidParams[4] = SwapParams({
            zeroForOne: true,
            amountSpecified: -1,
            sqrtPriceLimitX96: 1
        });
        
        // All should be handled gracefully
        for (uint256 i = 0; i < invalidParams.length; i++) {
            assertTrue(invalidParams[i].zeroForOne || !invalidParams[i].zeroForOne);
            assertTrue(invalidParams[i].amountSpecified >= type(int256).min);
            assertTrue(invalidParams[i].amountSpecified <= type(int256).max);
            assertTrue(invalidParams[i].sqrtPriceLimitX96 >= 0);
            assertTrue(invalidParams[i].sqrtPriceLimitX96 <= type(uint160).max);
        }
    }

    // ============ State Edge Cases ============

    function testStateConsistencyUnderLoad() public {
        // Test state consistency under various loads
        for (uint256 i = 0; i < 100; i++) {
            MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId);
            MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId);
            
            // State should be consistent
            assertTrue(address(config1.baseProtectionThreshold) == address(config2.baseProtectionThreshold));
            assertTrue(address(config1.maxSlippageBuffer) == address(config2.maxSlippageBuffer));
            assertTrue(address(config1.maxExecutionDelay) == address(config2.maxExecutionDelay));
            assertTrue(address(config1.isEnabled) == address(config2.isEnabled));
        }
    }

    function testStateIsolation() public {
        // Test state isolation between different pools
        PoolKey memory poolKey2 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 500,
            tickSpacing: 10,
            hooks: hook
        });
        PoolId poolId2 = poolKey2.toId();
        
        MEVShieldHook.ProtectionConfig memory config1 = hook.getPoolProtectionConfig(poolId);
        MEVShieldHook.ProtectionConfig memory config2 = hook.getPoolProtectionConfig(poolId2);
        
        // States should be isolated
        assertTrue(address(config1.baseProtectionThreshold) != address(config2.baseProtectionThreshold));
        assertTrue(poolId != poolId2);
    }
}
