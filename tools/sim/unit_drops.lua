-- Drops and remains: an opened chest keeps its open tile, blocks only when
-- drawn and drops its item on a free reachable cell next to it; a defeated
-- enemy leaves remains and its coin lands beside them; drops never stack.
--   lua unit_drops.lua <source>
SRC = arg[1]
stub = dofile("stub.lua")
stub.boot()
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. msg) end end
local e = stub.explore
local p, area, world = e.player, e.area, e.world
local objects, key = Game.objects, Game.layout.key

-- the home chest (the start area's house holds it)
local chest = objects.ofKind(area, "chest")[1]
check(chest ~= nil, "home has a chest")
local reach = Game.layout.reach(area, { { p.x, p.y } })
local function free(x, y) return Game.layout.inside(area, x, y) and not area.solid[y][x] and not e:objectAt(x, y) and not e:portalAt(x, y) end

-- open it from a free neighbor
local sx, sy, face
for _, d in ipairs(Game.grid.DIRS) do
  local x, y = chest.x - d[1], chest.y - d[2]
  if free(x, y) and reach[key(x, y)] then sx, sy, face = x, y, d[3]; break end
end
p.x, p.y = sx, sy; p:face(face)
e.dialogue = nil
e:pressA()
check(objects.status(world, chest) == "open", "chest opened")
check(#area.items == 1, "one item dropped")
local it = area.items[1]
check(not (it.x == chest.x and it.y == chest.y), "item not on the chest")
check(not (it.x == p.x and it.y == p.y), "item not under the player")
check(math.abs(it.x - chest.x) + math.abs(it.y - chest.y) <= 2, "item near the chest")
check(free(it.x, it.y), "item on a walkable cell")
local open = Game.kits.objects.chestOpen[1]
check(chest.tiles.open == open, "open tile from the kit")
check(objects.blocks(world, chest) == (open ~= nil), "open chest blocks only when drawn")
-- using it again drops nothing
e:pressA()
check(#area.items == 1, "an open chest drops nothing more")

-- an enemy dies: remains on its cell, coin beside them
local ex, ey
for y = 2, area.rows - 1 do
  for x = 2, area.cols - 1 do
    if not ex and free(x, y) and reach[key(x, y)] and not (x == p.x and y == p.y) and not (x == it.x and y == it.y) then ex, ey = x, y end
  end
end
check(ex ~= nil, "found a cell for the test enemy")
local enemy = Game.Enemy.new({ x = ex, y = ey, hp = 1, tile = 1 })
enemy.obj = objects.new("enemy", "enemy:test", ex, ey)
e.enemies = { enemy }
e:hitEnemy(enemy, 1)
local bones = Game.kits.objects.remains
if #bones > 0 then
  check(#e.remains == 1 and e.remains[1].x == ex and e.remains[1].y == ey, "remains where it fell")
end
check(#area.items == 2, "coin dropped")
local coin = area.items[2]
check(coin.item == "coin", "it's a coin")
check(not (coin.x == ex and coin.y == ey), "coin not on the remains")
check(not (coin.x == it.x and coin.y == it.y), "coin doesn't stack on the chest's item")
-- remains don't block
check(e:canEnter(ex, ey), "remains are walkable")
-- leaving clears them
e:enter(area.id, p.x, p.y, "S")
check(#e.remains == 0, "remains gone after re-entering")

if fails == 0 then print("unit_drops: all passed") else os.exit(1) end
