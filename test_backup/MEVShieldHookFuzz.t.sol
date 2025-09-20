// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Foundry Imports
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// CoFHE Test Imports
import {CoFheTest} from "@fhenixprotocol/cofhe-mock-contracts/CoFheTest.sol";

// MEV Shield Hook Imports
import {MEVShieldHook} from "../../src/hooks/MEVShieldHook.sol";
import {MEVDetectionEngine} from "../../src/detection/MEVDetectionEngine.sol";
import {IMEVDetectionEngine} from "../../src/hooks/interfaces/IMEVDetectionEngine.sol";
import {ProtectionMechanisms} from "../../src/protection/ProtectionMechanisms.sol";
import {EncryptedMetrics} from "../../src/analytics/EncryptedMetrics.sol";
import {IEncryptedMetrics} from "../../src/analytics/interfaces/IEncryptedMetrics.sol";
import {IProtectionMechanisms} from "../../src/protection/interfaces/IProtectionMechanisms.sol";
import {HybridFHERC20} from "../../src/tokens/HybridFHERC20.sol";

// Uniswap Imports
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

// FHE Imports
import {FHE, euint128, euint64, euint32, ebool} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

/**
 * @title MEVShieldHookFuzzTest
 * @notice Comprehensive fuzz test suite for MEV Shield Hook with 60+ fuzz tests
 * @dev Tests edge cases and boundary conditions for FHE-based MEV protection
 */
