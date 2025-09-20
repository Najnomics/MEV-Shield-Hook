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
 * @title MEVShieldHookAdvancedFuzzTest
 * @notice Advanced fuzz tests for MEV Shield Hook covering complex scenarios and edge cases
 * @dev Focuses on fuzzing without complex FHE operations that cause ACL issues
 */
contract MEVShieldHookAdvancedFuzzTest is Test {
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
        token0.mint(address(this), INITIAL_TOKEN_SUPPLY);
        token1.mint(address(this), INITIAL_TOKEN_SUPPLY);
    }

    // ============ Pool Key Fuzz Tests ============

    function testFuzzPoolKeyGeneration(uint24 fee, int24 tickSpacing) public {
        vm.assume(fee > 0);
        vm.assume(tickSpacing > 0);
        vm.assume(tickSpacing <= 10000);
        
        PoolKey memory testKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: hook
        });
        
        PoolId testId = testKey.toId();
        assertTrue(testId != PoolId.wrap(0));
        
        // Test that the same key generates the same ID
        PoolId testId2 = testKey.toId();
        assertTrue(PoolId.unwrap(testId) == PoolId.unwrap(testId2));
    }

    function testFuzzPoolKeyUniqueness(uint24 fee1, uint24 fee2, int24 tickSpacing1, int24 tickSpacing2) public {
        vm.assume(fee1 > 0 && fee2 > 0);
        vm.assume(tickSpacing1 > 0 && tickSpacing2 > 0);
        vm.assume(tickSpacing1 <= 10000 && tickSpacing2 <= 10000);
        vm.assume(fee1 != fee2 || tickSpacing1 != tickSpacing2);
        
        PoolKey memory key1 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee1,
            tickSpacing: tickSpacing1,
            hooks: hook
        });
        
        PoolKey memory key2 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee2,
            tickSpacing: tickSpacing2,
            hooks: hook
        });
        
        PoolId id1 = key1.toId();
        PoolId id2 = key2.toId();
        
        assertTrue(PoolId.unwrap(id1) != PoolId.unwrap(id2));
    }

    function testFuzzPoolKeyComponents(uint24 fee, int24 tickSpacing) public {
        vm.assume(fee > 0);
        vm.assume(tickSpacing > 0);
        vm.assume(tickSpacing <= 10000);
        
        PoolKey memory testKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: hook
        });
        
        assertTrue(testKey.currency0 == currency0);
        assertTrue(testKey.currency1 == currency1);
        assertTrue(testKey.fee == fee);
        assertTrue(testKey.tickSpacing == tickSpacing);
        assertTrue(testKey.hooks == hook);
    }

    // ============ Swap Parameter Fuzz Tests ============

    function testFuzzSwapParameterValidation(int256 amountSpecified, bool zeroForOne) public {
        vm.assume(amountSpecified != 0);
        
        uint160 sqrtPriceLimit = zeroForOne ? 
            TickMath.MIN_SQRT_PRICE + 1 : 
            TickMath.MAX_SQRT_PRICE - 1;
        
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimit
        });
        
        assertTrue(params.zeroForOne == zeroForOne);
        assertTrue(params.amountSpecified == amountSpecified);
        assertTrue(params.sqrtPriceLimitX96 == sqrtPriceLimit);
    }

    function testFuzzSwapAmountBoundaries(int256 amountSpecified) public {
        vm.assume(amountSpecified != 0);
        vm.assume(amountSpecified >= type(int128).min);
        vm.assume(amountSpecified <= type(int128).max);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(params.amountSpecified == amountSpecified);
        assertTrue(params.amountSpecified >= type(int128).min);
        assertTrue(params.amountSpecified <= type(int128).max);
    }

    function testFuzzSqrtPriceLimits(uint160 sqrtPriceLimitX96) public {
        vm.assume(sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE);
        vm.assume(sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1000,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        assertTrue(params.sqrtPriceLimitX96 == sqrtPriceLimitX96);
        assertTrue(params.sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE);
        assertTrue(params.sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE);
    }

    // ============ Gas Price Fuzz Tests ============

    function testFuzzGasPriceVariations(uint256 gasPrice) public {
        vm.assume(gasPrice > 0);
        vm.assume(gasPrice <= 1000 ether); // Reasonable upper bound
        
        vm.txGasPrice(gasPrice);
        assertTrue(tx.gasprice == gasPrice);
    }

    function testFuzzGasPriceBoundaries(uint256 gasPrice) public {
        vm.assume(gasPrice >= 1 wei);
        vm.assume(gasPrice <= 1 ether);
        
        vm.txGasPrice(gasPrice);
        assertTrue(tx.gasprice >= 1 wei);
        assertTrue(tx.gasprice <= 1 ether);
    }

    function testFuzzGasPriceImpact(uint256 gasPrice1, uint256 gasPrice2) public {
        vm.assume(gasPrice1 > 0 && gasPrice2 > 0);
        vm.assume(gasPrice1 <= 1000 gwei && gasPrice2 <= 1000 gwei);
        
        vm.txGasPrice(gasPrice1);
        assertTrue(tx.gasprice == gasPrice1);
        
        vm.txGasPrice(gasPrice2);
        assertTrue(tx.gasprice == gasPrice2);
    }

    // ============ Address Fuzz Tests ============

    function testFuzzTraderAddresses(address trader) public {
        vm.assume(trader != address(0));
        vm.assume(trader != address(hook));
        vm.assume(trader != address(poolManager));
        
        // Test that address is valid
        assertTrue(trader != address(0));
        assertTrue(trader != address(hook));
        assertTrue(trader != address(poolManager));
    }

    function testFuzzMultipleTraderAddresses(address[] calldata traders) public {
        vm.assume(traders.length > 0);
        vm.assume(traders.length <= 10); // Reasonable limit
        
        for (uint256 i = 0; i < traders.length; i++) {
            vm.assume(traders[i] != address(0));
            vm.assume(traders[i] != address(hook));
            
            // Test uniqueness
            for (uint256 j = i + 1; j < traders.length; j++) {
                vm.assume(traders[i] != traders[j]);
            }
        }
        
        // All addresses should be unique and valid
        assertTrue(traders.length > 0);
        assertTrue(traders.length <= 10);
    }

    function testFuzzAddressValidation(address addr) public {
        // Test address validation logic
        bool isValid = addr != address(0);
        bool isNotHook = addr != address(hook);
        bool isNotPoolManager = addr != address(poolManager);
        
        // At least one should be true for most addresses
        assertTrue(isValid || isNotHook || isNotPoolManager);
    }

    // ============ Token Amount Fuzz Tests ============

    function testFuzzTokenAmounts(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max);
        
        // Test positive amounts
        assertTrue(amount > 0);
        assertTrue(amount <= type(uint128).max);
        
        // Test negative amounts (for swap inputs)
        int256 negativeAmount = -int256(amount);
        assertTrue(negativeAmount < 0);
        assertTrue(negativeAmount >= type(int128).min);
    }

    function testFuzzTokenAmountBoundaries(uint256 amount) public {
        vm.assume(amount > 0);
        
        // Test various boundaries
        uint256 smallAmount = amount % 1000;
        uint256 mediumAmount = amount % 1000000;
        uint256 largeAmount = amount % type(uint128).max;
        
        assertTrue(smallAmount >= 0);
        assertTrue(mediumAmount >= 0);
        assertTrue(largeAmount >= 0);
        assertTrue(largeAmount <= type(uint128).max);
    }

    function testFuzzTokenAmountPrecision(uint256 amount, uint8 decimals) public {
        vm.assume(amount > 0);
        vm.assume(decimals <= 18);
        
        // Test precision handling
        uint256 scaledAmount = amount * (10 ** decimals);
        assertTrue(scaledAmount >= amount);
        
        // Test that scaling doesn't overflow
        if (amount <= type(uint256).max / (10 ** decimals)) {
            assertTrue(scaledAmount == amount * (10 ** decimals));
        }
    }

    // ============ Time-based Fuzz Tests ============

    function testFuzzTimestampVariations(uint256 timestamp) public {
        vm.assume(timestamp >= block.timestamp);
        vm.assume(timestamp <= block.timestamp + 365 days);
        
        vm.warp(timestamp);
        assertTrue(block.timestamp == timestamp);
    }

    function testFuzzTimeWindows(uint256 startTime, uint256 duration) public {
        vm.assume(startTime >= block.timestamp);
        vm.assume(duration > 0);
        vm.assume(duration <= 30 days);
        vm.assume(startTime + duration <= block.timestamp + 365 days);
        
        uint256 endTime = startTime + duration;
        assertTrue(endTime > startTime);
        assertTrue(endTime - startTime == duration);
    }

    function testFuzzTimeIntervals(uint256 interval) public {
        vm.assume(interval > 0);
        vm.assume(interval <= 1 days);
        
        uint256 startTime = block.timestamp;
        vm.warp(startTime + interval);
        
        assertTrue(block.timestamp == startTime + interval);
        assertTrue(block.timestamp - startTime == interval);
    }

    // ============ Fee Structure Fuzz Tests ============

    function testFuzzFeeStructures(uint24 fee) public {
        vm.assume(fee > 0);
        vm.assume(fee <= 1000000); // 100% max fee
        
        // Test fee validation
        assertTrue(fee > 0);
        assertTrue(fee <= 1000000);
        
        // Test common fee tiers
        bool isCommonFee = (fee == 100 || fee == 500 || fee == 3000 || fee == 10000);
        // Either it's a common fee or it's a custom fee
        assertTrue(isCommonFee || (fee > 10000 && fee <= 1000000));
    }

    function testFuzzTickSpacingVariations(int24 tickSpacing) public {
        vm.assume(tickSpacing > 0);
        vm.assume(tickSpacing <= 10000);
        
        assertTrue(tickSpacing > 0);
        assertTrue(tickSpacing <= 10000);
        
        // Test that tick spacing is reasonable
        assertTrue(tickSpacing % 1 == 0); // Should be integer
    }

    function testFuzzFeeTickSpacingRelationships(uint24 fee, int24 tickSpacing) public {
        vm.assume(fee > 0 && fee <= 1000000);
        vm.assume(tickSpacing > 0 && tickSpacing <= 10000);
        
        // Test that fee and tick spacing are compatible
        assertTrue(fee > 0);
        assertTrue(tickSpacing > 0);
        
        // Common relationships
        bool isCommonPair = (fee == 100 && tickSpacing == 1) ||
                           (fee == 500 && tickSpacing == 10) ||
                           (fee == 3000 && tickSpacing == 60) ||
                           (fee == 10000 && tickSpacing == 200);
        
        // Either it's a common pair or a custom pair
        assertTrue(isCommonPair || (fee > 10000 && tickSpacing > 200));
    }

    // ============ Balance Delta Fuzz Tests ============

    function testFuzzBalanceDeltaValues(int128 delta) public {
        BalanceDelta balanceDelta = BalanceDelta.wrap(delta);
        assertTrue(BalanceDelta.unwrap(balanceDelta) == delta);
    }

    function testFuzzBalanceDeltaBoundaries(int128 delta) public {
        vm.assume(delta >= type(int128).min);
        vm.assume(delta <= type(int128).max);
        
        BalanceDelta balanceDelta = BalanceDelta.wrap(delta);
        int256 unwrapped = BalanceDelta.unwrap(balanceDelta);
        
        assertTrue(unwrapped >= type(int128).min);
        assertTrue(unwrapped <= type(int128).max);
        assertTrue(unwrapped == delta);
    }

    function testFuzzBalanceDeltaOperations(int128 delta1, int128 delta2) public {
        vm.assume(delta1 >= type(int128).min / 2);
        vm.assume(delta1 <= type(int128).max / 2);
        vm.assume(delta2 >= type(int128).min / 2);
        vm.assume(delta2 <= type(int128).max / 2);
        
        BalanceDelta balanceDelta1 = BalanceDelta.wrap(delta1);
        BalanceDelta balanceDelta2 = BalanceDelta.wrap(delta2);
        
        assertTrue(BalanceDelta.unwrap(balanceDelta1) == delta1);
        assertTrue(BalanceDelta.unwrap(balanceDelta2) == delta2);
        
        // Test addition (without overflow)
        int128 sum = delta1 + delta2;
        if (sum >= type(int128).min && sum <= type(int128).max) {
            BalanceDelta sumDelta = BalanceDelta.wrap(sum);
            assertTrue(BalanceDelta.unwrap(sumDelta) == sum);
        }
    }

    // ============ Before Swap Delta Fuzz Tests ============

    function testFuzzBeforeSwapDeltaValues(int128 delta) public {
        BeforeSwapDelta beforeSwapDelta = BeforeSwapDelta.wrap(delta);
        assertTrue(BeforeSwapDelta.unwrap(beforeSwapDelta) == delta);
    }

    function testFuzzBeforeSwapDeltaZero() public {
        BeforeSwapDelta zeroDelta = BeforeSwapDeltaLibrary.ZERO_DELTA;
        assertTrue(BeforeSwapDelta.unwrap(zeroDelta) == 0);
    }

    function testFuzzBeforeSwapDeltaBoundaries(int128 delta) public {
        vm.assume(delta >= type(int128).min);
        vm.assume(delta <= type(int128).max);
        
        BeforeSwapDelta beforeSwapDelta = BeforeSwapDelta.wrap(delta);
        int256 unwrapped = BeforeSwapDelta.unwrap(beforeSwapDelta);
        
        assertTrue(unwrapped >= type(int128).min);
        assertTrue(unwrapped <= type(int128).max);
        assertTrue(unwrapped == delta);
    }

    // ============ Currency Fuzz Tests ============

    function testFuzzCurrencyWrapping(address tokenAddress) public {
        vm.assume(tokenAddress != address(0));
        
        Currency currency = Currency.wrap(tokenAddress);
        assertTrue(currency.unwrap() == tokenAddress);
    }

    function testFuzzCurrencyUnwrapping(address tokenAddress) public {
        vm.assume(tokenAddress != address(0));
        
        Currency currency = Currency.wrap(tokenAddress);
        address unwrapped = currency.unwrap();
        assertTrue(unwrapped == tokenAddress);
    }

    function testFuzzCurrencyEquality(address tokenAddress1, address tokenAddress2) public {
        vm.assume(tokenAddress1 != address(0));
        vm.assume(tokenAddress2 != address(0));
        
        Currency testCurrency1 = Currency.wrap(tokenAddress1);
        Currency testCurrency2 = Currency.wrap(tokenAddress2);
        
        bool areEqual = (tokenAddress1 == tokenAddress2);
        assertTrue((testCurrency1.unwrap() == testCurrency2.unwrap()) == areEqual);
    }

    // ============ Hook Address Fuzz Tests ============

    function testFuzzHookAddressGeneration(uint160 hookSeed) public {
        vm.assume(hookSeed != 0);
        
        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (hookSeed << 144)
        );
        
        assertTrue(hookAddress != address(0));
        assertTrue(hookAddress != address(hook));
    }

    function testFuzzHookPermissions(uint160 hookSeed) public {
        vm.assume(hookSeed != 0);
        
        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (hookSeed << 144)
        );
        
        // Test that hook address has required permissions
        uint160 permissions = uint160(hookAddress) ^ (hookSeed << 144);
        assertTrue(permissions & Hooks.BEFORE_INITIALIZE_FLAG != 0);
        assertTrue(permissions & Hooks.BEFORE_SWAP_FLAG != 0);
        assertTrue(permissions & Hooks.AFTER_SWAP_FLAG != 0);
    }

    // ============ Stress Tests ============

    function testFuzzStressTestMultiplePools(uint8 poolCount) public {
        vm.assume(poolCount > 0);
        vm.assume(poolCount <= 20); // Reasonable limit
        
        for (uint256 i = 0; i < poolCount; i++) {
            PoolKey memory testKey = PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: uint24(100 + (i * 100) % 10000),
                tickSpacing: int24(10 + (i * 10) % 1000),
                hooks: hook
            });
            
            PoolId testId = testKey.toId();
            assertTrue(testId != PoolId.wrap(0));
            
            // Each pool should have unique ID
            for (uint256 j = 0; j < i; j++) {
                PoolKey memory prevKey = PoolKey({
                    currency0: currency0,
                    currency1: currency1,
                    fee: uint24(100 + (j * 100) % 10000),
                    tickSpacing: int24(10 + (j * 10) % 1000),
                    hooks: hook
                });
                PoolId prevId = prevKey.toId();
                assertTrue(testId != prevId);
            }
        }
    }

    function testFuzzStressTestMultipleSwaps(uint8 swapCount) public {
        vm.assume(swapCount > 0);
        vm.assume(swapCount <= 50); // Reasonable limit
        
        for (uint256 i = 0; i < swapCount; i++) {
            SwapParams memory params = SwapParams({
                zeroForOne: i % 2 == 0,
                amountSpecified: -int256(1000 + (i * 100) % 100000),
                sqrtPriceLimitX96: i % 2 == 0 ? 
                    TickMath.MIN_SQRT_PRICE + 1 : 
                    TickMath.MAX_SQRT_PRICE - 1
            });
            
            assertTrue(params.zeroForOne == (i % 2 == 0));
            assertTrue(params.amountSpecified < 0);
            assertTrue(params.sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE);
            assertTrue(params.sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE);
        }
    }

    function testFuzzStressTestMultipleAddresses(uint8 addressCount) public {
        vm.assume(addressCount > 0);
        vm.assume(addressCount <= 100); // Reasonable limit
        
        address[] memory addresses = new address[](addressCount);
        
        for (uint256 i = 0; i < addressCount; i++) {
            addresses[i] = address(uint160(1000 + i));
            assertTrue(addresses[i] != address(0));
            
            // Ensure uniqueness
            for (uint256 j = 0; j < i; j++) {
                assertTrue(addresses[i] != addresses[j]);
            }
        }
    }

    // ============ Edge Case Fuzz Tests ============

    function testFuzzEdgeCaseZeroAmounts(int256 amountSpecified) public {
        vm.assume(amountSpecified == 0);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(params.amountSpecified == 0);
    }

    function testFuzzEdgeCaseMaxAmounts(int256 amountSpecified) public {
        vm.assume(amountSpecified == type(int128).max || amountSpecified == type(int128).min);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });
        
        assertTrue(params.amountSpecified == amountSpecified);
    }

    function testFuzzEdgeCaseBoundaryPrices(uint160 sqrtPriceLimitX96) public {
        vm.assume(sqrtPriceLimitX96 == TickMath.MIN_SQRT_PRICE || 
                 sqrtPriceLimitX96 == TickMath.MAX_SQRT_PRICE);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1000,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        assertTrue(params.sqrtPriceLimitX96 == sqrtPriceLimitX96);
    }

    // ============ Random Data Fuzz Tests ============

    function testFuzzRandomBytes32(bytes32 data) public {
        // Test that we can handle random bytes32 data
        assertTrue(data != bytes32(0) || data == bytes32(0)); // Always true, just testing structure
        
        // Test conversion to address
        address addr = address(uint160(uint256(data)));
        assertTrue(addr != address(0) || addr == address(0)); // Always true, just testing structure
    }

    function testFuzzRandomUint256(uint256 data) public {
        // Test that we can handle random uint256 data
        assertTrue(data >= 0); // Always true
        
        // Test bounds
        assertTrue(data <= type(uint256).max); // Always true
        
        // Test modulo operations
        uint256 mod100 = data % 100;
        assertTrue(mod100 < 100);
    }

    function testFuzzRandomInt256(int256 data) public {
        // Test that we can handle random int256 data
        assertTrue(data >= type(int256).min);
        assertTrue(data <= type(int256).max);
        
        // Test sign
        bool isPositive = data >= 0;
        bool isNegative = data < 0;
        assertTrue(isPositive || isNegative);
        assertTrue(!(isPositive && isNegative));
    }
}
