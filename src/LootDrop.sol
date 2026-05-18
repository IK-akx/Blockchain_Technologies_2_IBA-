// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GameItems.sol";

contract LootDrop is Ownable {
    VRFCoordinatorV2Interface public COORDINATOR;
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 250000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;
    
    uint256 public lastRequestId;
    
    mapping(uint256 => address) public requestToPlayer;
    GameItems public gameItems;
    
    event LootRequested(uint256 indexed requestId, address indexed player);
    event LootDropped(address indexed player, uint256 itemId);
    
    constructor(
        address _vrfCoordinator,
        uint64 _subId,
        bytes32 _keyHash,
        address _gameItems
    ) Ownable(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subId;
        keyHash = _keyHash;
        gameItems = GameItems(_gameItems);
    }
    
    receive() external payable {}
    
    function requestLoot() external payable {
        require(msg.value >= 0.001 ether, "Need 0.001 ETH");
        
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        
        requestToPlayer[requestId] = msg.sender;
        lastRequestId = requestId;
        emit LootRequested(requestId, msg.sender);
    }
    
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        require(msg.sender == address(COORDINATOR), "Only coordinator");
        
        address player = requestToPlayer[requestId];
        if (player == address(0)) return;
        
        uint256 random = randomWords[0];
        uint256 totalItems = gameItems.nextItemId();
        if (totalItems == 0) return;
        
        uint256 itemId = random % totalItems;
        gameItems.mintItem(player, itemId, 1);
        emit LootDropped(player, itemId);
    }
}