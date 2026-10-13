-- Builds every area (and house interior) of many worlds and checks them:
-- doorways connected and aligned, chests / NPCs / spawns reachable, gates on
-- gated sides, the captive only reachable through the cell door.
--   lua stress.lua <source> [worlds]
SRC = arg[1]
local N = tonumber(arg[2] or 500)
local stub = dofile("stub.lua")
Game = {}
for line in io.lines(SRC .. "/main.lua") do
  local m = line:match('^import "([^"]+)"')
  if m then import(m) end
end
local layout, grid = Game.layout, Game.grid
local problems, counts = {}, {}
local function bad(msg) problems[msg] = (problems[msg] or 0) + 1 end
local function count(k) counts[k] = (counts[k] or 0) + 1 end

local function walkable(a, x, y) return layout.inside(a, x, y) and not a.solid[y][x] end

for seed = 1, N do
  local world = Game.World.new(seed)
  for k, cell in pairs(world.gen.cells) do
    local ok, a = pcall(world.area, world, "c" .. k)
    if not ok then bad("build error " .. cell.kind .. ": " .. tostring(a)) goto next end
    count(cell.kind)
    -- doorways all connected (treat chest/NPC cells as blocked)
    local anchors = layout.anchors(a)
    if a.house then anchors[#anchors + 1] = { a.house.frontX, a.house.frontY } end
    if not layout.connected(a, anchors) then bad("anchors disconnected " .. cell.kind) end
    -- doorway cells must line up with the neighbor's
    for dir in pairs(cell.links) do
      if not a.openings[dir] or #a.openings[dir] == 0 then bad("missing opening " .. cell.kind) end
    end
    -- every chest / npc has a reachable standing spot
    local dist = layout.reach(a, { anchors[1] }, a.occupied)
    local function standable(x, y)
      for _, d in ipairs(grid.DIRS) do
        local nx, ny = x + d[1], y + d[2]
        if dist[layout.key(nx, ny)] then return true end
      end
      return false
    end
    local chests, npcs = Game.objects.ofKind(a, "chest"), Game.objects.ofKind(a, "npc")
    for _, c in ipairs(chests) do if not standable(c.x, c.y) then bad("chest unreachable " .. cell.kind) end end
    for _, n in ipairs(npcs) do if n.template ~= "captive" and not standable(n.x, n.y) then bad("npc unreachable " .. cell.kind) end end
    if cell.chest and cell.role ~= "start" and #chests ~= 1 then bad("chest missing " .. cell.kind) end
    if cell.role == "goal" and #npcs ~= 1 then bad("goal npc missing") end
    if #a.enemySpawns ~= cell.enemies then bad(("enemies %d/%d in %s"):format(#a.enemySpawns, cell.enemies, cell.kind)) end
    for _, s in ipairs(a.enemySpawns) do
      if not walkable(a, s.x, s.y) or s.x <= 1 or s.y <= 1 or s.x >= a.cols or s.y >= a.rows then bad("spawn on wall/border") end
    end
    if cell.kind == "town" then
      if not a.house then bad("town without house") else
        count("house")
        local ok2, h = pcall(world.area, world, "h" .. k)
        if not ok2 then bad("house build error: " .. tostring(h)) else
          local ha = { { h.portals[1].x, h.portals[1].y }, h.entry }
          if not layout.connected(h, ha) then bad("house exit blocked") end
          local hd = layout.reach(h, { h.entry }, h.occupied)
          for _, c in ipairs(Game.objects.ofKind(h, "chest")) do
            local s = false
            for _, d in ipairs(grid.DIRS) do if hd[layout.key(c.x + d[1], c.y + d[2])] then s = true end end
            if not s then bad("home chest unreachable") end
          end
          if cell.role == "start" and #Game.objects.ofKind(h, "chest") ~= 1 then bad("home without chest") end
          if cell.role ~= "start" and #Game.objects.ofKind(h, "npc") ~= 1 then bad("house without villager") end
        end
      end
    end
    if cell.kind == "camp" and not a.respawn then bad("camp without respawn") end
    for _, g in ipairs(Game.objects.ofKind(a, "gate")) do if not walkable(a, g.x, g.y) then bad("gate tile solid") end end
    local wantGates = (cell.locked and 1 or 0) + (cell.lockedTo and 1 or 0)
    for _ in pairs(cell.gates) do wantGates = wantGates + 1 end
    if #Game.objects.ofKind(a, "gate") ~= wantGates then bad("gate count") end
    if cell.role == "goal" then
      local cl = Game.objects.ofKind(a, "cell")[1]
      if not cl then bad("goal without cell") else
        -- door reachable from a doorway (with the door itself counted as closed)
        local blocked = { [layout.key(cl.x, cl.y)] = true }
        for kk in pairs(a.occupied) do blocked[kk] = true end
        local d0 = layout.reach(a, { anchors[1] }, blocked)
        local front = false
        for _, d in ipairs(grid.DIRS) do if d0[layout.key(cl.x + d[1], cl.y + d[2])] then front = true end end
        if not front then bad("cell door unreachable") end
        -- the NPC can only be reached through the door
        local n = Game.objects.ofKind(a, "npc")[1]
        local inside = false
        for _, d in ipairs(grid.DIRS) do if d0[layout.key(n.x + d[1], n.y + d[2])] then inside = true end end
        if inside then bad("npc reachable without the cell key") end
        for _, s in ipairs(a.enemySpawns) do if math.abs(s.x - n.x) + math.abs(s.y - n.y) <= 1 or (s.x == cl.x and s.y == cl.y) then bad("enemy in cell") end end
      end
    end
    if cell.chest == "cellKey" and not cell.dungeon then bad("cell key outside dungeon") end
    ::next::
  end
  -- whole world reachable through openings: every link has openings on both sides at matching positions
  for k, cell in pairs(world.gen.cells) do
    local a = world.areas["c" .. k]
    for dir in pairs(cell.links) do
      local b = world.areas["c" .. world:neighbor(k, dir)]
      local mine = a.openings[dir][1]
      local theirs = b.openings[grid.OPP[dir]][1]
      if dir == "N" or dir == "S" then
        if mine[1] ~= theirs[1] then bad("openings misaligned") end
      elseif mine[2] ~= theirs[2] then bad("openings misaligned") end
    end
  end
end
print("worlds:", N)
for k, v in pairs(counts) do io.write(k, "=", v, " ") end print()
print("problems:")
for k, v in pairs(problems) do print("  " .. k .. ": " .. v) end
