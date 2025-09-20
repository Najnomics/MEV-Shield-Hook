// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

/**
 * @title HookMiner
 * @notice Utility for mining salts to deploy hooks with specific addresses
 */
library HookMiner {
    /**
     * @notice Find a salt that will produce a hook address with the desired flags
     * @param deployer The address that will deploy the hook
     * @param flags The desired flags for the hook address
     * @param creationCode The creation code of the hook contract
     * @param constructorArgs The encoded constructor arguments
     * @return hookAddress The address of the hook that will be deployed
     * @return salt The salt to use for deployment
     */
    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal pure returns (address hookAddress, bytes32 salt) {
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
        
        // Mine for a valid salt by brute force
        uint256 nonce = 0;
        while (true) {
            salt = keccak256(abi.encodePacked("hook-salt", nonce));
            hookAddress = computeAddress(deployer, salt, bytecode);
            
            // Check if the address has the required flags
            if (uint160(hookAddress) & flags == flags) {
                break;
            }
            
            nonce++;
            // Prevent infinite loops in case of misconfiguration
            require(nonce < 100000, "HookMiner: Could not find valid address");
        }
        
        return (hookAddress, salt);
    }

    /**
     * @notice Create flags from hook permissions
     * @param permissions The permissions for the hook
     * @return flags The flags as a uint160
     */
    function createFlags(Hooks.Permissions memory permissions) internal pure returns (uint160 flags) {
        return uint160(
            (permissions.beforeInitialize ? 1 << 159 : 0) |
            (permissions.afterInitialize ? 1 << 158 : 0) |
            (permissions.beforeAddLiquidity ? 1 << 157 : 0) |
            (permissions.afterAddLiquidity ? 1 << 156 : 0) |
            (permissions.beforeRemoveLiquidity ? 1 << 155 : 0) |
            (permissions.afterRemoveLiquidity ? 1 << 154 : 0) |
            (permissions.beforeSwap ? 1 << 153 : 0) |
            (permissions.afterSwap ? 1 << 152 : 0) |
            (permissions.beforeDonate ? 1 << 151 : 0) |
            (permissions.afterDonate ? 1 << 150 : 0) |
            (permissions.beforeSwapReturnDelta ? 1 << 149 : 0) |
            (permissions.afterSwapReturnDelta ? 1 << 148 : 0) |
            (permissions.afterAddLiquidityReturnDelta ? 1 << 147 : 0) |
            (permissions.afterRemoveLiquidityReturnDelta ? 1 << 146 : 0)
        );
    }
    
    /**
     * @notice Compute the address of a contract deployed via CREATE2
     * @param deployer The address that will deploy the contract
     * @param salt The salt to use for deployment
     * @param bytecode The bytecode of the contract
     * @return The address where the contract will be deployed
     */
    function computeAddress(
        address deployer,
        bytes32 salt,
        bytes memory bytecode
    ) internal pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            deployer,
                            salt,
                            keccak256(bytecode)
                        )
                    )
                )
            )
        );
    }
}