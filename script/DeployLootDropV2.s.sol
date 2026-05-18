// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LootDrop.sol";

contract DeployLootDropV2 is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        
        address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
        uint64 subId = 6556;
        bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
        address gameItems = 0x31E53C56AbDF6D2ba9aD5bB7aC2966794b08C16C;
        
        vm.startBroadcast(deployerKey);
        
        LootDrop lootDrop = new LootDrop(vrfCoordinator, subId, keyHash, gameItems);
        
        console.log("LootDrop deployed at:", address(lootDrop));
        
        vm.stopBroadcast();
    }
}
