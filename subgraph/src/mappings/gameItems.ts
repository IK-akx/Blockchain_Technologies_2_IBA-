import { TransferSingle } from "../../generated/GameItems/GameItems";
import { Player, Item, PlayerItem } from "../../generated/schema";
import { BigInt, Bytes } from "@graphprotocol/graph-ts";

export function handleTransferSingle(event: TransferSingle): void {
  let to = event.params.to;
  let id = event.params.id;
  let value = event.params.value;
  
  if (to != Bytes.fromHexString("0x0000000000000000000000000000000000000000")) {
    let player = Player.load(to.toHexString());
    if (player == null) {
      player = new Player(to.toHexString());
      player.address = to;
      player.ggtBalance = BigInt.fromI32(0);
      player.totalSwaps = BigInt.fromI32(0);
      player.totalLootBoxes = BigInt.fromI32(0);
      player.save();
    }
    
    let inventoryId = to.toHexString() + "-" + id.toString();
    let playerItem = PlayerItem.load(inventoryId);
    if (playerItem == null) {
      playerItem = new PlayerItem(inventoryId);
      playerItem.player = player.id;
      
      let item = Item.load(id.toString());
      if (item == null) {
        item = new Item(id.toString());
        item.itemId = id;
        item.name = "Item";
        item.itemType = "Resource";
        item.totalSupply = BigInt.fromI32(0);
        item.save();
      }
      playerItem.item = item.id;
      playerItem.balance = BigInt.fromI32(0);
    }
    playerItem.balance = playerItem.balance.plus(value);
    playerItem.save();
  }
}