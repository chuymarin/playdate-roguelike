# The Rulebook

How a world is built and how it plays: what the hero finds, what blocks
the way, and the rules everything in the world follows. It's written
like a tabletop rulebook: chapters, numbered rules and tables. When the
game and this book disagree, one of them has a bug.

Rules marked **(v1)** are what the first build of the act system does.
Rules marked **(later)** are planned, and the rule shapes in Chapter 5 are
already designed to hold them.

---

## Chapter 1: The Tale

Every world tells one short story:

> **You are a hero. You need to achieve something.**

What that something is, who stands in the way and what you have to find
are rolled from the world's **seed**. The same seed always tells the same
story on the same map. A different seed gives a different one.

A story has **four acts**. Each act opens a new part of the world, and
the last act ends the story.

| Act | Working name | What happens |
|---|---|---|
| I | Awakening | You wake up at home with nothing. Find a way out of the home region. |
| II | The Road | The world opens up. Arm yourself. |
| III | The Trial | The last stretch before the end. |
| IV | The Dungeon | Enter the dungeon and reach the goal. |

**(v1)** The goal is always the same: someone is locked in a cell deep in
the dungeon. Free them to win. **(later)** The goal is rolled from a goal
table (rescue, fetch an item, defeat a boss), and its tags filter the
rolls that come after it.

---

## Chapter 2: The World

### 2.1 Areas
**Rule 2.1.1.** The world is a **4×4 map** of 16 **areas**. Every cell of
the map holds one area; none are blank.

**Rule 2.1.2.** An area is one screen: 12×7 tiles of 32 px. On the map
screen each area is drawn as a rectangle with the screen's proportions
(100×60 px at 8 px per tile).

**Rule 2.1.3.** Two neighboring areas are either **linked** (a doorway in
the middle of the shared side) or separated by wall.

### 2.2 Pieces
**Rule 2.2.1.** The map is cut into **four pieces** of four areas each,
shaped like the tetrominoes of falling-block games. Each piece belongs to
one act and is that act's **region**.

**Rule 2.2.2.** The pieces:

```
 I               O         T            L          J          S          Z
 [][][][]        [][]      [][][]       []           []         [][]     [][]
                 [][]        []         []           []       [][]         [][]
                                        [][]       [][]
```

Every rotation and mirror is allowed.

**Rule 2.2.3.** There are **117** ways to cut the 4×4 map into four pieces.
The seed picks one. T pieces always come in pairs (two or four per map):
a single T leaves space that can't be split into the other shapes.

An example cut, with each cell labeled by shape and act:

```
I1 I1 I1 I1
T2 J3 J3 J3
T2 T2 T4 J3
T2 T4 T4 T4
```

### 2.3 Links inside a piece
**Rule 2.3.1.** All the areas of a piece are linked so that the whole
piece can be walked:

| Piece | Links |
|---|---|
| I, L, J, S, Z | A single path from one end to the other. |
| T | The three arms join at the middle cell. |
| O | A **loop** (all 4 links) or a **U** (3 links), rolled by the seed. |

**Rule 2.3.2.** Neighboring areas in **different** pieces are never linked,
except through a gate (2.4).

### 2.4 Gates
**Rule 2.4.1.** The acts are put in order so that each act's piece touches
the next one: I touches II, II touches III, III touches IV. Every one of
the 117 cuts can be ordered this way.

**Rule 2.4.2.** Between each act and the next, one shared side is a
**gate**. Gates are the only way into a new region.

**Rule 2.4.3.** A region you have opened stays open. In Act III you can
walk anywhere in Acts I, II and III, but not into IV.

**Rule 2.4.4. (v1)** Every gate is a locked door, opened with a **key**. The
key is used up. **(later)** Gates are rolled from a gate table: fire that
needs the shield, thorns that need the sword, a boulder that needs a bomb.

### 2.5 Kinds of area
**Rule 2.5.1.** Each area has a **kind**, which decides how it is built:

| Kind | What it is |
|---|---|
| town | Grass, paths and one house you can enter. |
| house | The inside of a town's house. Not a map cell of its own. |
| forest | A maze of trees. |
| ruins | A maze of broken walls. |
| camp | A safe clearing. See Rule 4.3. |
| dungeon | Stone rooms with tougher enemies. |

