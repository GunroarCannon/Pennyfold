# Changelog

## Unreleased (2026-11-14)

### Mobile and web
- Touch controls: floating stick (edge sprints), cardboard action discs, menu column (map, quests, ledger, bestiary, help), camera drag and pinch zoom. Touch mode turns on for phones, mobile exports, `--touch`, or the first finger.
- Touch-friendly dialog, tutorial, help and title text; safe areas; stretch `expand`, sensor landscape.
- Low-end mode for web and mobile (smaller bakes, fewer extras).
- Web export with custom loader `web/shell.html` (kraft card, progress bar, tips).
- Title-screen wallet row: Connect NEAR wallet (web) or `name.testnet` (desktop), or play as guest. Relayer `POST /link`; account shown on the NEAR chip.

### Careers and feedback
- Levels and XP (kills, quests, trading profit, shifts), level bar, level-up banner and rip effect; HP, stamina and ink grow.
- Jobs: apply by talking, requirements, shifts, wages from the employer's real till, raises, warnings, firing and quitting. Grudges: a shop you assaulted will not trade for two days.
- Guards: hired by treasuries when danger is high, paid bounties; the player can take the job too.
- Knocked-out screen, gold floaters, running +/- beside the purse, rip effects on crits, blasts, boss kills, level-ups and deaths.

### World
- Story: the Penny Crown, four chapters, vault-funded rewards, journal, ending and New Game Plus.
- Daily events (festival, blight, fish run, collapse, caravan, raiders) with visible effects and gossip.
- "Why are prices like this?" and richer "any news" answers.
- Travelling merchants with real wallets and carts.
- Special buildings: price board at the exchange, healing at the temple.
- Map and minimap show all cities, roads and merchants.
- Bestiary (B), 15 sprite beasts including rare dragons, cardboard-izing pipeline (`tools/cardboardize.py`), `scenes/monster_test.tscn`.
- Panels pop in and drop away.

### Docs
- README, CREDITS, decision record `docs/decisions/2026-11-14-economy-cities.md`.
