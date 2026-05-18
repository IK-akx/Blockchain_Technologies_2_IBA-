// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/GameItems.sol";
import "../src/ResourceAMM.sol";
import "../src/GameToken.sol";
import "../src/GameGovernor.sol";
import "../src/LootDrop.sol";
import "../src/OracleAdapter.sol";
import "../src/RentalVault4626.sol";
import "../src/GameFactory.sol";
import "../src/GameParameters.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        
        console.log("Deploying from:", deployer);
        
        vm.startBroadcast(deployerKey);
        
        // ============ 1. DEPLOY CORE CONTRACTS ============
        console.log("\n--- Deploying Core ---");
        
        // GameItems (ERC-1155)
        GameItems gameItems = new GameItems();
        console.log("GameItems:", address(gameItems));
        
        // GameToken (ERC20Votes)
        GameToken gameToken = new GameToken("Game Governance Token", "GGT");
        console.log("GameToken:", address(gameToken));
        
        // OracleAdapter (Chainlink)
        address ethUsdFeed = vm.envAddress("CHAINLINK_ETH_USD");
        OracleAdapter oracle = new OracleAdapter(ethUsdFeed);
        console.log("OracleAdapter:", address(oracle));
        
        // GameParameters
        GameParameters gameParams = new GameParameters();
        console.log("GameParameters:", address(gameParams));
        
        // ResourceAMM (needs two token addresses - use GameToken and a mock)
        // For now, deploy with placeholders
        ResourceAMM amm = new ResourceAMM(address(gameToken), address(gameItems));
        console.log("ResourceAMM:", address(amm));
        
        // ============ 2. DEPLOY GOVERNANCE ============
        console.log("\n--- Deploying Governance ---");
        
        // TimelockController (2-day delay)
        uint256 timelockDelay = 2 days;
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(0);  // Will be set to Governor
        executors[0] = address(0);  // Anyone can execute
        
        TimelockController timelock = new TimelockController(
            timelockDelay,
            proposers,
            executors,
            deployer
        );
        console.log("Timelock:", address(timelock));
        
        // GameGovernor
        uint48 votingDelay = 7200;   // ~1 day in blocks
        uint32 votingPeriod = 50400; // ~1 week
        GameGovernor governor = new GameGovernor(
            IVotes(address(gameToken)),
            timelock,
            votingDelay,
            votingPeriod
        );
        console.log("Governor:", address(governor));
        
        // ============ 3. SETUP ROLES ============
        console.log("\n--- Setting up roles ---");
        
        // Grant PROPOSER_ROLE to Governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        
        // Grant CANCELLER_ROLE to Governor
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        
        // Revoke admin role from deployer (decentralize!)
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        console.log("Timelock admin renounced - DAO is now decentralized");
        
        // Transfer GameToken ownership to Timelock
        gameToken.transferOwnership(address(timelock));
        
        // Grant GOVERNOR_ROLE in GameParameters
        gameParams.grantGovernorRole(address(governor));
        
        // ============ 4. DEPLOY FACTORY ============
        console.log("\n--- Deploying Factory ---");
        
        GameFactory factory = new GameFactory();
        console.log("GameFactory:", address(factory));
        
        // Test CREATE2 deterministic deployment
        bytes32 salt = keccak256("gamefi-v1");
        address predicted = factory.predictVaultAddress(salt);
        console.log("Predicted CREATE2 address:", predicted);
        
        // ============ 5. DEPLOY LOOT DROP (Chainlink VRF) ============
        console.log("\n--- Deploying LootDrop ---");
        
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        uint64 subId = 1; // You need to create subscription in Chainlink
        
        LootDrop lootDrop = new LootDrop(
            vrfCoordinator,
            subId,
            vm.envBytes32("VRF_KEYHASH"),
            address(gameItems)
        );
        console.log("LootDrop:", address(lootDrop));
        
        // ============ 6. DEPLOY RENTAL VAULT (ERC-4626) ============
        console.log("\n--- Deploying RentalVault4626 ---");
        
        RentalVault4626 rentalVault = new RentalVault4626(
            IERC20(address(gameToken)),
            IERC1155(address(gameItems))
        );
        console.log("RentalVault4626:", address(rentalVault));
        
        vm.stopBroadcast();
        
        // ============ SUMMARY ============
        console.log("\n========== DEPLOYMENT COMPLETE ==========");
        console.log("GameItems:", address(gameItems));
        console.log("GameToken:", address(gameToken));
        console.log("ResourceAMM:", address(amm));
        console.log("OracleAdapter:", address(oracle));
        console.log("GameParameters:", address(gameParams));
        console.log("Timelock:", address(timelock));
        console.log("Governor:", address(governor));
        console.log("GameFactory:", address(factory));
        console.log("LootDrop:", address(lootDrop));
        console.log("RentalVault4626:", address(rentalVault));
        console.log("==========================================");
    }
}