// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {MEVShieldHook} from "../src/hooks/MEVShieldHook.sol";
import {MEVDetectionEngine} from "../src/detection/MEVDetectionEngine.sol";
import {ProtectionMechanisms} from "../src/protection/ProtectionMechanisms.sol";
import {EncryptedMetrics} from "../src/analytics/EncryptedMetrics.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

contract DeployAnvilScript is Script {
    function run() external {
        // Use default Anvil account
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying to Anvil network...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        // For Anvil, we'll use a mock PoolManager
        IPoolManager poolManager = IPoolManager(makeAddr("poolManager"));
        console.log("Using mock PoolManager at:", address(poolManager));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy core components
        MEVDetectionEngine detectionEngine = new MEVDetectionEngine();
        console.log("MEVDetectionEngine deployed at:", address(detectionEngine));
        
        ProtectionMechanisms protectionMechanisms = new ProtectionMechanisms();
        console.log("ProtectionMechanisms deployed at:", address(protectionMechanisms));
        
        EncryptedMetrics encryptedMetrics = new EncryptedMetrics();
        console.log("EncryptedMetrics deployed at:", address(encryptedMetrics));
        
        // Deploy main hook (simplified for Anvil)
        MEVShieldHook hook = new MEVShieldHook(
            poolManager,
            detectionEngine,
            protectionMechanisms,
            encryptedMetrics
        );
        console.log("MEVShieldHook deployed at:", address(hook));
        
        vm.stopBroadcast();
        
        console.log("Anvil deployment completed!");
        console.log("Hook address:", address(hook));
    }
}