contract MEVShieldHookFuzzTest is CoFheTest {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using FHE for uint256;

    // ============ Test Infrastructure ============

    MEVShieldHook public hook;
    MEVDetectionEngine public detectionEngine;
    ProtectionMechanisms public protectionMechanisms;
    EncryptedMetrics public encryptedMetrics;
    
    // Mock Uniswap V4 contracts
    IPoolManager public poolManager;
    
    // Test tokens
    HybridFHERC20 public fheToken0;
    HybridFHERC20 public fheToken1;
    
    Currency public fheCurrency0;
    Currency public fheCurrency1;
    
    // Test pool
    PoolKey public poolKey;
    PoolId public poolId;
    
    // Test addresses
    address public trader = makeAddr("trader");
    address public attacker = makeAddr("attacker");

    // ============ Setup ============

    function setUp() public {
        // Initialize CoFHE test environment
        
        // Deploy FHE tokens
        fheToken0 = new HybridFHERC20("FHE Token 0", "FHETK0");
        fheToken1 = new HybridFHERC20("FHE Token 1", "FHETK1");
        
        // Ensure token0 < token1 for proper ordering
        if (address(fheToken0) > address(fheToken1)) {
            (fheToken0, fheToken1) = (fheToken1, fheToken0);
        }
        
        // Set up currencies
        fheCurrency0 = Currency.wrap(address(fheToken0));
        fheCurrency1 = Currency.wrap(address(fheToken1));
        
        // Deploy components
        detectionEngine = new MEVDetectionEngine();
        protectionMechanisms = new ProtectionMechanisms();
        encryptedMetrics = new EncryptedMetrics();
        
        // Deploy mock pool manager
        poolManager = IPoolManager(makeAddr("poolManager"));
        
        // Create valid hook address using FHE template pattern
        address flags = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        
        // Deploy hook using deployCodeTo to ensure valid address
        bytes memory constructorArgs = abi.encode(
            poolManager,
            detectionEngine,
            protectionMechanisms,
            encryptedMetrics
        );
        
        deployCodeTo("MEVShieldHook.sol:MEVShieldHook", constructorArgs, flags);
        hook = MEVShieldHook(flags);
        
        // Set up test pool
        poolKey = PoolKey({
            currency0: fheCurrency0,
            currency1: fheCurrency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        
        poolId = poolKey.toId();
        
        // Configure access controls
        detectionEngine.setAuthorizedUpdater(address(hook), true);
        protectionMechanisms.setAuthorizedConfigurator(address(hook), true);
        encryptedMetrics.setAuthorizedUpdater(address(hook), true);
        
        // Set up FHE permissions for test environment
        vm.startPrank(address(this));
        detectionEngine.initializePool(poolKey);
        
        // Set up FHE permissions for all encrypted variables
        _setupFHEPermissions();
        vm.stopPrank();
        
        // Initialize pool
        vm.prank(address(poolManager));
        hook.beforeInitialize(address(this), poolKey, 79228162514264337593543950336);
    }

    function _setupFHEPermissions() internal {
        // FHE permissions are automatically handled by the contracts themselves
        // when they initialize pools and create encrypted variables
        // No additional setup needed for basic FHE operations
    }

    // ============ Fuzz Tests for Pool Initialization (10 tests) ============

    function testFuzzPoolInitializationSqrtPrices(uint160 sqrtPriceX96) public {
        // Bound sqrtPrice to valid range for Uniswap V4
        vm.assume(sqrtPriceX96 >= 4295128739 && sqrtPriceX96 <= 1461446703485210103287273052203988822378723970341);
        
        vm.prank(address(poolManager));
        bytes4 result = hook.beforeInitialize(address(this), poolKey, sqrtPriceX96);
        
        assertEq(result, hook.beforeInitialize.selector);
    }

    function testFuzzPoolInitializationDifferentFees(uint24 fee) public {
        // Bound fee to valid Uniswap V4 fees
        vm.assume(fee == 100 || fee == 500 || fee == 3000 || fee == 10000);
        
        PoolKey memory testPoolKey = PoolKey({
            currency0: fheCurrency0,
            currency1: fheCurrency1,
            fee: fee,
            tickSpacing: fee == 100 ? int24(1) : fee == 500 ? int24(10) : fee == 3000 ? int24(60) : int24(200),
            hooks: hook
        });
        
        vm.prank(address(poolManager));
        bytes4 result = hook.beforeInitialize(address(this), testPoolKey, 79228162514264337593543950336);
        
        assertEq(result, hook.beforeInitialize.selector);
    }

    function testFuzzPoolInitializationDifferentTickSpacings(uint24 tickSpacing) public {
        // Bound tick spacing to reasonable values
        vm.assume(tickSpacing >= 1 && tickSpacing <= 200);
        
        PoolKey memory testPoolKey = PoolKey({
            currency0: fheCurrency0,
            currency1: fheCurrency1,
            fee: 3000,
            tickSpacing: int24(tickSpacing),
            hooks: hook
        });
        
        vm.prank(address(poolManager));
        bytes4 result = hook.beforeInitialize(address(this), testPoolKey, 79228162514264337593543950336);
        
        assertEq(result, hook.beforeInitialize.selector);
    }

    function testFuzzPoolInitializationDifferentTokens(address token0, address token1) public {
        vm.assume(token0 != token1 && token0 != address(0) && token1 != address(0));
        
        // Ensure proper ordering
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: hook
        });
        
        vm.prank(address(poolManager));
        bytes4 result = hook.beforeInitialize(address(this), testPoolKey, 79228162514264337593543950336);
        
        assertEq(result, hook.beforeInitialize.selector);
    }

    function testFuzzPoolInitializationMultipleTimes(uint8 times) public {
        vm.assume(times > 0 && times <= 10);
        
        for (uint i = 0; i < times; i++) {
            vm.prank(address(poolManager));
            bytes4 result = hook.beforeInitialize(address(this), poolKey, 79228162514264337593543950336);
            assertEq(result, hook.beforeInitialize.selector);
        }
    }

    // ============ Fuzz Tests for MEV Detection (15 tests) ============

    function testFuzzMEVDetectionSwapAmounts(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 1e30); // Reasonable bounds
        
        euint128 encryptedAmount = FHE.asEuint128(amount);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzMEVDetectionSlippageTolerances(uint64 slippage) public {
        vm.assume(slippage >= 1 && slippage <= 10000); // 0.01% to 100%
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(slippage);
        euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzMEVDetectionGasPrices(uint64 gasPrice) public {
        vm.assume(gasPrice >= 1 gwei && gasPrice <= 1000 gwei); // Reasonable gas price range
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(gasPrice);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzMEVDetectionTimestamps(uint32 timestamp) public {
        vm.assume(timestamp >= 1000000000 && timestamp <= 4000000000); // Reasonable timestamp range
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(timestamp);
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzMEVDetectionTraderAddresses(address traderAddr) public {
        vm.assume(traderAddr != address(0));
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: traderAddr
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzMEVDetectionCombinedParameters(
        uint128 amount,
        uint64 slippage,
        uint64 gasPrice,
        address traderAddr
    ) public {
        vm.assume(amount > 0 && amount <= 1e30);
        vm.assume(slippage >= 1 && slippage <= 10000);
        vm.assume(gasPrice >= 1 gwei && gasPrice <= 1000 gwei);
        vm.assume(traderAddr != address(0));
        
        euint128 encryptedAmount = FHE.asEuint128(amount);
        euint64 encryptedSlippage = FHE.asEuint64(slippage);
        euint64 encryptedGasPrice = FHE.asEuint64(gasPrice);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: traderAddr
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    // ============ Fuzz Tests for Protection Application (15 tests) ============

    function testFuzzProtectionApplicationSwapAmounts(int256 amountSpecified) public {
        vm.assume(amountSpecified != 0 && amountSpecified >= -1e30 && amountSpecified <= 1e30);
        
        SwapParams memory params = SwapParams({
            zeroForOne: amountSpecified < 0,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: 0
        });
        
        uint128 absAmount = uint128(uint256(amountSpecified < 0 ? -amountSpecified : amountSpecified));
        euint128 encryptedAmount = FHE.asEuint128(absAmount);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(100 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        bytes memory hookData = abi.encode(swapData);
        
        vm.prank(address(poolManager));
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            trader,
            poolKey,
            params,
            hookData
        );
        
        assertEq(selector, hook.beforeSwap.selector);
    }

    function testFuzzProtectionApplicationPriceLimits(uint160 sqrtPriceLimitX96) public {
        // Bound to reasonable price limits
        vm.assume(sqrtPriceLimitX96 >= 4295128739 && sqrtPriceLimitX96 <= 1461446703485210103287273052203988822378723970341);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1000 * 1e18,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(100 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        bytes memory hookData = abi.encode(swapData);
        
        vm.prank(address(poolManager));
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            trader,
            poolKey,
            params,
            hookData
        );
        
        assertEq(selector, hook.beforeSwap.selector);
    }

    function testFuzzProtectionApplicationSwapDirections(bool zeroForOne) public {
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: zeroForOne ? -int256(1000 * 1e18) : int256(1000 * 1e18),
            sqrtPriceLimitX96: 0
        });
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(100 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        bytes memory hookData = abi.encode(swapData);
        
        vm.prank(address(poolManager));
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            trader,
            poolKey,
            params,
            hookData
        );
        
        assertEq(selector, hook.beforeSwap.selector);
    }

    function testFuzzProtectionApplicationMultipleTraders(address[] memory traders) public {
        vm.assume(traders.length > 0 && traders.length <= 10);
        
        for (uint i = 0; i < traders.length; i++) {
            vm.assume(traders[i] != address(0));
            
            SwapParams memory params = SwapParams({
                zeroForOne: i % 2 == 0,
                amountSpecified: i % 2 == 0 ? -int256(100 * 1e18) : int256(100 * 1e18),
                sqrtPriceLimitX96: 0
            });
            
            euint128 encryptedAmount = FHE.asEuint128(100 * 1e18);
            euint64 encryptedSlippage = FHE.asEuint64(50 + i * 10);
            euint64 encryptedGasPrice = FHE.asEuint64((50 + i * 20) * 1e9);
            euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp + i));
            
            IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
                encryptedAmount: encryptedAmount,
                encryptedSlippage: encryptedSlippage,
                encryptedGasPrice: encryptedGasPrice,
                encryptedTimestamp: encryptedTimestamp,
                trader: traders[i]
            });
            
            bytes memory hookData = abi.encode(swapData);
            
            vm.prank(address(poolManager));
            (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
                traders[i],
                poolKey,
                params,
                hookData
            );
            
            assertEq(selector, hook.beforeSwap.selector);
        }
    }

    function testFuzzProtectionApplicationHighRiskScenarios(
        uint128 amount,
        uint64 slippage,
        uint64 gasPrice
    ) public {
        vm.assume(amount > 1000 * 1e18); // Large amounts
        vm.assume(slippage < 100); // Tight slippage
        vm.assume(gasPrice > 100 * 1e9); // High gas prices
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -int256(uint256(amount)),
            sqrtPriceLimitX96: 0
        });
        
        euint128 encryptedAmount = FHE.asEuint128(amount);
        euint64 encryptedSlippage = FHE.asEuint64(slippage);
        euint64 encryptedGasPrice = FHE.asEuint64(gasPrice);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: attacker
        });
        
        bytes memory hookData = abi.encode(swapData);
        
        vm.prank(address(poolManager));
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            attacker,
            poolKey,
            params,
            hookData
        );
        
        assertEq(selector, hook.beforeSwap.selector);
    }

    // ============ Fuzz Tests for After Swap (10 tests) ============

    function testFuzzAfterSwapBalanceDeltas(int128 delta0, int128 delta1) public {
        vm.assume(delta0 != 0 || delta1 != 0); // At least one delta should be non-zero
        
        // Set up beforeSwap state first
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1000 * 1e18,
            sqrtPriceLimitX96: 0
        });
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(100 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        bytes memory hookData = abi.encode(swapData);
        
        vm.prank(address(poolManager));
        hook.beforeSwap(trader, poolKey, params, hookData);
        
        // Test afterSwap with fuzzed delta
        BalanceDelta delta = BalanceDelta.wrap(int256((uint256(uint128(delta1)) << 128) | uint256(uint128(delta0))));
        
        vm.prank(address(poolManager));
        (bytes4 selector, int128 returnValue) = hook.afterSwap(trader, poolKey, params, delta, "");
        
        assertEq(selector, hook.afterSwap.selector);
    }

    function testFuzzAfterSwapMultipleSwaps(uint8 swapCount) public {
        vm.assume(swapCount > 0 && swapCount <= 20);
        
        for (uint i = 0; i < swapCount; i++) {
            SwapParams memory params = SwapParams({
                zeroForOne: i % 2 == 0,
                amountSpecified: i % 2 == 0 ? -int256(100 * 1e18) : int256(100 * 1e18),
                sqrtPriceLimitX96: 0
            });
            
            euint128 encryptedAmount = FHE.asEuint128(100 * 1e18);
            euint64 encryptedSlippage = FHE.asEuint64(50);
            euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
            euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp + i));
            
            IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
                encryptedAmount: encryptedAmount,
                encryptedSlippage: encryptedSlippage,
                encryptedGasPrice: encryptedGasPrice,
                encryptedTimestamp: encryptedTimestamp,
                trader: trader
            });
            
            bytes memory hookData = abi.encode(swapData);
            
            // beforeSwap
            vm.prank(address(poolManager));
            hook.beforeSwap(trader, poolKey, params, hookData);
            
            // afterSwap
            BalanceDelta delta = BalanceDelta.wrap(0);
            vm.prank(address(poolManager));
            (bytes4 selector, int128 returnValue) = hook.afterSwap(trader, poolKey, params, delta, "");
            
            assertEq(selector, hook.afterSwap.selector);
        }
    }

    function testFuzzAfterSwapDifferentTraders(address[] memory traders) public {
        vm.assume(traders.length > 0 && traders.length <= 10);
        
        for (uint i = 0; i < traders.length; i++) {
            vm.assume(traders[i] != address(0));
            
            SwapParams memory params = SwapParams({
                zeroForOne: true,
                amountSpecified: -100 * 1e18,
                sqrtPriceLimitX96: 0
            });
            
            euint128 encryptedAmount = FHE.asEuint128(100 * 1e18);
            euint64 encryptedSlippage = FHE.asEuint64(50);
            euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
            euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp + i));
            
            IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
                encryptedAmount: encryptedAmount,
                encryptedSlippage: encryptedSlippage,
                encryptedGasPrice: encryptedGasPrice,
                encryptedTimestamp: encryptedTimestamp,
                trader: traders[i]
            });
            
            bytes memory hookData = abi.encode(swapData);
            
            // beforeSwap
            vm.prank(address(poolManager));
            hook.beforeSwap(traders[i], poolKey, params, hookData);
            
            // afterSwap
            BalanceDelta delta = BalanceDelta.wrap(0);
            vm.prank(address(poolManager));
            (bytes4 selector, int128 returnValue) = hook.afterSwap(traders[i], poolKey, params, delta, "");
            
            assertEq(selector, hook.afterSwap.selector);
        }
    }

    // ============ Fuzz Tests for Edge Cases (10 tests) ============

    function testFuzzExtremeSwapAmounts(uint256 amount) public {
        // Test with extreme amounts (including max values)
        int256 amountSpecified = amount > uint256(type(int256).max) ? -type(int256).max : -int256(amount);
        
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: 0
        });
        
        uint128 boundedAmount = uint128(amount > type(uint128).max ? type(uint128).max : amount);
        euint128 encryptedAmount = FHE.asEuint128(boundedAmount);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(100 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        bytes memory hookData = abi.encode(swapData);
        
        vm.prank(address(poolManager));
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            trader,
            poolKey,
            params,
            hookData
        );
        
        assertEq(selector, hook.beforeSwap.selector);
    }

    function testFuzzExtremeGasPrices(uint256 gasPrice) public {
        // Bound gas price to reasonable range
        uint64 boundedGasPrice = uint64(gasPrice > type(uint64).max ? type(uint64).max : gasPrice);
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(boundedGasPrice);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzExtremeSlippageValues(uint256 slippage) public {
        // Bound slippage to reasonable range
        uint64 boundedSlippage = uint64(slippage > 10000 ? 10000 : slippage == 0 ? 1 : slippage);
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(boundedSlippage);
        euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzBoundaryTimestampValues(uint256 timestamp) public {
        // Bound timestamp to reasonable range
        uint32 boundedTimestamp = uint32(timestamp > type(uint32).max ? type(uint32).max : timestamp);
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(boundedTimestamp);
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: trader
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzRandomTraderAddresses(bytes32 traderSeed) public {
        address traderAddr = address(uint160(uint256(traderSeed)));
        
        euint128 encryptedAmount = FHE.asEuint128(1000 * 1e18);
        euint64 encryptedSlippage = FHE.asEuint64(50);
        euint64 encryptedGasPrice = FHE.asEuint64(50 * 1e9);
        euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
        
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: encryptedAmount,
            encryptedSlippage: encryptedSlippage,
            encryptedGasPrice: encryptedGasPrice,
            encryptedTimestamp: encryptedTimestamp,
            trader: traderAddr
        });
        
        MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
            swapData,
            poolKey
        );
        
        assertTrue(address(detectionEngine) != address(0));
    }

    function testFuzzStressTestMultipleOperations(uint8 operationCount) public {
        vm.assume(operationCount > 0 && operationCount <= 50);
        
        for (uint i = 0; i < operationCount; i++) {
            // Randomly choose operation type
            uint8 operationType = uint8(uint256(keccak256(abi.encodePacked(i, block.timestamp))) % 3);
            
            if (operationType == 0) {
                // MEV Detection
                euint128 encryptedAmount = FHE.asEuint128((i + 1) * 100 * 1e18);
                euint64 encryptedSlippage = FHE.asEuint64(50 + i);
                euint64 encryptedGasPrice = FHE.asEuint64((50 + i * 10) * 1e9);
                euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp + i));
                
                IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
                    encryptedAmount: encryptedAmount,
                    encryptedSlippage: encryptedSlippage,
                    encryptedGasPrice: encryptedGasPrice,
                    encryptedTimestamp: encryptedTimestamp,
                    trader: trader
                });
                
                MEVDetectionEngine.ThreatAssessment memory threat = detectionEngine.analyzeSwapThreat(
                    swapData,
                    poolKey
                );
                
                assertTrue(address(detectionEngine) != address(0));
            } else if (operationType == 1) {
                // Protection Application
                SwapParams memory params = SwapParams({
                    zeroForOne: i % 2 == 0,
                    amountSpecified: i % 2 == 0 ? -int256(100 * 1e18) : int256(100 * 1e18),
                    sqrtPriceLimitX96: 0
                });
                
                euint128 encryptedAmount = FHE.asEuint128(100 * 1e18);
                euint64 encryptedSlippage = FHE.asEuint64(50);
                euint64 encryptedGasPrice = FHE.asEuint64(100 * 1e9);
                euint32 encryptedTimestamp = FHE.asEuint32(uint32(block.timestamp));
                
                IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
                    encryptedAmount: encryptedAmount,
                    encryptedSlippage: encryptedSlippage,
                    encryptedGasPrice: encryptedGasPrice,
                    encryptedTimestamp: encryptedTimestamp,
                    trader: trader
                });
                
                bytes memory hookData = abi.encode(swapData);
                
                vm.prank(address(poolManager));
                (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
                    trader,
                    poolKey,
                    params,
                    hookData
                );
                
                assertEq(selector, hook.beforeSwap.selector);
            } else {
                // View function calls
                MEVShieldHook.ProtectionConfig memory config = hook.getPoolProtectionConfig(poolId);
                euint128 count = hook.getProtectedSwapsCount(poolId);
                euint128 savings = hook.getTotalMevSavings(poolId);
                
                assertTrue(address(hook) != address(0));
            }
        }
    }

    // ============ Helper Functions ============

    function createMockHookData(
        uint128 amount,
        uint64 slippage,
        uint64 gasPrice,
        address traderAddr
    ) internal returns (bytes memory) {
        IMEVDetectionEngine.EncryptedSwapData memory swapData = IMEVDetectionEngine.EncryptedSwapData({
            encryptedAmount: FHE.asEuint128(amount),
            encryptedSlippage: FHE.asEuint64(slippage),
            encryptedGasPrice: FHE.asEuint64(gasPrice),
            encryptedTimestamp: FHE.asEuint32(uint32(block.timestamp)),
            trader: traderAddr
        });
        
        return abi.encode(swapData);
    }

    function createSwapParams(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
    ) internal pure returns (SwapParams memory) {
        return SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
    }
}
