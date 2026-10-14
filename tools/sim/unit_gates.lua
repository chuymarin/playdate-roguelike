-- Gates between acts (Rulebook 2.4): objects on both sides with one id,
-- regions sealed until their key is used, an open gate walkable both ways.
--   lua unit_gates.lua <source> [worlds]
SRC = arg[1]
local N = tonumber(arg[2] or 300)
stub = dofile("stub.lua")
stub.boot()
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; if fails < 20 then print("FAIL " .. msg) end end end
local objects, grid = Game.objects, Game.grid
for seed = 1, N do
  local w = Game.World.new(seed)
  local g = w.gen
  local gateCount = 0
  for k, c in pairs(g.cells) do
    local a = w:area("c" .. k)
    for dir in pairs(c.links) do
      local n = w:neighbor(k, dir)
      local id = "gate:" .. math.min(k, n) .. "-" .. math.max(k, n)
      local gated = c.gates[dir] or c.locked == dir or c.lockedTo == dir
      local found
      for _, o in ipairs(objects.ofKind(a, "gate")) do if o.id == id then found = o end end
      if gated then
        gateCount = gateCount + 1
        check(found, ("seed %d: gate %s missing on cell %d"):format(seed, id, k))
        if found then
          local cells = a.openings[dir]
          check(found.x == cells[1][1] and found.y == cells[1][2], "gate on the doorway's first cell")
          check(#cells == 1, "rest of a gated doorway is closed")
        end
      else
        check(not found, "no gate on an open link")
      end
      if c.act ~= g.cells[n].act then check(c.gates[dir], ("seed %d: link between acts %d-%d without gate"):format(seed, k, n)) end
    end
  end
  check(gateCount == 8, ("seed %d: %d gate sides (want 3 act gates + dungeon door, both sides)"):format(seed, gateCount))
  -- with every gate closed, the start reaches exactly Act I; each opened gate adds the next act
  local function reach(open)
    local seen, q = { [g.start] = true }, { g.start }
    while #q > 0 do
      local k = table.remove(q)
      for dir in pairs(g.cells[k].links) do
        local n = w:neighbor(k, dir)
        local c = g.cells[k]
        local gated = c.gates[dir] or c.locked == dir or c.lockedTo == dir
        local id = "gate:" .. math.min(k, n) .. "-" .. math.max(k, n)
        if not seen[n] and (not gated or open[id]) then seen[n] = true; q[#q + 1] = n end
      end
    end
    return seen
  end
  local open = {}
  for act = 1, 4 do
    local seen = reach(open)
    for k, c in pairs(g.cells) do
      local want = c.act <= act and not (act == 4 and c.dungeon and not open.dungeon)
      if act < 4 then want = c.act <= act end
      if act == 4 then want = c.act < 4 or k == g.entrance end
      check((seen[k] or false) == want, ("seed %d act %d: cell %d reachable=%s"):format(seed, act, k, tostring(seen[k])))
    end
    if act <= 3 then
      local gt = g.gates[act]
      open["gate:" .. math.min(gt.from, gt.to) .. "-" .. math.max(gt.from, gt.to)] = true
    end
  end
end
-- in game: blocked without a key, opens with one, walk across and back
local e = stub.explore
local w, g = e.world, e.world.gen
local gt = g.gates[1]
local dir = grid.cellDir(gt.from, gt.to, 4)
local a = w:area("c" .. gt.from)
local cells = a.openings[dir]
local gx, gy = cells[1][1], cells[1][2]
local d = grid.DELTA[grid.OPP[dir]]
e:enter(a.id, gx + d[1], gy + d[2], dir)
e.enemies = {}
e.dialogue = nil
e:tryMove(dir)
check(e.area.id == a.id and e.player.x == gx + d[1], "blocked without a key")
check(e.dialogue == nil and e.toastText == Game.text.doorHint, "walking into it only hints")
e.player:give("key")
e:tryMove(dir)
check(e.player.items.key == 1, "bumping with a key doesn't open it")
e.player:face(dir); e.player.items.key = nil
e:pressA()
check(e.dialogue ~= nil and e.dialogue.lines[1] == Game.text.gateLocked[1], "Ⓐ without a key: it's locked")
e.dialogue = nil
e.player:give("key")
e:pressA()
check(e.player.items.key == nil, "Ⓐ with the key opens it; the key is used up")
check(w.status["gate:" .. math.min(gt.from, gt.to) .. "-" .. math.max(gt.from, gt.to)] == "open", "gate open")
e:tryMove(dir) -- onto the open gate
check(e.player.x == gx and e.player.y == gy, "walk onto the open gate")
e:tryMove(dir) -- through to the next act
check(e.area.cell.k == gt.to, "walked into the next act")
e.enemies = {}
e:tryMove(grid.OPP[dir]) -- onto the other side's gate tile
e:tryMove(grid.OPP[dir]) -- back
check(e.area.cell.k == gt.from, "and back")
print(fails == 0 and ("unit_gates: all passed (" .. N .. " worlds)") or ("unit_gates: " .. fails .. " failed"))
