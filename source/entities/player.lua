-- The player: position in the room, facing, hearts and what they carry
-- (items[id] = count, see data/items.lua).
--
-- The sword (Ⓐ) appears for a few frames in the tile in front of the
-- player, turned to point your way: facing left or up it's mirrored, and
-- facing down it's mirrored and flipped upside down.
-- The shield (Ⓑ) shows in front of the player the same way and pushes an
-- enemy there one tile back.
-- Timings: config/settings.json, read each time (a difficulty can change
-- them, data/difficulty.lua).

local gfx <const> = playdate.graphics
local grid <const> = Game.grid
local config <const> = Game.config

local Player = {}
Player.__index = Player

local SWORD_FLIPS <const> = {
	E = gfx.kImageUnflipped,
	W = gfx.kImageFlippedX,
	N = gfx.kImageFlippedX,
	S = gfx.kImageFlippedXY,
}

function Player.new(tile)
	return setmetatable({
		tile = tile,
		x = 1,
		y = 1,
		facing = "S",
		flipX = false,
		hearts = config.MAX_HEARTS,
		maxHearts = config.MAX_HEARTS,
		items = {},
		invulnerable = 0,
		swing = 0,
		guard = 0,
	}, Player)
end

-- True when carrying at least n (default 1) of item id.
function Player:has(id, n)
	return (self.items[id] or 0) >= (n or 1)
end

function Player:give(id)
	self.items[id] = (self.items[id] or 0) + 1
end

-- Removes one; returns false if there was none.
function Player:take(id)
	local n = self.items[id] or 0
	if n == 0 then
		return false
	end
	self.items[id] = n > 1 and n - 1 or nil
	return true
end

-- True when a carried item gives this ability ("swing", "guard").
function Player:can(ability)
	for id in pairs(self.items) do
		local def = Game.items[id]
		if def and def.ability == ability then
			return true
		end
	end
	return false
end

function Player:face(dir)
	self.facing = dir
	if dir == "W" then
		self.flipX = true
	elseif dir == "E" then
		self.flipX = false
	end
end

function Player:front()
	local d = grid.DELTA[self.facing]
	return self.x + d[1], self.y + d[2]
end

function Player:busy()
	return self.swing > 0 or self.guard > 0
end

function Player:startSwing()
	self.swing = config.SWING_FRAMES
end

function Player:startGuard()
	self.guard = config.GUARD_FRAMES
end

-- Returns true if the hit landed (false while still blinking from the last one).
function Player:hurt()
	if self.invulnerable > 0 then
		return false
	end
	self.hearts = self.hearts - 1
	self.invulnerable = config.HURT_FRAMES
	return true
end

function Player:tick()
	if self.swing > 0 then
		self.swing = self.swing - 1
	end
	if self.guard > 0 then
		self.guard = self.guard - 1
	end
	if self.invulnerable > 0 then
		self.invulnerable = self.invulnerable - 1
	end
end

function Player:draw(tiles, kits, toScreen)
	local px, py = toScreen(self.x, self.y)
	if self.invulnerable == 0 or (self.invulnerable // 3) % 2 == 0 then
		tiles.drawSolid(config.TILE, self.tile, px, py, self.flipX and gfx.kImageFlippedX or gfx.kImageUnflipped)
	end
	local fx, fy = self:front()
	local sx, sy = toScreen(fx, fy)
	if self.swing > 0 then
		tiles.draw(config.TILE, Game.itemTile("sword"), sx, sy, SWORD_FLIPS[self.facing])
	elseif self.guard > 0 then
		tiles.draw(config.TILE, Game.itemTile("shield"), sx, sy, self.flipX and gfx.kImageFlippedX or gfx.kImageUnflipped)
	end
end

Game.Player = Player
