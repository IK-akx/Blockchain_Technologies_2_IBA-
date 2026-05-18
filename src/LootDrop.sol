// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GameItems.sol";

contract LootDrop is VRFV2WrapperConsumerBase, Ownable {
    // Sepolia VRF V2 Wrapper
    address constant WRAPPER_ADDRESS = 0xab18414CD93297B0d12ac29E63Ca20f515b3DB46;
    address constant LINK_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    
    uint32 constant callbackGasLimit = 300000;
    uint16 constant requestConfirmations = 3;
    uint32 constant numWords = 1;
    
    mapping(uint256 => address) public requestToPlayer;
    GameItems public gameItems;
    
    event LootRequested(uint256 indexed requestId, address indexed player);
    event LootDropped(address indexed player, uint256 itemId);
    
    constructor(address _gameItems)
        VRFV2WrapperConsumerBase(LINK_ADDRESS, WRAPPER_ADDRESS)
        Ownable(msg.sender)
    {
        gameItems = GameItems(_gameItems);
    }
    
    receive() external payable {}
    
    function requestLoot() external payable {
        require(msg.value >= 0.001 ether, "Need 0.001 ETH");
        
        uint256 requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        
        requestToPlayer[requestId] = msg.sender;
        emit LootRequested(requestId, msg.sender);
    }
    
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        address player = requestToPlayer[requestId];
        if (player == address(0)) return;
        
        uint256 random = randomWords[0];
        uint256 totalItems = gameItems.nextItemId();
        if (totalItems == 0) return;
        
        uint256 itemId = random % totalItems;
        gameItems.mintItem(player, itemId, 1);
        emit LootDropped(player, itemId);
    }
    
    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(LINK_ADDRESS);
        uint256 balance = link.balanceOf(address(this));
        if (balance > 0) {
            link.transfer(msg.sender, balance);
        }
    }
}
