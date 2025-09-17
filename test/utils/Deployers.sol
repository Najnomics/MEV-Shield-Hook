// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/**
 * @title Deployers
 * @notice Simplified deployer utilities for testing
 */
contract Deployers is Test {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    IPoolManager manager;
    PoolKey key;
    Currency currency0;
    Currency currency1;

    function deployFreshManagerAndRouters() internal {
        // Deploy simplified pool manager for testing
        manager = new PoolManager(address(this));
    }

    function initPool(
        Currency _currency0,
        Currency _currency1,
        IHooks hooks,
        uint24 fee,
        uint160 sqrtPriceX96
    ) internal returns (PoolKey memory _key, PoolId id) {
        _key = PoolKey(_currency0, _currency1, fee, 60, hooks);
        id = _key.toId();
        
        manager.initialize(_key, sqrtPriceX96);
        
        key = _key;
        currency0 = _currency0;
        currency1 = _currency1;
    }

    // Mock router for testing
    MockSwapRouter public swapRouter;

    constructor() {
        swapRouter = new MockSwapRouter();
    }
}

/**
 * @title MockSwapRouter
 * @notice Simplified swap router for testing
 */
contract MockSwapRouter {
    function exactInputSingle(
        SwapParams memory params,
        PoolKey memory key,
        bytes memory data
    ) external returns (uint256 amountOut) {
        // Mock implementation - just return a value
        return 1000;
    }
}