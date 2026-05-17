// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameItems is ERC1155, Ownable {
    struct ItemInfo {
        string uri;
        uint256 maxSupply;
        uint256 currentSupply;
        bool exists;
    }

    mapping(uint256 => ItemInfo) public itemInfo;
    uint256 public nextItemId;

    event ItemCreated(uint256 indexed itemId, string uri, uint256 maxSupply);

    constructor() ERC1155("") Ownable(msg.sender) {}

    function createItem(string memory uri_, uint256 _maxSupply) external onlyOwner returns (uint256) {
        uint256 itemId = nextItemId++;
        itemInfo[itemId] = ItemInfo(uri_, _maxSupply, 0, true);
        emit ItemCreated(itemId, uri_, _maxSupply); // было _uri, исправьте на uri_
        return itemId;
    }

    function mintItem(address to, uint256 itemId, uint256 amount) external onlyOwner {
        require(itemInfo[itemId].exists, "Item does not exist");
        require(itemInfo[itemId].currentSupply + amount <= itemInfo[itemId].maxSupply, "Max supply reached");
        itemInfo[itemId].currentSupply += amount;
        _mint(to, itemId, amount, "");
    }

    function uri(uint256 itemId) public view override returns (string memory) {
        require(itemInfo[itemId].exists, "Item does not exist");
        return itemInfo[itemId].uri;
    }
}
