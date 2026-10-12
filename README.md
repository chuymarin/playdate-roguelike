# playdate-roguelike (working title)

A tiny Zelda-like for the Playdate. Every world is a random 4x4 map of 12 areas:
a town (your home is here), forest and ruins mazes, camps, and a locked dungeon
where someone is waiting for you.

## How a run goes

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

## World generation

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
assets/               vendored Kenney packs (CC0): 1-Bit Pack, sound effects
```

Playdate's `import` returns nil when a file is imported a second time, so modules
never import each other: `main.lua` imports everything once, in dependency order,
and each module adds itself to the global `Game` table.

## Build

```
python3 tools/build_kits.py
python3 tools/build_sounds.py   # needs ffmpeg
pdc source Roguelike.pdx
```

## Credits

Tiles: [1-Bit Pack](https://kenney.nl/assets/1-bit-pack) by Kenney (CC0).
Sounds: Kenney RPG Audio, Impact Sounds and Retro Sounds 2 (CC0).
