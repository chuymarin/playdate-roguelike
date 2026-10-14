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
          check(objects.status(world, cover) == "open", "hidden passage opens on bump")
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
        check(objects.status(world, sec) == "open", "secret opens on bump")
        e.dialogue = nil
        e:tryMove(dir)
        check(e.area.id == "u" .. k, ("seed %d: walking onto the open way goes down (got %s)"):format(seed, e.area.id))
        secrets = secrets + 1
      end
    end
  end
end
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
check(maps > 0, "map screens tested")
check(passages > 0, "some passages tested")
check(secrets > 0, "some secrets tested")
check(hidden > 0, "some hidden passages tested")
check(aligned > 0, "some stairs tested")
print(("unit_layers: %s (%d passages, %d hidden, %d secrets, %d stairs aligned)"):format(fails == 0 and "all passed" or fails .. " failed", passages, hidden, secrets, aligned))
if fails > 0 then os.exit(1) end
