import { LootRequested } from "../../generated/LootDrop/LootDrop";
import { Player, LootRequest } from "../../generated/schema";
import { BigInt } from "@graphprotocol/graph-ts";

export function handleLootRequested(event: LootRequested): void {
  let player = Player.load(event.params.player.toHexString());
  if (player == null) {
    player = new Player(event.params.player.toHexString());
    player.address = event.params.player;
    player.ggtBalance = BigInt.fromI32(0);
    player.totalSwaps = BigInt.fromI32(0);
    player.totalLootBoxes = BigInt.fromI32(0);
    player.save();
  }
  
  let lootRequest = new LootRequest(event.params.requestId.toString());
  lootRequest.player = player.id;
  lootRequest.status = "Pending";
  lootRequest.requestedAt = event.block.timestamp;
  lootRequest.save();
}
