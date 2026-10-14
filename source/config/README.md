# Game settings

Everything in this folder is plain JSON the game reads when it starts. Edit a
file, rebuild with `pdc source Roguelike.pdx`, and the change is in: no Lua
to touch, no other script to run. A key starting with `_` is ignored, so you
can leave yourself notes (`"_note": "trying fewer camps"`).

After editing `story.json` or `places.json`, run `lua tools/story_check.lua`
(and `tools/sim/run.sh` for the full set): it checks every seed can still be
finished. A file that isn't valid JSON stops the game at startup with
"can't read config/<name>.json".

| File | What it controls |
|---|---|
| `settings.json` | Hearts, walking speed, effect speed, combat timings, how enemies move, fixed seeds for testing |
| `story.json` | The four acts: which places each rolls, what its chests hold, enemies |
| `places.json` | Optional places, what each place gets (inside, stairs down or up, chest), how far levels spread, which lower levels connect |
| `items.json` | What each item does and what it says when you pick it up |
| `text.json` | Every line the game shows |
| `kits.json` | Which tiles everything uses (made with the Kit Builder) |

## settings.json

- `maxHearts`: hearts you start with.
- `walkRepeatDelay`, `walkRepeatEvery`: frames you hold the d-pad before
  walking repeats, then frames between steps (30 frames = 1 second).
- `effectFrameTime`: frames each tile of an effect (hit, hurt...) shows.
- `swingFrames`: frames the sword stays out after Ⓐ.
- `guardFrames`: frames the shield stays up after Ⓑ.
- `hurtFrames`: frames you blink after a hit, when you can't be hurt again.
- `enemyChaseRange`: enemies closer than this many tiles (counted along
  the grid) walk toward you; farther ones wander.
- `enemyChaseFrames`, `enemyWanderFrames`: frames between an enemy's steps
  when chasing and when wandering (plus a random 0-6). Lower is faster.
- `enemyIdleChance`: how often (0 to 1) a wandering enemy stands still
  instead of stepping.
- `enemyStunFrames`: frames an enemy stands stunned after a push or a hit.
- How many shield pushes defeat an enemy is in `items.json`
  (`shield.pushesToDefeat`).
- `difficulty`: the difficulty a new player starts on (`"normal"`); the
  title screen's Settings changes it, and the choice is saved.
- `difficulties`: the list Settings steps through, in order. Each has an
  `id`, a `name` (shown on screen), and any settings it changes: the keys
  above (`maxHearts`, `enemyChaseFrames`...) and `pushesToDefeat`. What it
  leaves out stays as written above, so `{"id": "normal", "name":
  "Normal"}` plays the file as is.
- `seeds`: build every area of a kind from one seed, to test one design
  everywhere, e.g. `{"cave": 42, "house": 7}`. Kinds: town, ruinedTown,
  church, cemetery, forest, creepyForest, mountain, ruins, camp, entrance,
  dungeon; insides and lower levels: house, ruinedHouse, chapel, crypt,
  cave, cellar; upper levels: ridge, tower.

## story.json

- `acts`: four rows, Act I to IV.
  - `name`: the banner when you first walk into the act's region.
  - `kinds`: `[kind, weight]` pairs rolled for the act's areas (Act IV is
    always the entrance and dungeon). A place missing from this world (see
    `places.json` `optional`) is skipped.
  - `camps`: at most this many camps in the act.
  - `chests`: what the act's chests hold, placed in order, one area each.
    `at`: `"home"` (the start house), `"entrance"` (Act IV's entrance),
    `"farthest"` (farthest from where you come into the region), `"any"`
    (a random area without a chest), `"rest"` (every area left).
- `enemies`: per kind of area, `min` to `max` enemies (each extra one with
  `chance`). Insides, lower and upper levels (ruinedHouse, crypt, cave,
  cellar, ridge, tower) have their own rows.
- `firstAct`: at most this many enemies per area in Act I.
- `alone`: an area whose chest holds one of these items has one enemy at most.

## places.json

- `optional`: the chance each of these places is in a world at all.
- `features`: per kind of place:
  - `inside`: the room behind its building's door (house, ruinedHouse, chapel).
  - `insideChance`: how often you can go in (a ruined house that can't is
    fallen in).
  - `below`: stairs down to a lower level: `kind` (crypt, cave, cellar),
    `chance`, `from` (`"outside"` or `"inside"` the building), `cover`
    (`"grave"` or `"rubble"`: pushed aside; `"web"`: torn, a cave mouth in
    the area's edge; `"mouth"`: an open cave mouth in the edge; none:
    stairs in plain sight).
  - `above`: stairs up to an upper level (never locked): `kind` (ridge,
    tower), `chance`. Never over Act IV's entrance or the captive's room.
  - `spread` and `over` (in `below` or `above`): the level can grow over
    up to `spread` more cells of the same act, joined to it in the piece,
    of the kinds in `over` (each extra cell has a 60% chance). Those cells
    have no stairs of their own: you walk in through passages, so the
    level takes part of the act's tetromino shape.
  - `chest`: where the area's chest goes: `"inside"`, `"below"`, `"deepest"`
    (below if it has stairs, else inside), or `"highest"` (up top if it
    has stairs up, else in the open). Leave it out for the open area. A
    chest only goes into a level the area has its own stairs or door to.
    Keys can end up inside, below or up top this way: every way there is
    open (covers are pushed aside, stairs up are never locked), so a key is
    never behind the lock it opens.
  - `chestChance`: how often the chest follows `chest` (default 1); the
    rest stay in the open.
- `hiddenPassages`: the chance a passage between lower levels is blocked by
  a web (between caves) or rubble that you push away.
- `connections`: which places' lower levels join when two neighbors in the
  same act both got stairs down: `{"between": ["church", "cemetery"]}`, with
  an optional `"chance"`. Remove a line and that pair never connects.

## items.json

- `slots`: items the HUD always has a slot for (the shield and the
  weapon): an empty frame until you find them, then the world's own tile.
- `order`: the order the HUD shows other carried items in.
- Per item: `ability` (`"swing"` on Ⓐ or `"guard"` on Ⓑ), `consumed`
  (keys), `heart` (one more heart, all refilled), `quiet` (a toast instead
  of a dialogue), `lines` / `toast`: the key in `text.json` of what it says.
- `pushesToDefeat` (shield): how many shield pushes on one enemy defeat it
  (5). The shield itself never wears out.
  Every push counts, whether the enemy was moved or not: raising the
  shield into it, or blocking its attack. An enemy with no room behind it
  is pushed to a side instead.

Adding a brand new item also needs a tile slot in the Kit Builder and a
place in `story.json` chests.

## text.json

Every line of dialogue and every toast. A list is shown one line at a time
(Ⓐ moves on); `%s` in the hint lines is filled in with a place. Ⓐ and Ⓑ are
the Playdate font's button glyphs.
`title` holds the title screen's words (menu, headings, hints); `mapLayers`
the layer names on the map.

## kits.json

The tiles for every place, object, item and character, and which decoration
tiles block the way (`walls`). Make it with the Kit Builder artifact; Claude
copies it here. `python3 tools/build_kits.py` is only needed if the tile
sheet image changes (it also checks every tile here exists).

## Still in Lua

The object rules (what a chest, gate, secret or NPC does when you use it
with Ⓐ, hit it with the sword or shield, or walk into it) are in `data/objects.lua`, since they're closer to code.
