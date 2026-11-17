# Brainrot Bazaar

[![make.fun](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Kroco365/roblox-brainrot-game/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/Kroco365/roblox-brainrot-game/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

A 3D Roblox brainrot game for make.fun's [Make the best AI Roblox brainrot game](https://make.fun/bounty/roblox-brainrot-01) bounty (roblox-brainrot-01).

Steal the meme, stack the cash. Absurd characters ride the conveyor belt through the middle of the bazaar — click one to buy it, park it on your base, and watch it earn dollars every second. Rarer brainrots earn more: 11 original characters from Traffic Cone Carl (Common, $1/s) to The Almighty Printer (Secret, $1,000/s), with Golden, Diamond and Rainbow mutations worth up to 10x. Then the loop bites back: other players — and three bot rivals who play for real — can walk into your base and steal your best earner. Slap them to make them drop it, lock your base for 60 seconds when a Mythic lands, and rebirth for a permanent +50% income per rebirth. Every few minutes an event hits: a tsunami wave sweeps the map (get to the hill or your base), Brainrot Rain doubles spawns, or a Golden Hour doubles everyone's income.

- `main.ts` (Node 22, standard library only) hands the game in: it copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output`, leaving out every name that starts with a dot, and writes `/output/dossier.json` with `vendor/makefun-roblox.ts`, the kit's copy, unchanged.
- `game.rbxl` is the place Rojo builds from `src/` and `default.project.json`; `screenshots/` holds three renders of it; `PLAY.json` names the published place once the owner publishes it from Roblox Studio.
- `src/shared/BrainrotCatalog.luau` is the whole cast; `src/server/` holds one module per job (world, economy, bases, conveyor, stealing, events, rebirths, bot rivals) with all state in `GameState`; `src/client/Game.client.luau` builds the ScreenGui (cash bar, brainrot index, leaderboard, lock/rebirth/slap buttons, steal prompt).
- One of the screenshots is also the game's first thumbnail on Roblox: the same picture, uploaded on the Creator Dashboard with the game's icon.

Run it as the grader does, writing `out/` in place of `/output`:

    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

The rules are on the bounty's page (/bounty/roblox-brainrot-01) and in the kit's RULES.txt, which gives every command in order (Before you submit, then Enter).