**Rule 2.5.2.** Act I's piece holds the **start**: a town whose house is
your home.

**Rule 2.5.3.** Act IV's piece is **1 entrance + 3 dungeon rooms**:
- The **entrance** is an outdoor area: the outside of the dungeon. It is
  always an **end** of the piece (the tip of an I or L, the stem of a T,
  any corner of an O), so the three rooms behind it stay connected.
- Act III's gate leads into the entrance.
- The **dungeon door** is a locked door between the entrance and the first
  dungeon room.

**Rule 2.5.4.** Other areas get their kinds rolled per act (Appendix A).

---

## Chapter 3: Things

### 3.1 Items
**Rule 3.1.1.** The hero carries **items**: `items[id] = count`. Every
item is one row of the item table:

| Item | Effect | Used up |
|---|---|---|
| shield | **Ability**: Ⓑ raises it. It pushes an enemy back one tile. | no |
| sword | **Ability**: Ⓐ swings it at the tile in front of you. | no |
| key | Opens one gate or locked door. | yes |
| cell key | Opens the captive's cell. | yes |
| heart | One more heart to hold, and refills them all. | (taken at once) |
| coin | Dropped by enemies. **(v1)** Only counted; what coins buy comes later. | — |

**Rule 3.1.2.** An **ability item** changes what a button does. Any other
item only matters to conditions (Chapter 5).

**Rule 3.1.3. (v1)** The **shield** is found in Act I and the **sword** in Act II.
Act I is played with the shield only: push enemies away, don't fight them.
New items and new ways to use them come in later updates.

### 3.2 Objects
**Rule 3.2.1.** Everything you can interact with is an **object**. An object
has a **kind**, a **status**, and **rules** (Chapter 5).

**Rule 3.2.2.** Each kind has a fixed set of statuses:

| Kind | Statuses | How you interact |
|---|---|---|
| chest | `closed` → `open` | Face it and press Ⓐ. |
| gate | `blocked` → `open` | Walk into it. |
| cell | `locked` → `open` | Walk into it. |
| npc | `waiting` → `done` | Face them and press Ⓐ. |
| enemy | `alive` → `defeated` | Fight it. |

**Rule 3.2.3.** Statuses are kept by the world. An open chest stays open
and an open gate stays open. Ordinary enemies come back every time you
enter an area, but an enemy that carries loot stays defeated (Rule 5.4.3).

### 3.3 Items on the ground
**Rule 3.3.1.** An opened chest disappears and leaves its item on its tile.
Walk onto an item to pick it up. A dropped item stays where it fell until
you take it.

---

## Chapter 4: Playing

### 4.1 Controls
| Button | Does |
|---|---|
| D-pad | Move one tile; hold to keep walking. |
| Ⓐ | Open the chest or talk to the NPC in front of you. Otherwise swing the sword, once you have it. |
| Ⓑ | Raise the shield, once you have it. |
| Menu → map | The areas you've visited. |
| Menu → new world | Start over with a new seed. |

### 4.2 Hearts and fainting
**Rule 4.2.1.** You start with **3 hearts**. An enemy that touches you takes
one, and you blink for a moment; you can't be hurt again while you blink.

**Rule 4.2.2.** At 0 hearts you **faint** and wake up at your last rest spot
with full hearts. You keep everything you carry.

### 4.3 Camps
**Rule 4.3.1.** A camp never has enemies. Walking in refills your hearts
and makes it your rest spot.

### 4.4 Enemies
**Rule 4.4.1.** Outdoor enemies take 1 hit, dungeon enemies take 2. A hit
pushes an enemy back a tile and stuns it for a moment.

**Rule 4.4.2. (v1)** All enemies of an area look alike; nothing marks one as
special. Every defeated enemy **drops a coin** on its tile. Enemies come back
when you re-enter an area, so coins can be farmed. That's fine until coins buy something.

### 4.5 Winning
**Rule 4.5.1. (v1)** Open the captive's cell and talk to them. The story ends,
and Ⓐ starts a new world.

