-- Act banners, villager hints and text length checks.
--   lua unit_polish.lua <source>
SRC = arg[1]
stub = dofile("stub.lua")
stub.boot()
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. msg) end end
local e = stub.explore
local w, g = e.world, e.world.gen
check(e.bannerText == Game.story.acts[1].name and e.bannerFrames > 0, "Act I banner at the start")
-- walking through the first gate shows Act II's banner once
local gt = g.gates[1]
local dir = Game.grid.cellDir(gt.from, gt.to, 4)
e:enter("c" .. gt.from, 2, 2, "S")
w.status["gate:" .. math.min(gt.from, gt.to) .. "-" .. math.max(gt.from, gt.to)] = "open"
e.bannerFrames = 0
e:enter("c" .. gt.to, 2, 2, dir)
check(e.bannerText == Game.story.acts[2].name and e.bannerFrames > 0, "Act II banner on entering")
e.bannerFrames = 0
e:enter("c" .. gt.from, 2, 2, "S"); e:enter("c" .. gt.to, 2, 2, dir)
check(e.bannerFrames == 0, "banner only the first time")
-- hints: every villager names its act's key place and the gate; nothing missing
local longest, seen = 0, 0
for seed = 1, 300 do
  local world = Game.World.new(seed)
  for k, c in pairs(world.gen.cells) do
    if c.kind == "town" and c.role ~= "start" then
      local a = world:area("c" .. k)
      if a.house then
        local h = world:area("h" .. k)
        local v = Game.objects.ofKind(h, "npc")[1]
        local lines = v.rules[1].does.say
        seen = seen + 1
        check(#lines >= 3, "villager has greeting + key + gate hints")
        local keyLine = false
        for _, l in ipairs(lines) do
          check(not l:find("nil") and not l:find("%%s"), "hint has no holes: " .. l)
          if l:find("key is hidden") then keyLine = true end
          longest = math.max(longest, #l)
        end
        check(keyLine, "villager names this region's key")
      end
    end
  end
end
check(seen > 100, "enough villagers checked: " .. seen)
-- every line the game says fits the dialogue box (about two lines of ~46 characters)
local function scan(t)
  for _, v in pairs(t) do
    if type(v) == "string" then longest = math.max(longest, #v) elseif type(v) == "table" then scan(v) end
  end
end
scan(Game.text)
check(longest <= 92, "longest line " .. longest .. " characters")
-- dying ends the run: after the last line it's logged and the title
-- screen comes back
Game.newWorld(5)
local before = stub.explore
before.dialogue = nil
before.player.hearts = 1
before.player.invulnerable = 0
before:hurtPlayer({ x = -9, y = -9 }) -- far off: no knock-back
check(before.player.hearts == 0 and before.dialogue ~= nil, "dying says so")
local runs = Game.profile.runs(10)
for _ = 1, 10 do
  if #Game.profile.runs(10) > #runs then break end
  stub.frame({ "A" }); stub.frame({})
end
local last = Game.profile.parseRun(Game.profile.runs(1)[1] or "")
check(last.result == "died" and last.hero == "Tester" and last.seed == "seed 5", "dying is logged: " .. tostring(Game.profile.runs(1)[1]))
stub.frame({}); stub.frame({})
-- the title screen is up: one more Ⓐ on Start goes to the heroes page,
-- and Ⓐ on the hero starts a new run
local e0 = stub.explore
stub.frame({ "A" }); stub.frame({ "A" })
check(stub.explore ~= e0 and stub.explore.world.seed ~= nil, "Start, then the hero, starts a new run")
-- the shield: a blocked push goes to a side; the last push (items.json
-- shield.pushesToDefeat) defeats
do
  local e = stub.explore
  e.dialogue = nil
  local a, p = e.area, e.player
  local saved = {}
  local function wall(x, y, v) saved[#saved + 1] = { x, y, a.solid[y][x] }; a.solid[y][x] = v end
  for y = 2, 6 do for x = 3, 7 do wall(x, y, true) end end
  -- a dead end: player at (4,4) facing E, enemy at (5,4), wall behind it
  wall(4, 4, false); wall(5, 4, false); wall(5, 3, false)
  e.enemies = {}
  p.x, p.y = 4, 4; p:face("E")
  local en = Game.Enemy.new({ x = 5, y = 4, tile = 1, hp = 1 })
  en.obj = Game.objects.new("enemy", "enemy:test", 5, 4)
  e.enemies[1] = en
  e:shieldPush(en, "E")
  check(en.x == 5 and en.y == 3, "blocked push goes to the free side: " .. en.x .. "," .. en.y)
  -- no room anywhere: it stays put, and the last push defeats it
  local needed = Game.items.shield.pushesToDefeat
  en.x, en.y = 5, 4; wall(5, 3, true)
  for _ = 2, needed - 1 do e:shieldPush(en, "E") end
  check(en.x == 5 and en.y == 4 and #e.enemies == 1, "no room: stays, not yet beaten")
  e:shieldPush(en, "E")
  check(#e.enemies == 0, "push " .. needed .. " defeats")
  -- blocking an attack counts too
  local en2 = Game.Enemy.new({ x = 5, y = 4, tile = 1, hp = 2 })
  en2.obj = Game.objects.new("enemy", "enemy:test2", 5, 4)
  e.enemies = { en2 }
  p.guard = 5
  for _ = 1, needed do p.guard = 5; e:attack(en2, "W") end
  check(#e.enemies == 0 and p.hearts > 0, "blocked attacks count")
  for i = #saved, 1, -1 do local w = saved[i]; a.solid[w[2]][w[1]] = w[3] end
end
print(fails == 0 and ("unit_polish: all passed (" .. seen .. " villagers, longest line " .. longest .. ")") or ("unit_polish: " .. fails .. " failed"))
