# Pennyfold: how to check what we claim

Everything below can be checked by running something. If a claim here does not
hold when you run it, that is a bug in the claim, so please say so.

## What it is

A cardboard-paper fantasy RPG (Godot 4.7, desktop and web) where every coin is
a real, conserved balance. Shopkeepers, townsfolk, monsters, the town treasury,
the quest escrow and you each hold a wallet. Coins only ever move between
wallets (wages, trades, taxes, rewards, a bed at the inn, a blessing at the
shrine). Nothing is printed or deleted. The day's net flows are settled on NEAR
testnet through a small relayer, so the game never shows a wallet popup.

## Claims and how to verify them

| Claim | How to check |
|---|---|
| Coins are conserved | Run `godot --headless --path . -- --demo=career`, `--demo=story`, `--demo=guard`, `--demo=merchants`. Each prints PASS or a result line. Press Tab in game for the ledger. |
| Settlement logic nets flows correctly | `node server/selftest.mjs` (no wallet, no network needed). |
| Real testnet transfers | Start `node server/relayer.mjs` with a funded testnet key (see README, "Test it live on testnet"), play a day, press Esc then "Settle day now". The pause menu shows the transaction links, which open on NearBlocks. |
| It still plays with no chain | Start the game with no relayer. The HUD chip says "Offline: ledger kept on this device". |
| NPCs are autonomous | Stand still in a town for a few in-game days. Shopkeepers restock, people eat, work shifts, sweep doorways, forage and hunt, and merchants carry goods between towns. |

## What is not finished (so you do not have to find it)

- Single player. The simulation is local and authoritative. A shared world
  would need a server-side sim; the relayer and sub-account design would carry
  over to it, but it is not built.
- The wallet link on the web build is an optional payout address, not
  authentication, and has not been tested against a live wallet page.
- Town raids by wolves and bandits, and townsfolk who fight them for a reward,
  are designed but not in this build.
- Touch controls exist but have not been tried on a real device.
- The base sprite pack's licence is not recorded; see `CREDITS.md`.

## What is different about it

Most "game economy on chain" projects put an item or token on a chain and leave
the game loop untouched. Here the economy is the game loop: the town runs
whether or not you are there, prices come from stock and demand, and the chain
is the audit trail of money that already moved, not a toll booth in front of
playing.
