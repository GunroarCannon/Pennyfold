# Decision record: cities, economy, careers, touch (2026-11-14)

Status: accepted. For each choice: what was chosen, what was rejected, and when to revisit.

## 1. Data-driven economy and four cities

- **Chosen:** economic content lives in JSON (`data/economy.json` or equivalent, `careers.json`, `story.json`, `bestiary.json`), read once by plain GDScript classes. Cities are data entries; extra cities populate lazily when the player gets close.
- **Rejected:** custom `Resource` (.tres) definitions. They give Inspector editing, but nobody edits this data in the editor, and the project already uses JSON; diffs and hand edits are easier.
- **Revisit when:** there are more than ~8 cities, non-programmers edit content, cities should unload when far away, or saves are added (then `Career`, `Story` and wallets need serialisers).

## 2. Conservation of coins

- Coins are never created or destroyed in play. Wages come from the employer's wallet, guard bounties and quest rewards from treasuries/escrow, story rewards from a `crown` vault funded once at the start (520 coins), temple fees to the temple, knock-out fees to the nearest treasury, and a dead merchant's coins to the treasury.
- **Revisit when:** a faucet is wanted. It must be a visible, genesis-funded wallet so the ledger still balances.

## 3. NEAR settlement and the optional wallet

- **Chosen:** the relayer keeps owning all sub-accounts. The player's own wallet is optional: the title screen offers "Connect NEAR wallet" (web redirect login in `web/shell.html`, no library) or a typed `name.testnet` (desktop), or play as guest. `POST /link` validates the name (live mode also checks it exists). `POST /settle` carries `player_account`; flows paid to `player` go to that account.
- **Rejected:** wallet-selector / near-api-js (large bundle for a login redirect, bad for web size) and signing the player's spending with their own key (needs function-call keys and per-transaction approval; too much friction).
- **Assumptions:** testnet only. The redirect trusts the `account_id` query parameter, so it is a payout address, not authentication. If identity ever matters (leaderboards, mainnet prizes), switch to wallet-selector with a signed message. The redirect flow has not been tested live.

## 4. Careers, levels and jobs

- **Chosen:** `Career` is a `RefCounted` owned by `Main` (like `Quests`), numbers in `data/careers.json`. Shift presence is checked near the workplace; pay, raises, warnings and firing happen at 17:00.
- **Rejected:** an autoload (state is per run and should reset with the scene) and an ability-system Resource stack (overkill for one stat curve and one job).
- **Revisit when:** saves exist: add `to_dict()/from_dict()`.

## 5. Travelling merchants

- **Chosen:** `Merchant extends Npc`, its cart registered as an Economy shop with no city, routes from `Economy.best_trade`. The player trades with the cart like any shop.
- **Rejected:** a separate entity type; the NPC loop already provides views, bubbles, death and dialog.
- **Revisit when:** there are dozens of merchants: route along a pre-built road graph instead of whole-grid pathfinding. Merchant AI is lightly tested.

## 6. Touch controls

- **Chosen:** one custom `TouchControls` node owning every touch (stick, discs, menu, camera drag, pinch) and feeding the Input Map via `Input.action_press/release`, so `main.gd` input code is unchanged.
- **Rejected:** the built-in 4.7 `VirtualJoystick`: it covers only the stick, the other multi-touch routing would still be custom, and its API could not be checked without the editor.
- **Assumption:** verified by screenshots and code reading, not on a physical device.

## 7. Low-end (web and mobile) mode

- `Game.low_end` is on for web/mobile exports (or `--low-end`): smaller bakes without mipmaps, fewer townsfolk, clouds, particles and monsters, one 1024 px shadow split. Desktop measurement with `--low-end`: textures 398 MB to 172 MB.
- **Revisit when:** a real device still struggles: lower `scaling_3d/scale`, shorter draw distance.

## 8. Monster sprites

- **Chosen:** an offline pass (`tools/cardboardize.py`) turns the sprite pack into cut-paper beasts in `assets/beasts/`; unsuitable art is dropped and listed in `assets/beasts/MANIFEST.json`. `assets/monsters/` is excluded from exports.
- **Assumption:** the licence of the base sprite pack is not recorded in the repo. Confirm it before any commercial release. The CC BY-NC painted sheets are not used.
