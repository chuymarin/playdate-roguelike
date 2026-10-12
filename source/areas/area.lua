-- Builds one area (a room-sized screen) on demand. Ids: "c<k>" is the
-- outdoor/dungeon area in world cell k, "h<k>" the inside of that cell's
-- house.
--
-- Every area has its own random sequence, derived from the world seed and
-- its cell, so areas don't depend on each other or on visiting order. A
-- seed in config.SEEDS for its kind replaces that (handy for testing one
-- house or maze design everywhere).

local rng <const> = Game.rng
local layout <const> = Game.layout
local config <const> = Game.config

local area = {}

local SALT = { c = 1, h = 2 }

function area.build(world, id)
	local prefix, k = id:sub(1, 1), tonumber(id:sub(2))
	local cell = world.gen.cells[k]
	local kind = prefix == "h" and "house" or cell.kind
	local seed = config.SEEDS[kind] or rng.derive(world.seed, k, SALT[prefix])
	local a = layout.new(id, kind)
	a.cell = cell
	a.seed = seed
	local ctx = {
		world = world,
		cell = cell,
		r = rng.new(seed),
		kits = Game.kits,
		parent = prefix == "h" and world:area("c" .. k) or nil,
	}
	Game.areaKinds[kind].build(a, ctx)
	return a
end

Game.area = area
