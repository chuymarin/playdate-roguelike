-- Layers: a lower level's passage leads into the neighbor's lower level
-- (same act, both with stairs down), and its stairs go back up to that
-- neighbor's area; a hidden way down opens when you walk into it; the
-- stairs back up sit on the same cell as the way down, and going down
-- puts you on the same spot you stood on.
--   lua unit_layers.lua <source> [worlds]
SRC = arg[1]
local N = tonumber(arg[2] or 60)
stub = dofile("stub.lua")
stub.boot()
local fails, passages, secrets, hidden, aligned = 0, 0, 0, 0, 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. msg) end end
local grid, objects = Game.grid, Game.objects

-- Hits what's in front of the hero with the shield (Ⓑ) or the sword (Ⓐ).
local function strike(e, dir, weapon)
  local p = e.player
  if not p:has(weapon) then p:give(weapon) end
  p.swing, p.guard = 0, 0
  p:face(dir)
  if weapon == "shield" then e:pressB() else e:pressA() end
  e:updateCombat()
  p.swing, p.guard = 0, 0 -- done swinging
end

for seed = 1, N do
  Game.newWorld(seed)
  local e = stub.explore
  local world = e.world
  for k, cell in pairs(world.gen.cells) do
    for _, lv in ipairs({ { "below", "u", "down" }, { "above", "a", "up" } }) do
      local level = cell[lv[1]]
      if level and level.from then
        local from = world:area((level.from == "inside" and "h" or "c") .. k)
        local way = from[lv[3]]
        if way then
          local u = world:area(lv[2] .. k)
          local up = u.portals[1]
          check(up.x == way.x and up.y == way.y, ("seed %d: stairs back in %s%d at %d,%d, way there at %d,%d"):format(seed, lv[2], k, up.x, up.y, way.x, way.y))
          check(u.entry[1] == way.frontX and u.entry[2] == way.frontY, "you arrive where you stood")
          -- walking onto the stairs takes you there, and back
          e:enter(from.id, way.frontX, way.frontY, "N")
          e.dialogue = nil
          if not objects.at(from, world, way.x, way.y) then
            for _, d in ipairs(grid.DIRS) do
              if way.frontX + d[1] == way.x and way.frontY + d[2] == way.y then e:tryMove(d[3]) end
            end
            check(e.area.id == lv[2] .. k, ("seed %d: the stairs lead to %s%d (got %s)"):format(seed, lv[2], k, e.area.id))
            check(e.player.x == way.frontX and e.player.y == way.frontY, "arrive on the same spot")
          end
          aligned = aligned + 1
        end
      end
    end
    -- walk through each passage from k's lower and upper level
    for _, lv in ipairs({ { "u", "underLinks", "below" }, { "a", "overLinks", "above" } }) do
    local prefix = lv[1]
    for dir in pairs(cell[lv[2]] or {}) do
      local nb = world:neighbor(k, dir)
      local u = world:area(prefix .. k)
      local o = u.openings[dir][1]
      -- a hidden passage: walking into its cover opens it, on both sides
      local d = grid.DELTA[dir]
      local cover = objects.at(u, world, o[1] - d[1], o[2] - d[2])
      if cover and cover.template == "secret" then
        local bx, by = o[1] - 2 * d[1], o[2] - 2 * d[2]
        if not u.solid[by][bx] and not objects.at(u, world, bx, by) then
          e:enter(u.id, bx, by, dir)
          e.dialogue = nil
          e:tryMove(dir)
          check(objects.status(world, cover) == "hidden", "walking into a hidden passage doesn't open it")
          strike(e, dir, "sword")
          check(objects.status(world, cover) == "open", "the sword opens a hidden passage")
          local other = world:area("u" .. nb)
          for _, sec in ipairs(objects.ofKind(other, "secret")) do
            if sec.id == cover.id then check(objects.status(world, sec) == "open", "the other side opens too") end
          end
          hidden = hidden + 1
        end
      end
      e:enter(u.id, o[1], o[2], dir)
      e.dialogue = nil
      e:tryMove(dir)
      check(e.area.id == prefix .. nb, ("seed %d: passage %d %s leads to %s%d (got %s)"):format(seed, k, dir, prefix, nb, e.area.id))
      local up = e.area.portals[1]
      if world.gen.cells[nb][lv[3]].from then
        check(up and up.to:sub(2) == tostring(nb), "its stairs go to the neighbor's own area")
      else
        check(up == nil, "a spread-to level has no stairs")
      end
      passages = passages + 1
    end
    end
    -- open a hidden way down by walking into it
    local c = world:area("c" .. k)
    for _, sec in ipairs(objects.ofKind(c, "secret")) do
      if objects.status(world, sec) == "hidden" then
        local d = c.down
        e:enter(c.id, d.frontX, d.frontY, "N")
        e.dialogue = nil
        local dir
        for _, g in ipairs(grid.DIRS) do if d.frontX + g[1] == sec.x and d.frontY + g[2] == sec.y then dir = g[3] end end
        e:tryMove(dir)
        check(objects.status(world, sec) == "hidden", "walking into a secret doesn't open it")
        e:pressA()
        check(objects.status(world, sec) == "hidden" or e.player:has("sword"), "Ⓐ alone (no sword) doesn't open it")
        strike(e, dir, "shield")
        check(objects.status(world, sec) == "open", "the shield opens a secret")
        e.dialogue = nil
        e:tryMove(dir)
        check(e.area.id == "u" .. k, ("seed %d: walking onto the open way goes down (got %s)"):format(seed, e.area.id))
        secrets = secrets + 1
      end
    end
  end
