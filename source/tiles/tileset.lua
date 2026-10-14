-- The tile image tables built by tools/build_kits.py: the whole 1-Bit Pack
-- sheet at 8px (map screen), 16px (HUD) and 32px (rooms). Sheet
-- tile n (from 0, as kits.lua numbers them) is image n + 1 in each table.

local gfx <const> = playdate.graphics

local tables = {
	[8] = gfx.imagetable.new("images/tiles8"),
	[16] = gfx.imagetable.new("images/tiles16"),
	[32] = gfx.imagetable.new("images/tiles32"),
}

local tiles = {}

function tiles.get(size, index)
	return tables[size]:getImage(index + 1)
end

function tiles.draw(size, index, x, y, flip)
	local image = tables[size]:getImage(index + 1)
	if image then
		image:draw(x, y, flip or gfx.kImageUnflipped)
	end
end

-- Draws a tile on a black square: for the hero, enemies, NPCs and items on
-- the ground, so they don't blend into the floor or a door under them
-- (tiles are see-through around the drawing). Quick, passing things (the
-- sword, the shield, hit effects) use tiles.draw.
function tiles.drawSolid(size, index, x, y, flip)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(x, y, size, size)
	tiles.draw(size, index, x, y, flip)
end

Game.tiles = tiles
