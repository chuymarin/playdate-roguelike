-- The story roller (Rulebook Chapter 6, step 6): what every area holds,
-- read from the tables in data/story.lua. It runs on its own sub-seed of the
-- world seed, so it never shifts the map's random sequence (the Room Scale
-- Lab, which only shows the map, keeps matching).
--
-- Fills in, per cell: chest (the item in its chest) and enemies; on the
-- world: placed[item] = { cells holding it }, and for the villagers' hints
-- keys[act] (the cell with each act's key), sword, cellKey.

local rng <const> = Game.rng
local grid <const> = Game.grid

local story = {}

local SALT <const> = 7

-- Where you come into each act's region: home, then each gate's far side.
local function entry(gen, act)
	if act == 1 then
		return gen.start
	end
	return gen.gates[act - 1].to
end

-- Places one act's chests. Errors name the table row, for the check tool.
local function placeAct(r, gen, act, rows)
	local cells, links = gen.cells, gen.links
	local open = grid.filter(gen.actCells[act], function(k)
		return k ~= gen.goal
	end)
	local function take(k, item)
		cells[k].chest = item
		gen.placed[item] = gen.placed[item] or {}
		table.insert(gen.placed[item], k)
		open = grid.filter(open, function(j)
			return j ~= k
		end)
	end
	for i, row in ipairs(rows) do
		local where = ("act %d chest %d (%s)"):format(act, i, tostring(row.item))
		assert(Game.items[row.item], where .. ": no such item")
		if row.at == "rest" then
			for _, k in ipairs(open) do
				take(k, row.item)
			end
		else
			local k
			if row.at == "home" then
				k = gen.start
			elseif row.at == "entrance" then
				k = gen.entrance
			elseif row.at == "farthest" then
				k = #open > 0 and Game.worldgen.farthest(r, open, entry(gen, act), links) or nil
			elseif row.at == "any" then
				k = rng.pick(r, open)
			else
				error(where .. ": unknown place " .. tostring(row.at))
			end
			assert(k and grid.contains(open, k), where .. ": no area left for it")
			take(k, row.item)
		end
	end
end

function story.roll(gen)
	local tables = Game.story
	local r = rng.new(rng.derive(gen.seed, SALT))
	local cells = gen.cells
	gen.placed = {}

	for act = 1, 4 do
		placeAct(r, gen, act, tables.acts[act].chests or {})
	end
	gen.keys = {}
	for _, k in ipairs(gen.placed.key or {}) do
		gen.keys[cells[k].act] = k
	end
	gen.sword = gen.placed.sword and gen.placed.sword[1]
	gen.cellKey = gen.placed.cellKey and gen.placed.cellKey[1]

	-- enemies (never in the captive's room)
	local alone = {}
	for _, item in ipairs(tables.alone or {}) do
		alone[item] = true
	end
	for k = 0, Game.config.MAP * Game.config.MAP - 1 do
		local cell = cells[k]
		local e = tables.enemies[cell.kind]
		cell.enemies = 0
		if e and k ~= gen.goal then
			local n = e.min
			for _ = e.min + 1, e.max do
				if r() < (e.chance or 0) then
					n = n + 1
				end
			end
			if cell.act == 1 then
				n = math.min(n, tables.firstAct or n)
			end
			if cell.chest and alone[cell.chest] then
				n = math.min(n, 1)
			end
			cell.enemies = n
		end
	end
	return gen
end

Game.storyRoller = story
