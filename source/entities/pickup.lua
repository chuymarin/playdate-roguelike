-- Items on the ground (Rulebook 3.3). An opened chest (or a defeated enemy)
-- drops its item on its tile, and walking onto an item picks it up.
--
-- Items live in the area (area.items), so a dropped item stays where it
-- fell until you take it.

local config <const> = Game.config

local pickup = {}

function pickup.itemAt(area, x, y)
	for i, it in ipairs(area.items) do
		if it.x == x and it.y == y then
			return it, i
		end
	end
	return nil
end

function pickup.drop(area, item, x, y)
	area.items[#area.items + 1] = { x = x, y = y, item = item }
end

-- Gives the item to the player and removes it from the area. Returns the
-- item's definition (data/items.lua), which says how to announce it.
function pickup.collect(area, index, player)
	local it = table.remove(area.items, index)
	local def = Game.items[it.item]
	if def.heart then
		player.maxHearts = player.maxHearts + 1
		player.hearts = player.maxHearts
	else
		player:give(it.item)
	end
	return def
end

function pickup.draw(area, tiles, kits, toScreen, size)
	size = size or config.TILE
	for _, it in ipairs(area.items) do
		local px, py = toScreen(it.x, it.y)
		tiles.drawSolid(size, Game.itemTile(it.item), px, py)
	end
end

Game.pickup = pickup
