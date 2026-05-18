// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LootDrop.sol";

contract DeployFixedLootDrop is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address gameItems = 0x31E53C56AbDF6D2ba9aD5bB7aC2966794b08C16C;
        
        vm.startBroadcast(deployerKey);
        
        LootDrop lootDrop = new LootDrop(gameItems);
        
        console.log("Fixed LootDrop deployed at:", address(lootDrop));
        
        vm.stopBroadcast();
    }
}
