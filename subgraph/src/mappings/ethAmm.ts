import { Swap as SwapEvent } from "../../generated/ETHAMM/ETHAMM";
import { Player, Swap } from "../../generated/schema";
import { BigInt } from "@graphprotocol/graph-ts";

export function handleSwap(event: SwapEvent): void {
  let player = Player.load(event.params.user.toHexString());
  if (player == null) {
    player = new Player(event.params.user.toHexString());
    player.address = event.params.user;
    player.ggtBalance = BigInt.fromI32(0);
    player.totalSwaps = BigInt.fromI32(0);
    player.totalLootBoxes = BigInt.fromI32(0);
    player.save();
  }
  
  player.totalSwaps = player.totalSwaps.plus(BigInt.fromI32(1));
  player.save();
  
  let swap = new Swap(event.transaction.hash.toHexString() + "-" + event.logIndex.toString());
  swap.trader = player.id;
  swap.amountIn = event.params.amountIn;
  swap.amountOut = event.params.amountOut;
  swap.timestamp = event.block.timestamp;
  swap.save();
}