---

## Chapter 5: The Laws of Interaction

Every object works by the same law: **when something happens, if the
conditions hold, then the effects happen.** No object has special code;
they differ only in their rules.

### 5.1 The shape of a rule
```lua
{ on        = "use",                                   -- trigger
  when      = { has = { "key" } },                     -- conditions
  does      = { take = "key", status = "open", drop = "shield" },  -- effects
  otherwise = { say = { "It's locked." } } }           -- if the conditions fail
```

### 5.2 Triggers
| Trigger | When |
|---|---|
| `use` | You face the object and press Ⓐ. |
| `bump` | You walk into the object. |
| `defeat` | The object (an enemy) drops to 0 hit points. |
| `enter` | You walk into the object's area. |

### 5.3 Conditions
**Rule 5.3.1.** All the conditions in `when` must hold (AND). An empty
`when` always holds.

| Condition | Holds when |
|---|---|
| `has = { "key" }` | You carry every listed item. |
| `has = { gem = 3 }` **(later)** | You carry at least that many. |
| `status = { chest4 = "open" }` **(later)** | That object has that status. |
| `any = { ... }` **(later)** | At least one of the listed conditions holds (OR). |

**Rule 5.3.2.** Conditions are not ordered. If a gate needs the key *and*
the lamp, you may find them in either order.

### 5.4 Effects
**Rule 5.4.1.** The effects in `does` happen in the order listed:

| Effect | Does |
|---|---|
| `give = "x"` | Puts item x in your items. |
| `take = "x"` | Removes one x from your items. |
| `drop = "x"` | Puts item x on the ground at the object's tile. |
| `status = "s"` | Changes this object's status. |
| `say = { ... }` | Shows lines in the dialogue box. |
| `win = true` | Ends the story. |

**Rule 5.4.2.** When the conditions fail, `otherwise` happens instead. It
should usually say what's missing, as a hint.

**Rule 5.4.3. (later)** A **loot carrier** is one enemy in a region with a
`defeat` rule that drops an item. It stays defeated once beaten (Rule 3.2.3).

### 5.5 The v1 rules, written out
```lua
chest   = { status = "closed",
            rules = { { on = "use", does = { status = "open", drop = "{item}" } } } }

gate    = { status = "blocked",
            rules = { { on = "bump", when = { has = { "key" } },
                        does = { take = "key", status = "open" },
                        otherwise = { say = { "The door is locked." } } } } }

cell    = { status = "locked",
            rules = { { on = "bump", when = { has = { "cellKey" } },
                        does = { take = "cellKey", status = "open" },
                        otherwise = { say = { "Help! The guards keep the key in a chest." } } } } }

enemy   = { kind = "enemy", status = "alive",
            rules = { { on = "defeat", does = { status = "defeated", drop = "coin" } } } }

captive = { kind = "npc", status = "waiting",
            rules = { { on = "use", does = { say = { "You got me out!" }, win = true } } } }
```

### 5.6 Planned rules (later)
```lua
-- a locked chest: Dad has the key
homeChest = { status = "closed",
  rules = { { on = "use", when = { has = { "key" } },
              does = { take = "key", status = "open", drop = "shield" },
              otherwise = { say = { "Locked. Dad had the key..." } } } } }

-- a trade
fisher = { kind = "npc", status = "waiting",
  rules = { { on = "use", when = { has = { "rod" } },
              does = { take = "rod", give = "fish", status = "done", say = { "A rod! Take this fish." } },
              otherwise = { say = { "If only I had a fishing rod..." } } } } }

-- a loot carrier
brute = { kind = "enemy", status = "alive", carrier = true,
  rules = { { on = "defeat", does = { status = "defeated", drop = "bomb" } } } }
```

---

## Chapter 6: Building a World (for the Game Master)

The game rolls a world in this order. Every roll comes from the world
seed, so the same seed always gives the same world.

1. **Cut the map.** Roll one of the 117 cuts (Rule 2.2.3).
2. **Order the acts.** Roll an order where each piece touches the next
   (Rule 2.4.1).
