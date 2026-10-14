-- The 16px strip above the room: hearts, a slot for the shield and one for
-- the weapon (the item table's `slots`: the world's own tiles once found,
-- an empty frame until then), then every other carried item in the item
-- table's order (data/items.lua). A stack of more than one (keys, coins)
-- is followed by its count in 8px digit tiles.

local config <const> = Game.config
local gfx <const> = playdate.graphics

local hud = {}

local ICON <const> = 16
local DIGIT <const> = 8

local function drawCount(n, x, tiles, kits)
	local digits = kits.hud.digits
	if not digits or #digits < 10 then
		return x
	end
	for c in tostring(n):gmatch("%d") do
		tiles.draw(DIGIT, digits[tonumber(c) + 1], x, ICON - DIGIT)
		x = x + DIGIT
	end
	return x
end

function hud.draw(player, tiles, kits)
	local x = config.ORIGIN_X
	for i = 1, player.maxHearts do
		local tile = i <= player.hearts and kits.hud.heart[1] or kits.hud.heartEmpty[1]
		tiles.draw(ICON, tile, x, 0)
		x = x + ICON
	end
	x = x + ICON / 2
	local slotted = {}
	for _, id in ipairs(Game.items.slots or {}) do
		slotted[id] = true
		if player.items[id] and kits.items[id] and kits.items[id][1] then
			tiles.draw(ICON, Game.itemTile(id), x, 0)
		elseif kits.hud.slot and kits.hud.slot[1] then
			tiles.draw(ICON, kits.hud.slot[1], x, 0)
		else
			gfx.setColor(gfx.kColorWhite)
			gfx.drawRect(x + 1, 1, ICON - 2, ICON - 2)
		end
		x = x + ICON + 2
	end
	x = x + ICON / 2
	for _, id in ipairs(Game.items.order) do
		local n = player.items[id]
		if n and not slotted[id] and kits.items[id] and kits.items[id][1] then
			tiles.draw(ICON, Game.itemTile(id), x, 0)
			x = x + ICON
			if n > 1 then
				x = drawCount(n, x, tiles, kits)
			end
			x = x + 2
		end
	end
end

Game.hud = hud
