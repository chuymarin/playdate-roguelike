-- A running world: the generated map plus everything that changes while
-- you play (areas built so far, with their opened chests and dropped items,
-- which areas you've seen, object statuses, where you wake up).

local worldgen <const> = Game.worldgen
local config <const> = Game.config

local World = {}
World.__index = World

local LOOKS_SALT <const> = 11

-- Each item's look for this world: one tile from its Kit Builder slot,
-- rolled on its own sub-seed so the map and story don't shift.
local function rollLooks(seed)
	local r = Game.rng.new(Game.rng.derive(seed, LOOKS_SALT))
	local ids = {}
	for id in pairs(Game.kits.items) do
		ids[#ids + 1] = id
	end
	table.sort(ids) -- pairs' order isn't stable; the same seed must give the same looks
	local looks = {}
	for _, id in ipairs(ids) do
		local tiles = Game.kits.items[id]
		if #tiles > 0 then
			looks[id] = Game.rng.pick(r, tiles)
		end
	end
	return looks
end

-- The tile an item is drawn with in the current world.
function Game.itemTile(id)
	return Game.looks and Game.looks[id] or Game.kits.items[id][1]
end

-- Builds the world for `seed`: the map (world/worldgen.lua), then what
-- each area holds (world/story.lua). Every seed gives a valid world.
function World.new(seed)
	local gen = Game.storyRoller.roll(worldgen.generate(seed))
	Game.looks = rollLooks(seed)
	return setmetatable({
		seed = seed,
		gen = gen,
		areas = {},
		visited = {},
		actsSeen = {}, -- acts whose region you've walked into (for the banner)
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