3. **Link the pieces.** Inside each piece, link the areas (Rule 2.3.1).
   For an O, roll loop or U.
4. **Place the gates.** For each pair of acts, roll one shared side to be
   the gate (Rule 2.4.2).
5. **Pick the kinds.** The start town in Act I, the entrance and dungeon
   rooms in Act IV, and the rest from Appendix A.
6. **Fill the objects.** Give each area its chests, NPCs and gates (Appendix B).
7. **Check.** Every condition must be satisfiable from items placed in the
   same act or an earlier one. (By construction this always holds in v1. A
   check tool rolls thousands of seeds to make sure.)

**Rule 6.1. (Solvable by construction.)** An item a condition needs is
always placed in the same act's region as that condition, or in an
earlier one. Since everything inside a region can be walked, every world
can be won.

**Rule 6.2. (Each area builds alone.)** Each area builds from its own seed,
derived from the world seed and its cell, so building one area never
changes another, whatever order you visit them in.

**Rule 6.3. (The Room Scale Lab.)** The lab artifact runs the same map
algorithm with the same random numbers, so a seed shows the same map in
the lab and in the game.

---

## Appendix A: Kind tables (v1)

| Act | Areas | Kinds |
|---|---|---|
| I | 4 | the start town, then 3 rolled: forest, ruins, camp, town |
| II | 4 | rolled: forest, ruins, camp, town |
| III | 4 | rolled: forest, ruins, camp |
| IV | 4 | 1 entrance (outdoor), 3 dungeon rooms |

Each of Acts I–III has at most one camp.

## Appendix B: Object tables (v1)

**Rule B.1.** Every area holds **one chest** that opens without a condition.
The start town's chest is inside your home. Act IV's deepest room holds
the captive's cell instead.

| Act | Chest contents |
|---|---|
| I | home chest: **shield**; one chest: **gate key**; the rest: heart |
| II | one chest: **sword**; one chest: **gate key**; the rest: heart |
| III | one chest: **gate key**; the rest: heart |
| IV | entrance: **dungeon key**; one dungeon room: **cell key**; deepest room: the **captive's cell** (no chest); the rest: heart |

**Rule B.2.** The key chest is the area farthest from where you entered the
region, so each key is a little walk away.

**Rule B.3.** Villagers in town houses give hints about where the act's key
and the sword are.

## Appendix C: Glossary

| Term | Meaning |
|---|---|
| **Act** | One chapter of the story. Owns one region. Ends at a gate (Act IV ends at the goal). |
| **Area** | One screen of the world: one cell of the 4×4 map. |
| **Condition** | Something that must hold before an effect happens. Usually "you carry item X". |
| **Effect** | What a rule does: give, take, drop, change status, say, win. |
| **Gate** | The one passage between an act's region and the next. Blocked until its condition holds. |
| **Goal** | How the story ends. |
| **Coin** | What every defeated enemy drops (v1). Counted, not yet spent. |
| **Item** | Anything the hero carries. Ability items change what a button does. |
| **Loot carrier** | An enemy that drops an item the story needs. |
| **Object** | Anything you interact with: chest, gate, cell, NPC, enemy. Has a status and rules. |
| **Piece** | One of the four tetromino shapes the map is cut into. |
| **Region** | The areas of one act: one piece. |
| **Required / optional** | An object is required if it's on the way to the act's gate, otherwise optional (hearts, side trades). |
| **Rule** | Trigger → conditions → effects (and `otherwise`). |
| **Seed** | The number that fixes every roll. |
| **Status** | Where an object is in its life: closed / open, alive / defeated... |
| **Table** | A list of weighted entries; one roll picks one entry. |
| **Trigger** | What starts a rule: use, bump, defeat, enter. |

## Appendix D: Open questions

Settled for v1:
- Shield in Act I, sword in Act II (Rule 3.1.3).
- Enemies all look the same and drop coins (Rule 4.4.2). Loot carriers come later.

Still open:
- What coins buy (a shop, a trade, a toll gate?).
- Flags ("talked to the mayor") or items only? Items only is simpler: a
  beaten boss can drop a crown.
- Act names are working titles.
