-- Screen transitions: each kind of move (edge, layer) plays the effect
-- settings.json names for it, the game waits while it plays, and every
-- effect draws at any point.
--   lua unit_transitions.lua <source>
SRC = arg[1]
stub = dofile("stub.lua")
stub.transitions = true
stub.boot()
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. msg) end end
local T, config, grid = Game.transitions, Game.config, Game.grid
local e = stub.explore
e.dialogue = nil

check(config.TRANSITIONS.edge.effect == "slide" and config.TRANSITIONS.layer.effect == "fade", "settings.json: slide between areas, fade through doors")

-- walking off an edge plays the edge effect, and the game waits for it
local function edgeOut()
  local w = e.world
  for k = 0, 15 do
    local a = w:area("c" .. k)
    for dir, ops in pairs(a.openings) do
      local o = ops[1]
      local d = grid.DELTA[dir]
      local ix, iy = o[1] - d[1], o[2] - d[2]
      if not a.solid[iy][ix] and not Game.objects.at(a, w, ix, iy) then
        e:enter(a.id, o[1], o[2], dir)
        e.enemies = {}
        return a, dir
      end
    end
  end
end
local a, dir = edgeOut()
e:tryMove(dir)
check(e.area.id ~= a.id, "the move happens at once (the new area is set)")
check(e.transition and e.transition.effect == T.effects.slide, "walking off the edge slides")
local x, y = e.player.x, e.player.y
local frames = 0
while e.transition and frames < 100 do
  stub.frame({ "up" }) -- input is ignored while it plays
  frames = frames + 1
end
check(frames == config.TRANSITIONS.edge.frames, "it lasts its frames: " .. frames)
check(e.player.x == x and e.player.y == y, "no walking during the slide")

-- a door, stairs or cave mouth plays the layer effect (iris: circles drawn)
local function throughDoor()
  for k = 0, 15 do
    local c = e.world:area("c" .. k)
    if c.door and not Game.objects.at(c, e.world, c.door.x, c.door.y) then
      e:enter(c.id, c.door.frontX, c.door.frontY, "N")
      e.enemies = {}
      for _, g in ipairs(grid.DIRS) do
        if c.door.frontX + g[1] == c.door.x and c.door.frontY + g[2] == c.door.y then e:tryMove(g[3]) end
      end
      return c
    end
  end
end
e.dialogue = nil
local c = throughDoor()
check(c and e.area.id == "h" .. c.cell.k, "the door leads inside")
check(e.transition and e.transition.effect == T.effects.fade, "a door plays the fade")
local irisFrames = 0
while e.transition do
  stub.frame({})
  irisFrames = irisFrames + 1
end
check(irisFrames == config.TRANSITIONS.layer.frames, "the fade lasts its frames")

-- the effect is picked in settings, not in code: fade, cut, or off
config.TRANSITIONS.layer = { effect = "iris", frames = 10 }
e:enter(c.id, c.door.frontX, c.door.frontY, "N"); e.enemies = {}
for _, g in ipairs(grid.DIRS) do if c.door.frontX + g[1] == c.door.x and c.door.frontY + g[2] == c.door.y then e:tryMove(g[3]) end end
check(e.transition and e.transition.effect == T.effects.iris, "switching the setting to iris uses it")
e.transition = nil
config.TRANSITIONS.layer = { effect = "cut", frames = 10 }
e:enter(c.id, c.door.frontX, c.door.frontY, "N"); e.enemies = {}
for _, g in ipairs(grid.DIRS) do if c.door.frontX + g[1] == c.door.x and c.door.frontY + g[2] == c.door.y then e:tryMove(g[3]) end end
check(e.transition == nil and e.area.id == "h" .. c.cell.k, "cut: no transition")
config.TRANSITIONS.layer = { effect = "iris", frames = 0 }
check(T.start("layer", {}, {}, {}) == nil, "0 frames: none")
config.TRANSITIONS.layer = { effect = "spin", frames = 10 }
local ok, err = pcall(T.start, "layer", {}, {}, {})
check(not ok and tostring(err):find("no effect named spin"), "an unknown effect says so")

-- every effect draws from start to end, in every direction
local img = playdate.graphics.image.new(400, 240, "black")
for name, effect in pairs(T.effects) do
  if effect.draw then
    for _, d in ipairs({ "N", "E", "S", "W" }) do
      for _, p in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
        local ok2, err2 = pcall(effect.draw, p, img, img, { dir = d, fromX = 20, fromY = 30, toX = 380, toY = 220, room = { x = 8, y = 16, w = 384, h = 224 } }, {})
        check(ok2, name .. " draws at " .. p .. ": " .. tostring(err2))
      end
    end
  end
end
check(stub.clip == nil, "the slide leaves no clip behind")
print(fails == 0 and "unit_transitions: all passed" or ("unit_transitions: " .. fails .. " failed"))