end
-- coming up from below through a covered way opens that cover (like a
-- door left open behind you), and only that one
local backs = 0
for seed = 1, N do
  Game.newWorld(seed)
  local e = stub.explore
  local world = e.world
  for k, cell in pairs(world.gen.cells) do
    local level = cell.below
    if level and level.from and level.cover and level.cover ~= "mouth" then
      local from = world:area((level.from == "inside" and "h" or "c") .. k)
      local way = from.down
      local cover
      for _, sec in ipairs(objects.ofKind(from, "secret")) do
        if way and sec.x == way.x and sec.y == way.y then cover = sec end
      end
      if cover and objects.status(world, cover) == "hidden" then
        local hiddenBefore = {}
        for id, a in pairs(world.areas) do
          for _, sec in ipairs(objects.ofKind(a, "secret")) do
            if objects.status(world, sec) == "hidden" then hiddenBefore[sec.id] = true end
          end
        end
        local u = world:area("u" .. k)
        e:enter(u.id, u.entry[1], u.entry[2], "N")
        e.dialogue = nil
        local up = u.portals[1]
        for _, d in ipairs(grid.DIRS) do
          if u.entry[1] + d[1] == up.x and u.entry[2] + d[2] == up.y then e:tryMove(d[3]) end
        end
        check(e.area.id == from.id, ("seed %d: the way up from u%d leads to %s (got %s)"):format(seed, k, from.id, e.area.id))
        check(objects.status(world, cover) == "open", ("seed %d: leaving u%d by its stairs opens the %s"):format(seed, k, level.cover))
        check(not objects.at(from, world, way.x, way.y), "nothing blocks the way you came by")
        for id, a in pairs(world.areas) do
          for _, sec in ipairs(objects.ofKind(a, "secret")) do
            if sec ~= cover and hiddenBefore[sec.id] then
              check(objects.status(world, sec) == "hidden", ("seed %d: %s stays closed"):format(seed, sec.id))
            end
          end
        end
        backs = backs + 1
      end
    end
  end
end
check(backs > 0, "some ways back tested")
-- the map screen draws from every layer (it marks the way in, or your spot)
local maps = 0
for seed = 1, 20 do
  Game.newWorld(seed)
  local e = stub.explore
  for k, cell in pairs(e.world.gen.cells) do
    for _, prefix in ipairs({ "h", "u", "a" }) do
      local has = prefix == "h" and cell.inside or prefix == "u" and cell.below or prefix == "a" and cell.above
      if has then
        local ok = pcall(function()
          local a = e.world:area(prefix .. k)
          e:enter(a.id, a.entry[1], a.entry[2], "N")
          Game.MapScreen.new(e.world, e, function() end):draw()
        end)
        check(ok, ("seed %d: map screen from %s%d"):format(seed, prefix, k))
        maps = maps + 1
      end
    end
  end
end
-- the map shows only the layer you're on, and only its visited areas
for seed = 1, 20 do
  Game.newWorld(seed)
  local e = stub.explore
  local world = e.world
  for k, cell in pairs(world.gen.cells) do
    if cell.below and cell.below.from then
      local u = world:area("u" .. k)
      e:enter(u.id, u.entry[1], u.entry[2], "N")
    end
  end
  for _, layer in ipairs({ "c", "h", "u", "a" }) do
    for k, area in pairs(Game.MapScreen.shown(world, layer)) do
      check(area.id == layer .. k and world.visited[area.id], ("seed %d: map of %s shows %s"):format(seed, layer, area.id))
    end
  end
  local lows = 0
  for _ in pairs(Game.MapScreen.shown(world, "u")) do lows = lows + 1 end
  check(lows > 0, "visited lower levels show on the Below map")
end
check(Game.text.mapLayers.u == "Below", "the layers are named")
check(maps > 0, "map screens tested")
check(passages > 0, "some passages tested")
check(secrets > 0, "some secrets tested")
check(hidden > 0, "some hidden passages tested")
check(aligned > 0, "some stairs tested")
print(("unit_layers: %s (%d passages, %d hidden, %d secrets, %d ways back, %d stairs aligned)"):format(fails == 0 and "all passed" or fails .. " failed", passages, hidden, secrets, backs, aligned))
if fails > 0 then os.exit(1) end
