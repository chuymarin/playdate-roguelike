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
print(fails == 0 and ("unit_polish: all passed (" .. seen .. " villagers, longest line " .. longest .. ")") or ("unit_polish: " .. fails .. " failed"))
