-- Layers: a lower level's passage leads into the neighbor's lower level
-- (same act, both with stairs down), and its stairs go back up to that
-- neighbor's area; a hidden way down opens when you walk into it.
--   lua unit_layers.lua <source> [worlds]
SRC = arg[1]
local N = tonumber(arg[2] or 60)
stub = dofile("stub.lua")
stub.boot()
local fails, passages, secrets, hidden = 0, 0, 0, 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. msg) end end
local grid, objects = Game.grid, Game.objects

for seed = 1, N do
  Game.newWorld(seed)
  local e = stub.explore
  local world = e.world
  for k, cell in pairs(world.gen.cells) do
    -- walk through each passage from k's lower level
    for dir in pairs(cell.underLinks or {}) do
      local nb = world:neighbor(k, dir)
      local u = world:area("u" .. k)
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
      check(e.area.id == "u" .. nb, ("seed %d: passage %d %s leads to u%d (got %s)"):format(seed, k, dir, nb, e.area.id))
      local up = e.area.portals[1]
      check(up and up.to:sub(2) == tostring(nb), "stairs up go to the neighbor's own area")
      passages = passages + 1
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
check(passages > 0, "some passages tested")
check(secrets > 0, "some secrets tested")
check(hidden > 0, "some hidden passages tested")
print(("unit_layers: %s (%d passages, %d hidden, %d secrets)"):format(fails == 0 and "all passed" or fails .. " failed", passages, hidden, secrets))
if fails > 0 then os.exit(1) end
