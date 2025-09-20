// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {MEVShieldHook} from "../src/hooks/MEVShieldHook.sol";
import {MEVDetectionEngine} from "../src/detection/MEVDetectionEngine.sol";
import {ProtectionMechanisms} from "../src/protection/ProtectionMechanisms.sol";
import {EncryptedMetrics} from "../src/analytics/EncryptedMetrics.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

contract DeployScript is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying MEV Shield Hook contracts...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        
        // Get the existing PoolManager for this chain
        IPoolManager poolManager = IPoolManager(getPoolManagerByChainId(block.chainid));
        console.log("Using PoolManager at:", address(poolManager));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy core components
        MEVDetectionEngine detectionEngine = new MEVDetectionEngine();
        console.log("MEVDetectionEngine deployed at:", address(detectionEngine));
        
        ProtectionMechanisms protectionMechanisms = new ProtectionMechanisms();
        console.log("ProtectionMechanisms deployed at:", address(protectionMechanisms));
        
        EncryptedMetrics encryptedMetrics = new EncryptedMetrics();
        console.log("EncryptedMetrics deployed at:", address(encryptedMetrics));
        
        // Hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        
        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManager, detectionEngine, protectionMechanisms, encryptedMetrics);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(MEVShieldHook).creationCode, constructorArgs);
        
        console.log("Found hook address:", hookAddress);
        
        // Deploy main hook using CREATE2
        MEVShieldHook hook = new MEVShieldHook{salt: salt}(
            poolManager,
            detectionEngine,
            protectionMechanisms,
            encryptedMetrics
        );
        
        require(address(hook) == hookAddress, "DeployScript: hook address mismatch");
        
        vm.stopBroadcast();
        
        console.log("Deployment completed successfully!");
        console.log("Hook address:", address(hook));
    }
    
    function getPoolManagerByChainId(uint256 chainId) internal pure returns (address) {
        // Add known PoolManager addresses for different networks
        if (chainId == 1) {
            return address(0x0000000000000000000000000000000000000000); // Ethereum mainnet (placeholder)
        } else if (chainId == 11155111) {
            return address(0x0000000000000000000000000000000000000000); // Sepolia testnet (placeholder)
        } else if (chainId == 42069) {
            return address(0x0000000000000000000000000000000000000000); // Fhenix testnet (placeholder)
        } else {
            revert("Unsupported chain ID");
        }
    }
}
