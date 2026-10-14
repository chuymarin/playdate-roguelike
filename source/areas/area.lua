-- Builds one area (a room-sized screen) on demand. Ids: "c<k>" is the
-- outdoor/dungeon area in world cell k, "h<k>" the room inside its
-- building (cell.inside), "u<k>" its lower level, down the stairs
-- (cell.below) and "a<k>" its upper level, up the stairs (cell.above; see
-- data/places.lua and world/story.lua). A level spread over from a
-- neighbor's has no stairs and no parent: you walk in through a passage.
--
-- Every area has its own random sequence, derived from the world seed and
-- its cell, so areas don't depend on each other or on visiting order. A
-- seed in config.SEEDS for its kind replaces that (handy for testing one
-- house or maze design everywhere).

local rng <const> = Game.rng
local layout <const> = Game.layout
local config <const> = Game.config

local area = {}

local SALT = { c = 1, h = 2, u = 3, a = 4 }

function area.build(world, id)
	local prefix, k = id:sub(1, 1), tonumber(id:sub(2))
	local cell = world.gen.cells[k]
	local kind = cell.kind
	local parent = nil
	if prefix == "h" then
		kind = cell.inside or "house"
		parent = world:area("c" .. k)
	elseif prefix == "u" then
		kind = cell.below.kind
		if cell.below.from then
			parent = world:area((cell.below.from == "inside" and "h" or "c") .. k)
		end
	elseif prefix == "a" then
		kind = cell.above.kind
		if cell.above.from then
			parent = world:area("c" .. k)
		end
	end
	local seed = config.SEEDS[kind] or rng.derive(world.seed, k, SALT[prefix])
	local a = layout.new(id, kind)
	a.cell = cell
	a.seed = seed
	local ctx = {
		world = world,
		cell = cell,
		r = rng.new(seed),
		kits = Game.kits,
		parent = parent,
	}
	Game.areaKinds[kind].build(a, ctx)
	return a
end

Game.area = area
