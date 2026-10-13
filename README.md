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

Work toward this is tracked in the repo's GitHub issues.

## How the current build plays

The code doesn't have the act system yet. Today a run goes like this:

1. You start at home. The chest there holds a **shield** (Ⓑ: block; pushes an enemy back one tile).
2. Out in the world, maze areas hide closed chests. Face one and press Ⓐ: the chest
   disappears and leaves its item, which you pick up by walking onto it. One holds the
   **sword** (Ⓐ: swing at the tile in front of you), one the **dungeon key**, any others
   a **heart container**.
3. Villagers in the other houses give hints about where things are.
4. Camps are safe: walking in refills your hearts and makes it your respawn point.
5. The key opens the dungeon's locked door. Inside, the NPC is locked in a barred cell in the
   deepest room; a chest in another dungeon room holds the **cell key**. Free them to win.

System menu: **map** (the areas you've visited, at 8px per tile) and **new world**.

## World generation (current build)

One world seed builds the map (`world/worldgen.lua`, the same algorithm and random
sequence as the Room Scale Lab artifact, so a seed shows the same map in both).
Each area then builds from its own seed derived from the world seed; set
`config.SEEDS.<kind>` to build every area of a kind from one fixed seed while testing.

- 4 blank cells, as separate spots of 1-3 cells
- dungeon: 4-6 areas, one locked entrance, the NPC in a locked cell in the deepest room,
  the cell key in the deepest other room
- town: 2-4 areas (near the start, or a far outpost), one enterable house each
- forest / ruins mazes at dead ends, with some walls knocked down for loops
- 1-2 camps; the area outside the dungeon door prefers to be one

## Repo structure

```
source/
  main.lua            imports every module once, runs the active scene
  config.lua          screen layout (12x7 rooms of 32px, 16px HUD), seed overrides
  core/               rng (seeded xorshift), grid helpers
  world/              worldgen (the 4x4 map), world (runtime state)
  areas/              layout (shared building blocks), one file per area kind, area (builder)
  entities/           player, enemy, npc, pickup (chests and items)
  ui/                 hud, dialogue
  scenes/             explore (gameplay), mapscreen
  tiles/              kits.lua (generated), tileset (image tables)
  data/text.lua       everything the game says
  audio.lua           sound effects
tools/
  kits.json           tile picks per area kind (edit in the Kit Builder artifact)
  build_kits.py       kits.json + 1-Bit Pack sheet -> 8/16/32px image tables + kits.lua
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
python3 tools/build_kits.py
python3 tools/build_sounds.py   # needs ffmpeg
lua tools/story_check.lua       # after editing data/story.lua or data/objects.lua
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
