-- Enemies: step one tile at a time. Within CHASE_RANGE tiles of the player
-- they walk toward them; otherwise they wander (sometimes standing still).
-- Walking into the player hurts them, unless the player's shield is up and
-- facing the enemy, which pushes the enemy back instead.

local gfx <const> = playdate.graphics
local grid <const> = Game.grid
local config <const> = Game.config

local Enemy = {}
Enemy.__index = Enemy

local CHASE_RANGE <const> = 4
local CHASE_FRAMES <const> = 14
local WANDER_FRAMES <const> = 24
local IDLE_CHANCE <const> = 0.3
local STUN_FRAMES <const> = 20

function Enemy.new(spawn)
	return setmetatable({
		x = spawn.x,
		y = spawn.y,
		tile = spawn.tile,
		hp = spawn.hp,
		cooldown = math.random(10, 30),
		stun = 0,
		flash = 0,
		flipX = false,
	}, Enemy)
end

function Enemy:stunFor(frames)
	self.stun = frames or STUN_FRAMES
end

-- room: { canEnter(x, y, enemy), player, attack(enemy, dir) }
function Enemy:update(room)
	if self.flash > 0 then
		self.flash = self.flash - 1
	end
	if self.stun > 0 then
		self.stun = self.stun - 1
		return
	end
	self.cooldown = self.cooldown - 1
	if self.cooldown > 0 then
		return
	end
	local p = room.player
	local dist = math.abs(p.x - self.x) + math.abs(p.y - self.y)
	local chasing = dist <= CHASE_RANGE
	self.cooldown = (chasing and CHASE_FRAMES or WANDER_FRAMES) + math.random(0, 6)
	if not chasing and math.random() < IDLE_CHANCE then
		return
	end

	local options = {}
	for _, d in ipairs(grid.DIRS) do
		local nx, ny = self.x + d[1], self.y + d[2]
		if (nx == p.x and ny == p.y) or room:canEnter(nx, ny, self) then
			local score = math.abs(p.x - nx) + math.abs(p.y - ny)
			options[#options + 1] = { nx, ny, d[3], score }
		end
	end
	if #options == 0 then
		return
	end
	local choice
	if chasing then
		local best = math.huge
		for _, o in ipairs(options) do
			best = math.min(best, o[4])
		end
		local bests = {}
		for _, o in ipairs(options) do
			if o[4] == best then
				bests[#bests + 1] = o
			end
		end
		choice = bests[math.random(#bests)]
	else
		choice = options[math.random(#options)]
	end

	if choice[3] == "E" then
		self.flipX = false
	elseif choice[3] == "W" then
		self.flipX = true
	end
	if choice[1] == p.x and choice[2] == p.y then
		room:attack(self, choice[3])
	else
		self.x, self.y = choice[1], choice[2]
	end
end

function Enemy:draw(tiles, toScreen)
	if self.flash > 0 and (self.flash // 2) % 2 == 1 then
		return
	end
	local px, py = toScreen(self.x, self.y)
	tiles.draw(config.TILE, self.tile, px, py, self.flipX and gfx.kImageFlippedX or gfx.kImageUnflipped)
end

Game.Enemy = Enemy
