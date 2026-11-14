# Pennyfold

*A storybook world where every coin is real.*

An open-world cardboard RPG with a working economy. The world is a paper
diorama: flat cut-out townspeople and monsters, trees that fold up out of the
ground as you walk near them, houses with painted timber walls. You explore a
procedural valley, chop wood, fight beasts that get far more dangerous the
further you roam, take quests, and trade with shops and people.

Every coin belongs to a wallet (you, each person, each shop, the treasury, the
quest board). Coins are never created or destroyed. At the end of each game day
the town's money flows are settled on **NEAR testnet** as real transfers
between sub-accounts, through a small relayer. The player never sees a wallet,
a key or a popup, but can open the ledger (Tab) and follow the transactions to
NearBlocks.

Built with Godot 4.7 (GL Compatibility) for the NEAR hackathon, `games` track.
Runs on desktop and in the browser.

## Play

**Desktop.** Install Godot 4.7, then `Godot_v4.7-stable_win64.exe --path .`
(or open the folder in the editor and press Play).

**Web.** Export with the included "Web" preset, then serve it from the relayer
so the game and the chain bridge share one origin (no CORS, no config):

```
godot --headless --path . --export-release "Web" build/web/index.html
node server/relayer.mjs          # then open http://127.0.0.1:8787/
```

The relayer serves `build/web` (override with `WEB_DIR`), sends the
cross-origin-isolation headers, and listens on `PORT` (default 8787) and `HOST`
(default 127.0.0.1; use `HOST=0.0.0.0` to share on a network). In the browser
the game talks to the page's own origin, or to `?relayer=https://host` if you
add that to the URL. Web requests use the browser `fetch`, so it works under
slow software rendering too. The export is single-threaded and does not need
special hosting headers.

The title card has Play and an art-style toggle: **Cute** (chibi people,
pastel monsters) or **Real** (plain-faced people, dark monsters). The first
Play runs a short tutorial (skippable, remembered).

### Controls

| Key | Action |
| --- | --- |
| WASD | Walk (relative to the camera) |
| Shift | Sprint (uses stamina) |
| Left click / J | Strike. Chain three for a combo; the third hits hardest |
| X / Ctrl | Dodge roll. Dodging through an attack is a **Perfect Dodge** (slow-mo, stamina and ink back) |
| K / R | Ink beam (30 ink) |
| E | Talk, trade, gather, read the board |
| Strike at a tree | Chop it for wood (sell it at the general store) |
| Space | Jump |
| Q / C, right-drag | Turn the camera |
| Mouse wheel | Zoom |
| M | Map (click a discovered place to fast travel) |
| L | Quest log |
| Tab | Town ledger and NEAR log |

## What is in the world

- **Open valley** with mountain rims, a lake, a mine, a lookout and winding
  roads. Six landmarks (farm, mine, lake dock, ruins, deep wood, lookout) show
  a banner when discovered and unlock fast travel.
- **Danger zones.** Beasts come in three tiers: normal, **Fierce** and **Dire**.
  Tougher tiers are bigger, faster, hit harder, chase further and glow red.
  Wolves hunt in packs and wolves, bats, trolls and slimes pounce or charge
  with a wind-up. The Mine and the Ruins hold Dire beasts. It is no longer easy
  to outrun them: you have limited sprint stamina and a dodge roll instead.
- **Combat.** Three-hit combo with aim assist and a target ring, a finisher
  slam, 15 percent crits, hit-stop and stagger, i-frames while rolling.
- **Town.** Shops (bakery, tavern, market, lodge, smithy, general store, guard
  post), houses, lamps and a quest board. Walls fade gently when you walk
  behind them.
- **People** eat, work, get paid, drink, sleep, gossip, flee monsters and die.
  Talking zooms the camera in and the words appear in a speech bubble over the
  speaker. They queue sensibly at doors instead of jamming.
- **Quests**: gather, hunt, visit and deliver, paid from an escrow wallet.
- **UI**: a hero medallion with HP, stamina and ink gauges, a round rotating
  minimap, a NEAR status chip (click it for the ledger), a combo counter, and a
  map with fog of war.

