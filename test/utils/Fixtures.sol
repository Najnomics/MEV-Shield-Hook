// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Deployers} from "./Deployers.sol";

/**
 * @title Fixtures
 * @notice Simplified test fixtures for MEV Shield Hook testing
 */
contract Fixtures is Deployers {
    uint256 constant STARTING_USER_BALANCE = 10_000_000 ether;

    IPositionManager posm;
    
    function deployAndApprovePosm(IPoolManager poolManager) public {
        deployPosm(poolManager);
        approvePosm(currency0, currency1);
    }

    function deployAndApprovePosm(IPoolManager poolManager, Currency curr0, Currency curr1) public {
        deployPosm(poolManager);
        approvePosm(curr0, curr1);
    }

    function deployPosm(IPoolManager poolManager) internal {
        // Simplified position manager deployment
        // In production tests, this would deploy the full PositionManager
        posm = IPositionManager(address(0x1234)); // Mock address
    }

    function seedBalance(address to) internal {
        IERC20(Currency.unwrap(currency0)).transfer(to, STARTING_USER_BALANCE);
        IERC20(Currency.unwrap(currency1)).transfer(to, STARTING_USER_BALANCE);
    }

    function approvePosm(Currency curr0, Currency curr1) internal {
        approvePosmCurrency(curr0);
        approvePosmCurrency(curr1);
    }

    function approvePosmCurrency(Currency currency) internal {
        IERC20(Currency.unwrap(currency)).approve(address(posm), type(uint256).max);
    }

    function approvePosmFor(address addr) internal {
        vm.startPrank(addr);
        approvePosm(currency0, currency1);
        vm.stopPrank();
    }
}