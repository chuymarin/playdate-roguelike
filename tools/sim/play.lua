-- A bot plays a whole world through the Playdate stand-in: the home chest,
-- each act's key (and the sword in Act II), every gate, the dungeon door, the
-- cell key and the captive.
--   lua play.lua <source> <seed> [snapshot dir or -] [v] [god]
-- v prints the route; god turns enemies off (checks progression, not fighting).
SRC = arg[1]
local SEED = tonumber(arg[2] or 7)
local OUT = arg[3] ~= "-" and arg[3] or nil
local VERBOSE = arg[4] == "v"
local GOD = arg[5] == "god" -- the hero can't be hurt: checks progression, not fighting skill
stub = dofile("stub.lua")
stub.boot()
local keyPickups = 0
local give = Game.Player.give
Game.Player.give = function(self, id) if id == "key" then keyPickups = keyPickups + 1 end return give(self, id) end
if GOD then
  Game.Player.hurt = function() return false end
  local enter = Game.Explore.enter
  Game.Explore.enter = function(self, ...) enter(self, ...); self.enemies = {} end
end
Game.newWorld(SEED)
local layout, grid, pickup = Game.layout, Game.grid, Game.pickup
local E = function() return stub.explore end
local frames, shots, log = 0, {}, {}
local function say(...) if VERBOSE then print(...) end end

local function frame(b, held) stub.frame(b, held); frames = frames + 1; if frames > 200000 then error("too many frames") end end
local function idle(n) for _ = 1, n or 1 do frame() end end
local function shot(name) if OUT then local p = OUT .. "/" .. #shots + 1 .. "_" .. name .. ".log"; stub.snapshot(p); shots[#shots + 1] = p end end
local function dismiss()
  local n = 0
  while E().dialogue do
    say("  says: " .. E().dialogue.lines[E().dialogue.index])
    frame({ "A" }); idle(); n = n + 1
    if n > 20 then error("dialogue stuck") end
  end
end
local BTN = { N = "up", E = "right", S = "down", W = "left" }
local function press(dir) frame({ BTN[dir] }); idle(2); dismiss() end

