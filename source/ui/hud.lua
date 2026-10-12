-- The 16px strip above the room: hearts, then the key, shield and sword
-- once you have them (the cell key too). Icons are the tiles at 16px.

local config <const> = Game.config

local hud = {}

local ICON <const> = 16

function hud.draw(player, tiles, kits)
	local x = config.ORIGIN_X
	for i = 1, player.maxHearts do
		local tile = i <= player.hearts and kits.hud.heart[1] or kits.hud.heartEmpty[1]
		tiles.draw(ICON, tile, x, 0)
		x = x + ICON
	end
	x = x + ICON / 2
	for _ = 1, player.keys do
		tiles.draw(ICON, kits.items.key[1], x, 0)
		x = x + ICON
	end
	if player.cellKey then
		tiles.draw(ICON, kits.items.cellKey[1], x, 0)
		x = x + ICON
	end
	if player.hasShield then
		tiles.draw(ICON, kits.items.shield[1], x, 0)
		x = x + ICON
	end
	if player.hasSword then
		tiles.draw(ICON, kits.items.sword[1], x, 0)
	end
end

Game.hud = hud
