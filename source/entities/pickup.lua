-- Chests and items. A chest doesn't show what it holds: facing it and
-- pressing Ⓐ makes it disappear and leaves its item on that tile, and
-- walking onto an item picks it up.
--
-- Chests and items live in the area (area.chests / area.items), so an
-- opened chest stays open and a dropped item stays where it was.

local config <const> = Game.config

local pickup = {}

function pickup.chestAt(area, x, y)
	for _, c in ipairs(area.chests) do
		if not c.opened and c.x == x and c.y == y then
			return c
		end
	end
	return nil
end

function pickup.itemAt(area, x, y)
	for i, it in ipairs(area.items) do
		if it.x == x and it.y == y then
			return it, i
		end
	end
	return nil
end

function pickup.open(area, chest)
	chest.opened = true
	area.items[#area.items + 1] = { x = chest.x, y = chest.y, item = chest.contents }
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
	for _, c in ipairs(area.chests) do
		if not c.opened then
			local px, py = toScreen(c.x, c.y)
			tiles.draw(size, kits.items.chest[1], px, py)
		end
	end
	for _, it in ipairs(area.items) do
		local px, py = toScreen(it.x, it.y)
		tiles.draw(size, kits.items[it.item][1], px, py)
	end
end

Game.pickup = pickup