-- BFS path inside the current area to any cell where ok(x, y)
local function path(ok)
  local e = E(); local a = e.area; local p = e.player
  local start = layout.key(p.x, p.y)
  local prev, q, head = { [start] = false }, { { p.x, p.y } }, 1
  while head <= #q do
    local c = q[head]; head = head + 1
    if ok(c[1], c[2]) then
      local steps, k = {}, layout.key(c[1], c[2])
      while prev[k] do local pc = prev[k]; table.insert(steps, 1, pc.dir); k = pc.from end
      return steps
    end
    for _, d in ipairs(grid.DIRS) do
      local nx, ny = c[1] + d[1], c[2] + d[2]
      local nk = layout.key(nx, ny)
      if layout.inside(a, nx, ny) and prev[nk] == nil and not a.solid[ny][nx]
        and (not e:objectAt(nx, ny) or (ok(nx, ny) and e:objectAt(nx, ny).kind ~= "chest" and e:objectAt(nx, ny).kind ~= "npc")) and not (e:portalAt(nx, ny) and not ok(nx, ny)) then
        prev[nk] = { from = layout.key(c[1], c[2]), dir = d[3] }
        q[#q + 1] = { nx, ny }
      end
    end
  end
  return nil
end

-- one step, fighting an enemy in the way
local function step(dir)
  local e = E(); local p = e.player
  local d = grid.DELTA[dir]
  local tries = 0
  while true do
    local en = e:enemyAt(p.x + d[1], p.y + d[2])
    if not en then break end
    tries = tries + 1
    p:face(dir)
    if p:has("sword") then frame({ "A" }); idle(10); dismiss() elseif p:has("shield") then frame({ "B" }); idle(13); dismiss() else idle(5) end
    if tries > 40 then break end
  end
  local before = E().area.id
  press(dir)
  return E().area.id ~= before
end

local function walk(ok)
  for _ = 1, 40 do
    local steps = path(ok)
    if not steps then return false end
    if #steps == 0 then return true end
    local area = E().area.id
    step(steps[1])
    if E().area.id ~= area then return true end
  end
  local steps = path(ok)
  return steps ~= nil and #steps == 0
end

local function walkTo(x, y) return walk(function(a, b) return a == x and b == y end) end

local function faceAndA(x, y)
  if not walk(function(a, b) return math.abs(a - x) + math.abs(b - y) == 1 end) then return false end
  local p = E().player
  for _, d in ipairs(grid.DIRS) do if p.x + d[1] == x and p.y + d[2] == y then p:face(d[3]) end end
  frame({ "A" }); idle(2); dismiss()
  return true
end

local function exitVia(dir)
  local a = E().area
  local cells = a.openings[dir]
  for _ = 1, 6 do
    if E().area ~= a then return true end
    local ok = walk(function(x, y) for _, c in ipairs(cells) do if c[1] == x and c[2] == y then return true end end return false end)
    if E().area ~= a then return true end
    if ok and step(dir) then return true end
  end
  return E().area ~= a
end

local function goOutside()
  for _ = 1, 3 do
    local a = E().area
    if not a.interior then return end
    walkTo(a.portals[1].x, a.portals[1].y)
  end
end

local function travel(k)
  for _ = 1, 60 do
    goOutside()
    local here = E().area.cell.k
    if here == k then return true end
    local gen = E().world.gen
    local open = grid.set()
    for c in pairs(gen.cells) do open:add(c) end
    local hasKey = E().player:has("key")
    local dist = grid.cellDistances(k, open, Game.config.MAP, function(a, b)
      local da = grid.cellDir(a, b, Game.config.MAP)
      if not gen.cells[a].links[da] then return false end
      local gated = gen.cells[a].locked == da or gen.cells[a].lockedTo == da or gen.cells[a].gates[da]
      local id = "gate:" .. math.min(a, b) .. "-" .. math.max(a, b)
      if gated and E().world.status[id] ~= "open" and not hasKey then return false end
      return true
    end)
    local best
    for _, d in ipairs(grid.DIRS) do
      local n = E().world:neighbor(here, d[3])
      if gen.cells[here].links[d[3]] and dist[n] and dist[n] < (dist[here] or 99) then best = d[3] end
    end
    if not best then say("no route from", here, "to", k); return false end
    say(("  %s%d -> %s"):format(E().area.kind, here, best))
    exitVia(best)
  end
  return E().area.cell.k == k
end

local openChestHere
-- take a way (a door or stairs): push its secret open first
local function takeWay(way)
  local a = E().area
  for _, sec in ipairs(Game.objects.ofKind(a, "secret")) do
    if sec.x == way.x and sec.y == way.y and Game.objects.status(E().world, sec) == "hidden" then
      faceAndA(sec.x, sec.y); shot("secret_" .. a.kind)
    end
  end
  walkTo(way.x, way.y)
  return E().area ~= a
end
-- the chest is inside, below or up top (data/places.lua): go there, open it, come back
local function openChestInside()
  local a = E().area
  if not a.chestOnward then return end
  local way = a.chestOnward == "a" and a.up or a.chestOnward == "u" and a.down or a.door
  if not (way and takeWay(way)) then return end
  local h = E().area
  if h.chestOnward and h.down then takeWay(h.down) end
  openChestHere()
  goOutside()
end

function openChestHere()
  openChestInside()
  local a = E().area
  for _, c in ipairs(Game.objects.ofKind(a, "chest")) do
    if Game.objects.status(E().world, c) == "closed" and E().area == a then
      faceAndA(c.x, c.y)
      shot("chest_open_" .. a.kind)
      -- the item lands on a free cell next to the chest
      while #a.items > 0 and E().area == a do
        local it = a.items[1]
        walkTo(it.x, it.y)
        dismiss()
        if a.items[1] == it then break end
      end
    end
  end
end

-- ---- the run ----
idle(); shot("start")
dismiss()
openChestHere()
log[#log + 1] = "shield " .. tostring(E().player:has("shield"))
goOutside(); shot("outside")
local gen = E().world.gen
local faints = 0
local function faintCount() local n = 0 for _, s in ipairs(stub.sounds) do if s == "sounds/faint" then n = n + 1 end end return n end
local keysFound = 0
for act = 1, 4 do
  if act == 2 then
    for _ = 1, 6 do
      if E().player:has("sword") then break end
      travel(gen.sword); if #shots < 4 then shot("sword_area") end; openChestHere()
    end
  end
  local before = (E().player.items.key or 0)
  for _ = 1, 6 do
    if (E().player.items.key or 0) > before then break end
    travel(gen.keys[act]); openChestHere()
  end
  if (E().player.items.key or 0) > before then keysFound = keysFound + 1 end
end
log[#log + 1] = "sword " .. tostring(E().player:has("sword"))
log[#log + 1] = "keys " .. keyPickups
travel(gen.dungeonDoor.outside); shot("dungeon_door")
for _ = 1, 6 do
  if E().player:has("cellKey") then break end
  travel(gen.cellKey); openChestHere()
end
log[#log + 1] = "cellKey " .. tostring(E().player:has("cellKey"))
for _ = 1, 6 do
  if travel(gen.goal) then break end
end
shot("goal_room")
local won = false
E().onEnd = function() won = true end
local cl = Game.objects.ofKind(E().area, "cell")[1]
if cl then
  -- walk into the cell door to unlock it
  walk(function(a, b) return math.abs(a - cl.x) + math.abs(b - cl.y) == 1 end)
  local p = E().player
  for _, d in ipairs(grid.DIRS) do if p.x + d[1] == cl.x and p.y + d[2] == cl.y then press(d[3]) end end
  shot("cell_open")
end
if E().npcs[1] then faceAndA(E().npcs[1].x, E().npcs[1].y) end
stub.menu["map"](); idle(); shot("map")
log[#log + 1] = "faints " .. faintCount()
log[#log + 1] = ("gate %s cell %s | won %s | hearts %d/%d | frames %d | sounds %d"):format(tostring(E().world.status["gate:" .. math.min(gen.dungeonDoor.inside, gen.dungeonDoor.outside) .. "-" .. math.max(gen.dungeonDoor.inside, gen.dungeonDoor.outside)]), tostring(E().world.status["cell:" .. gen.goal]), tostring(won), E().player.hearts, E().player.maxHearts, frames, #stub.sounds)
if VERBOSE then print("ended in", E().area.id, E().area.kind, #E().area.portals) end
print("seed " .. E().world.seed .. ": " .. table.concat(log, " | "))
if OUT then local f = io.open(OUT .. "/shots.txt", "w"); f:write(table.concat(shots, "\n")); f:close() end
