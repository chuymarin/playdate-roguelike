# playdate-roguelike (working title)

A tiny Zelda-like for the Playdate where every seed tells a different short
story. You are a hero, and you need to achieve something. The story comes
in **four acts**, and each act opens a new part of the world.

The full rules are in **[the Rulebook](https://app.notion.com/p/3f895764acd58115b348ce525d24aee4)**
(in Notion, with the rest of the project docs): how the world is built, what
every object does, and the tables the story is rolled from.

## The design in short

- The world is a **4x4 map** of 16 areas (one screen each), cut into four
  **tetromino pieces** (I, O, T, L/J, S/Z). There are 117 ways to cut it.
- Each piece is one **act's region**. Act I's piece is open from the start.
  A **gate** opens the next act's piece, and regions you've opened stay open.
- Inside a piece the areas are linked as a path, a T, or (for an O) a loop or a U.
- Act IV is 1 dungeon entrance plus 3 dungeon rooms, with the captive in the deepest one.
- Every area has a chest. In each act one chest holds the key to the next gate.
- Everything you interact with is an **object** with a status (`closed`/`open`...)
  and **rules**: *trigger → conditions → effects* (`on use, when has key: take key, open`).
  What you carry is `items[]`.

Work toward this is tracked in the repo's GitHub issues. The first version (v1) of
the act system is in the build: see below.

## How a run plays (v1)

1. You wake up at home in Act I's region. The chest there holds a **shield**
   (Ⓑ: pushes an enemy back one tile). In Act I you can only push enemies away.
2. Every area has a chest. Face one and press Ⓐ: the chest disappears and leaves its
   item, which you pick up by walking onto it. Each act's region hides the **key** to
   its gate (the chest farthest from where you came in); Act II also hides the
   **sword** (Ⓐ: swing at the tile in front of you). The rest hold **heart containers**.
3. Walk into a locked gate with a key to open it; the next act's title shows the first
   time you step into its region. Opened gates stay open.
4. Villagers in town houses tell you where their region's key and the sword are, and
   which way the gate is. Camps refill your hearts and become your respawn point.
   Defeated enemies drop **coins** (only counted for now).
5. Act IV: the entrance's chest holds the key to the dungeon door. Inside, the captive is
   locked in a barred cell in the deepest room; another room holds the **cell key**.
   Free them to win.

System menu: **map** (the areas you've visited at 8px per tile, with a line where
two acts' regions meet) and **new world**.

## World generation

One world seed builds the map (`world/worldgen.lua`, the same algorithm and random
sequence as the Room Scale Lab artifact, so a seed shows the same map in both): the
tiling, the act order, links inside each piece, the gates and each area's kind.
What each area holds is rolled from `config/story.json` and `config/places.json`
on sub-seeds (`world/story.lua`). Each area then builds from its own seed derived
from the world seed; set `seeds` in `config/settings.json` to build every area of a
kind from one fixed seed while testing.

## Settings

The game's settings are JSON files in `source/config/`, read at startup: hearts and
timing (`settings.json`), the acts and enemies (`story.json`), places, insides,
stairs and underground connections (`places.json`), items (`items.json`), every
line of text (`text.json`) and the tile picks (`kits.json`, from the Kit Builder).
Edit one and rebuild with `pdc`; `source/config/README.md` explains every field.

## Repo structure

```
source/
  main.lua            imports every module once, runs the active scene
  config.lua          screen layout (12x7 rooms of 32px, 16px HUD), loads config/*.json
  config/             the settings files (JSON, see config/README.md)
  core/               rng (seeded xorshift), grid helpers, rules (the rule engine)
  world/              worldgen (the 4x4 map), story (what each area holds),
                      objects (object instances and statuses), world (runtime state)
  areas/              layout (shared building blocks), one file per area kind, area (builder)
  entities/           player (and items[]), enemy, npc, pickup (items on the ground)
  ui/                 hud, dialogue
  scenes/             explore (gameplay), mapscreen
  tiles/              kits (reads config/kits.json), tileset (image tables)
  data/               loaders for config/ (text, items, story, places), and
                      objects (object templates and their rules)
  audio.lua           sound effects
tools/
  build_kits.py       1-Bit Pack sheet -> 8/16/32px image tables; checks config/kits.json
  json.lua            JSON reader for running the game outside the Playdate
  build_sounds.py     Kenney sounds -> Playdate WAVs
  story_check.lua     rolls thousands of worlds and checks each can be finished
  sim/                headless tests: a Playdate stand-in, a bot that plays a world, unit tests
assets/               vendored Kenney packs (CC0): 1-Bit Pack, sound effects
```

Playdate's `import` returns nil when a file is imported a second time, so modules
never import each other: `main.lua` imports everything once, in dependency order,
and each module adds itself to the global `Game` table.

## Build

```
python3 tools/build_kits.py     # only when the tile sheet changes
python3 tools/build_sounds.py   # needs ffmpeg
lua tools/story_check.lua       # after editing config/story.json, config/places.json or data/objects.lua
pdc source Roguelike.pdx
```

`tools/story_check.lua [count]` (plain Lua 5.4) rolls seeds 1..count (default 5000)
with the game's own code and checks the Rulebook: four pieces, one gate between
consecutive acts, the entrance at an end of Act IV, the shield and sword where they
belong, one chest per area, every object's placeholders filled, and that every world
can be finished. It prints stats and exits with status 1 on a failure.

`tools/sim/run.sh` runs the headless tests (the story check, unit tests, a stress test
that builds every area of 500 worlds, and a bot playing 30 worlds). The Playdate uses
32-bit numbers; `LUA=path/to/lua32 tools/sim/run.sh` runs them on a Lua built with
`LUA_32BITS` too.

## Credits

Tiles: [1-Bit Pack](https://kenney.nl/assets/1-bit-pack) by Kenney (CC0).
Sounds: Kenney RPG Audio, Impact Sounds and Retro Sounds 2 (CC0).
