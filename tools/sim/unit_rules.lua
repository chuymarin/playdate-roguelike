-- Rule engine and object checks (Rulebook Chapter 5, v1 rules in 5.5).
--   lua unit_rules.lua <source>
SRC = arg[1]
stub = dofile("stub.lua")
stub.boot()
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. msg) end end
local rules, objects = Game.rules, Game.objects
local e = stub.explore
local world, p = e.world, e.player
-- a fake context recording effects
local log = {}
local function ctx()
  return {
    player = p,
    statusOf = function(id) return world.status[id] end,
    setStatus = function(obj, s) objects.setStatus(world, obj, s); log[#log + 1] = "status " .. s end,
    drop = function(item, x, y) log[#log + 1] = ("drop %s %d %d"):format(item, x, y) end,
    sound = function(n) log[#log + 1] = "sound " .. n end,
    toast = function(t) log[#log + 1] = "toast " .. t end,
    say = function(lines, onDone) log[#log + 1] = "say " .. lines[1]; if onDone then onDone() end end,
    win = function() log[#log + 1] = "win" end,
  }
end
local area = { id = "t", objects = {} }
-- chest: use -> open, drop item; holes filled
local chest = objects.add(area, "chest", 3, 4, { item = "sword", tile = 303 })
check(chest.id == "chest:t:1" and chest.tiles.closed == 303, "chest instance")
check(objects.blocks(world, chest), "closed chest blocks")
check(not rules.fire("bump", chest, ctx()), "chest has no bump rule")
log = {}
check(rules.fire("use", chest, ctx()), "chest use fires")
check(log[1] == "status open" and log[2] == "drop sword 3 4" and log[3] == "sound chest", "chest effects in order: " .. table.concat(log, ", "))
check(not objects.blocks(world, chest) and objects.tile(world, chest) == nil, "open chest gone")
-- the template wasn't changed by filling
check(Game.objectKinds.chest.rules[1].does.drop == "{item}", "template untouched")
-- gate: otherwise without key, open with key (taken), shared id
local gate = objects.add(area, "gate", 1, 4, { lockedTile = 1, openTile = 2, lockedLines = { "Locked." } }, "gate:1-2")
log = {}
rules.fire("bump", gate, ctx())
check(log[1] == "sound locked" and log[2] == "say Locked." and objects.status(world, gate) == "blocked", "gate otherwise: " .. table.concat(log, ", "))
p:give("key"); p:give("key")
log = {}
rules.fire("bump", gate, ctx())
check(objects.status(world, gate) == "open" and p.items.key == 1, "gate opens, takes one key")
local other = objects.new("gate", "gate:1-2", 12, 4, { lockedTile = 1, openTile = 2 })
check(objects.status(world, other) == "open" and not objects.blocks(world, other) and objects.tile(world, other) == 2, "other side of gate is open too")
-- conditions: counts and statuses
local area2 = { id = "u", objects = {} }
check(rules.holds({ has = { coin = 2 } }, nil, ctx()) == false, "count condition fails")
p:give("coin"); p:give("coin")
check(rules.holds({ has = { coin = 2 } }, nil, ctx()), "count condition holds")
check(rules.holds({ status = { ["gate:1-2"] = "open" } }, nil, ctx()), "status condition holds")
check(not rules.holds({ status = { ["gate:1-2"] = "blocked" } }, nil, ctx()), "status condition fails")
-- captive: say then win
local cap = objects.add(area2, "captive", 5, 2, { tile = 75 })
log = {}
rules.fire("use", cap, ctx())
check(log[1] == "status done" and log[2]:match("^say") and log[3] == "win", "captive says then wins: " .. table.concat(log, ", "))
check(objects.blocks(world, cap), "captive still blocks when done")
-- enemy: statuses not kept in the world
local en = objects.new("enemy", "enemy:x:1", 6, 6)
log = {}
rules.fire("defeat", en, ctx())
check(log[1] == "status defeated" and log[2] == "drop coin 6 6", "enemy drops a coin")
check(world.status["enemy:x:1"] == nil, "enemy status not persisted")
-- in game: killing an enemy drops a coin on its tile
local e2 = stub.explore
local spawnArea
for k, c in pairs(world.gen.cells) do if c.enemies and c.enemies > 0 then spawnArea = "c" .. k break end end
e2:enter(spawnArea, 1, 1, "S")
local en2 = e2.enemies[1]
local count = #e2.enemies
en2.hp = 1
local ex, ey = en2.x, en2.y
e2:hitEnemy(en2, 1)
local it = Game.pickup.itemAt(e2.area, ex, ey)
check(#e2.enemies == count - 1 and it and it.item == "coin", "defeated enemy drops coin in game")
print(fails == 0 and "unit_rules: all passed" or ("unit_rules: " .. fails .. " failed"))
