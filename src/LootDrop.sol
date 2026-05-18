// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GameItems.sol";

contract LootDrop is VRFConsumerBaseV2, Ownable {
    VRFCoordinatorV2Interface immutable COORDINATOR;
    uint64 immutable subscriptionId;
    bytes32 immutable keyHash;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    mapping(uint256 => address) public requestToPlayer;
    mapping(uint256 => uint256) public requestToItemId;

    GameItems public gameItems;

    event LootRequested(uint256 indexed requestId, address indexed player);
    event LootDropped(address indexed player, uint256 itemId);

    constructor(address _vrfCoordinator, uint64 _subId, bytes32 _keyHash, address _gameItems)
        VRFConsumerBaseV2(_vrfCoordinator)
        Ownable(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subId;
        keyHash = _keyHash;
        gameItems = GameItems(_gameItems);
    }

    function requestLoot() external {
        uint256 requestId =
            COORDINATOR.requestRandomWords(keyHash, subscriptionId, requestConfirmations, callbackGasLimit, numWords);
        requestToPlayer[requestId] = msg.sender;
        emit LootRequested(requestId, msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address player = requestToPlayer[requestId];
        require(player != address(0), "LootDrop: unknown request");
        uint256 random = randomWords[0];
        // Assume item IDs start from 0, up to total items - 1
        uint256 totalItems = gameItems.nextItemId(); // we need to add getter in GameItems
        if (totalItems == 0) return;
        uint256 itemId = random % totalItems;
        // Mint 1 copy of the random item to player
        gameItems.mintItem(player, itemId, 1);
        emit LootDropped(player, itemId);
    }
}
