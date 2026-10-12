-- NPCs stand still and turn around now and then (a horizontal flip every
-- 0.7-2.5 s) so they look alive. Facing them and pressing Ⓐ shows their lines.

local gfx <const> = playdate.graphics
local config <const> = Game.config

local Npc = {}
Npc.__index = Npc

local TURN_MIN_FRAMES <const> = 20
local TURN_MAX_FRAMES <const> = 75

function Npc.new(def)
	return setmetatable({
		def = def,
		x = def.x,
		y = def.y,
		flipX = false,
		turnIn = math.random(TURN_MIN_FRAMES, TURN_MAX_FRAMES),
	}, Npc)
end

function Npc:update()
	self.turnIn = self.turnIn - 1
	if self.turnIn <= 0 then
		self.flipX = not self.flipX
		self.turnIn = math.random(TURN_MIN_FRAMES, TURN_MAX_FRAMES)
	end
end

function Npc:draw(tiles, toScreen)
	local px, py = toScreen(self.x, self.y)
	tiles.draw(config.TILE, self.def.tile, px, py, self.flipX and gfx.kImageFlippedX or gfx.kImageUnflipped)
end

Game.Npc = Npc
