-- Inventory checks: has/give/take/can, table-driven pickup, quiet coins, HUD counts.
--   lua unit_items.lua <source>
SRC = arg[1]
stub = dofile("stub.lua")
stub.boot()
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. msg) end end
local e = stub.explore
local p, area = e.player, e.area
check(next(p.items) == nil, "starts with nothing")
check(not p:can("swing") and not p:can("guard"), "no abilities at start")
p:give("key"); p:give("key")
check(p:has("key", 2) and not p:has("key", 3), "two keys")
check(p:take("key") and p:has("key") and p:take("key") and not p:has("key") and p.items.key == nil, "take keys down to nil")
check(not p:take("key"), "take with none fails")
-- pickups through the table
for _, it in ipairs({ "shield", "sword", "coin", "coin", "coin", "heart", "cellKey" }) do
  area.items[#area.items + 1] = { x = 1, y = 1, item = it }
  local def = Game.pickup.collect(area, #area.items, p)
  check(def == Game.items[it], "collect returns def for " .. it)
end
check(p:can("swing") and p:can("guard"), "abilities from items")
check(p.items.coin == 3, "3 coins")
check(p.maxHearts == Game.config.MAX_HEARTS + 1 and p.hearts == p.maxHearts, "heart container")
check(p.items.heart == nil, "heart not carried")
-- coin pickup by walking: quiet (toast + coin sound, no dialogue)
e.dialogue = nil
local tx, ty
for _, d in ipairs(Game.grid.DIRS) do
  local x, y = p.x + d[1], p.y + d[2]
  if Game.layout.inside(area, x, y) and not area.solid[y][x] and not e:portalAt(x, y) and not e:objectAt(x, y) then tx, ty = x, y; break end
end
area.items[#area.items + 1] = { x = tx, y = ty, item = "coin" }
local before = #stub.sounds
e:tryMove(Game.grid.cellDir and (tx > p.x and "E" or tx < p.x and "W" or ty > p.y and "S" or "N"))
check(p.items.coin == 4, "walked onto coin")
check(e.dialogue == nil and e.toastText == Game.text.coin, "coin is quiet with toast")
check(stub.sounds[#stub.sounds] == "sounds/coin", "coin sound")
-- HUD draws the coin count as 8px digits
local hudLog = os.tmpname(); stub.frame(); stub.snapshot(hudLog)
local hud = {}
for line in io.lines(hudLog) do local s, i, x, y = line:match("^T (%d+) (%d+) (%d+) (%d+)") if s and tonumber(y) < 16 then hud[#hud + 1] = { tonumber(s), tonumber(i), tonumber(x), tonumber(y) } end end
local digit4 = false
for _, h in ipairs(hud) do if h[1] == 8 and h[2] == Game.kits.hud.digits[5] then digit4 = true end end
check(digit4, "HUD shows coin count 4")
local coinIcon = false
for _, h in ipairs(hud) do if h[1] == 16 and h[2] == Game.kits.items.coin[1] then coinIcon = true end end
check(coinIcon, "HUD shows coin icon")
print(fails == 0 and "unit_items: all passed" or ("unit_items: " .. fails .. " failed"))
