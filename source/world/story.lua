-- The story roller (Rulebook Chapter 6, step 6 and Appendix B): what every
-- area holds. It runs on its own sub-seed of the world seed, so it never
-- shifts the map's random sequence (and the Room Scale Lab, which only
-- shows the map, keeps matching).
--
-- Fills in, per cell: chest (the item in its chest), enemies; and on the
-- world: keys[act] (the cell holding each act's key), sword, cellKey.

local rng <const> = Game.rng
local grid <const> = Game.grid

local story = {}

local SALT <const> = 7

function story.roll(gen)
	local r = rng.new(rng.derive(gen.seed, SALT))
	local cells, links = gen.cells, gen.links
	local farthest = Game.worldgen.farthest
	gen.keys = {}

	local function except(list, ...)
		local skip = { ... }
		return grid.filter(list, function(k)
			return not grid.contains(skip, k)
		end)
	end

	-- Act I: the shield at home, the key farthest from home
	cells[gen.start].chest = "shield"
	local rest = except(gen.actCells[1], gen.start)
	gen.keys[1] = farthest(r, rest, gen.start, links)
	-- Acts II and III: the key farthest from where you come in
	for act = 2, 3 do
		gen.keys[act] = farthest(r, gen.actCells[act], gen.gates[act - 1].to, links)
	end
	for act = 1, 3 do
		cells[gen.keys[act]].chest = "key"
	end
	gen.sword = rng.pick(r, except(gen.actCells[2], gen.keys[2]))
	cells[gen.sword].chest = "sword"
	-- Act IV: the dungeon key at the entrance, the cell key in the deepest
	-- other room
	cells[gen.entrance].chest = "key"
	gen.keys[4] = gen.entrance
	local rooms = except(gen.actCells[4], gen.entrance, gen.goal)
	gen.cellKey = farthest(r, rooms, gen.entrance, links)
	cells[gen.cellKey].chest = "cellKey"
	-- every other area: a heart
	for k, cell in pairs(cells) do
		if not cell.chest and k ~= gen.goal then
			cell.chest = "heart"
		end
	end

	-- enemies: none in towns and camps; in Act I only one, since you can
	-- only push them; the sword's guard is alone too (you get there without
	-- it); dungeon enemies sometimes
	for k = 0, Game.config.MAP * Game.config.MAP - 1 do
		local cell = cells[k]
		if cell.kind == "forest" or cell.kind == "ruins" then
			cell.enemies = 1 + (r() < 0.4 and 1 or 0)
			if cell.act == 1 or k == gen.sword then
				cell.enemies = 1
			end
		elseif cell.kind == "entrance" then
			cell.enemies = 1
		elseif cell.kind == "dungeon" and k ~= gen.goal then
			cell.enemies = r() < 0.7 and 1 or 0
		end
	end
	return gen
end

Game.storyRoller = story