## How the economy works

- `scripts/economy.gd`: wallets for the player, every person, every shop, the
  town treasury and the quest escrow. Each trade, wage, tax and bounty moves
  coins between wallets and emits `transferred`.
- Production: the bakery bakes, the lodge hunts, the tavern brews ale from
  bread, the smithy forges blades from ore. Shops buy inputs from each other.
  The general store buys wood.
- Prices rise when stock is low and fall when it is high.
- The treasury collects an evening tax, inherits the coins of the dead, pays
  guard bounties and funds newcomers.

## NEAR integration and how to test it

```
Economy.transferred --> Chain (autoload) --> end of day: net flows per wallet pair
                                               |
                                    POST /settle {day, flows, ledger}
                                               v
                               server/relayer.mjs --> NEAR testnet
                     one sub-account per wallet: player.<root>, bakery-0.<root>, ...
```

- `scripts/chain.gd` records every transfer, nets them per pair of wallets at
  midnight and sends the day to the relayer. The top-bar chip shows the state
  ("NEAR dry run - 4 queued", "NEAR testnet - day 3 settled", "local only").
  The ledger (Tab) has **Settle day now (NEAR)**, **Last transaction** and
  **Open NearBlocks** buttons.
- `server/relayer.mjs` has no dependencies (Node 18+). It builds, signs and
  sends NEAR transactions itself (borsh, ed25519, JSON-RPC). Sub-account keys
  are derived from the root key and the wallet id. 1 coin = 0.0001 NEAR.
- The game never blocks on the chain. If the relayer is down the chip says
  "local only" and the game keeps retrying and keeps its own ledger.

### Test it (no wallet needed)

```
cd server
node relayer.mjs              # dry run: signs nothing, logs what it would send
npm run selftest              # in another shell: health, status, genesis, settle checks
```

End to end with the game, headless: sells wheat, settles, prints
`NEAR TEST ...` lines and quits.

```
Godot_v4.7-stable_win64_console.exe --headless --path . -- --demo=near
```

### Test it live on testnet

Copy `server/.env.example` to `server/.env`, fill in a testnet account you
control and its private key, then `node server/relayer.mjs --live`. Play a day
(or press **Settle day now**) and open the ledger's NearBlocks link. The relayer
refuses to run on mainnet. `server/.env` and `server/state.json` are ignored by
git.

Point the game at another relayer with `--relayer=URL` after `--`, the
`FOLDED_RELAYER` environment variable, or `?relayer=` on the web.

## Debug arguments

After `--`: `--seed=42`, `--hour=21`, `--style=cute|real`,
`--at=farm|mine|lake|ruins|wood|lookout`,
`--demo=fight|dire|chop|near|beam|talk|shop|map|faces`, `--title` (force the
title card), `--tutorial` (force the tutorial), `--weather=rain`, `--report=1`
(print the ledger each day), `--shot=path.png --frames=N` (screenshot, quit).

## Code map

- `scripts/main.gd`: world assembly, camera, day and night, weather, the
  simulation loop, combat, dialogue, landmarks, fast travel.
- `scripts/world.gd`, `town_gen.gd`: heightmap, roads, props, town layout.
- `scripts/npc.gd`, `monster.gd`: townspeople and monsters (tiers, packs,
  pounce, beams).
- `scripts/economy.gd`, `quests.gd`, `chain.gd`: money, escrow, NEAR.
- `scripts/paint*.gd`, `cutout.gd`, `bake.gd`: every texture is painted in code
  at start-up.
- `scripts/standee.gd`, `speech_bubble.gd`: puppet characters, bubbles, HP bars.
- `scripts/fx.gd`, `shaders/`: effects (slashes, beams, decals), terrain,
  props, bubble and bar shaders.
- `scripts/hud.gd`, `tutorial.gd`, `card_box.gd`: UI.
- `server/`: relayer and its self-test.

## Reused assets

No third-party code. Some art and sound come from the author's earlier
projects; see CREDITS.md for exactly what and under which licences.

## License

MIT, see LICENSE. Assets keep their own licences (CREDITS.md).
