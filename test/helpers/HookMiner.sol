// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
        
        for (uint256 i = 0; i < 100000; i++) {
            salt = keccak256(abi.encodePacked(i));
            hookAddress = computeAddress(deployer, salt, bytecode);
            
            if (uint160(hookAddress) & uint160(0x7FF) == flags) {
                return (hookAddress, salt);
            }
        }
        
        revert("HookMiner: Could not find salt");
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