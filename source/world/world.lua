-- A running world: the generated map plus everything that changes while
-- you play (areas built so far, with their opened chests and dropped items,
-- which areas you've seen, object statuses, where you wake up).

local worldgen <const> = Game.worldgen
local config <const> = Game.config

local World = {}
World.__index = World

-- Builds the world for `seed`: the map (world/worldgen.lua), then what
-- each area holds (world/story.lua). Every seed gives a valid world.
function World.new(seed)
	local gen = Game.storyRoller.roll(worldgen.generate(seed))
	return setmetatable({
		seed = seed,
		gen = gen,
		areas = {},
		visited = {},
		status = {}, -- object id -> status (world/objects.lua)
		respawn = nil, -- { id, x, y }
	}, World)
end

function World:area(id)
	if not self.areas[id] then
		self.areas[id] = Game.area.build(self, id)
	end
	return self.areas[id]
end

-- The world cell next to k in direction dir.
function World:neighbor(k, dir)
	local d = Game.grid.DELTA[dir]
	return k + d[1] + d[2] * config.MAP
end

Game.World = World
