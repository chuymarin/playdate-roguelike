-- The story roller (Rulebook Chapter 6, step 6): what every area holds,
-- read from the tables in data/story.lua. It runs on its own sub-seed of the
-- world seed, so it never shifts the map's random sequence (the Room Scale
-- Lab, which only shows the map, keeps matching).
--
-- Fills in, per cell: chest (the item in its chest), enemies, and its
-- features (see rollFeatures); on the
-- world: placed[item] = { cells holding it }, and for the villagers' hints
-- keys[act] (the cell with each act's key), sword, cellKey.

local rng <const> = Game.rng
local grid <const> = Game.grid

local story = {}

local SALT <const> = 7
local FEATURES_SALT <const> = 14

-- How many enemies a kind of area gets (the story's enemy table), capped in
-- Act I and next to an item that wants to be alone.
local function enemyCount(r, tables, kind, cell, alone)
	local e = tables.enemies[kind]
	if not e then
		return 0
	end
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
	return n
end

-- Each area's features (data/places.lua), on its own sub-seed: its inside
-- (cell.inside, insideEnemies), its lower level (cell.below = { kind,
-- from, cover }, belowEnemies), where its chest is (cell.chestAt), then the
-- passages between neighboring lower levels (cell.underLinks[dir]).
local function rollFeatures(gen, tables, alone)
	local places = Game.places
	local r = rng.new(rng.derive(gen.seed, FEATURES_SALT))
	local MAP <const> = Game.config.MAP
	for k = 0, MAP * MAP - 1 do
		local cell = gen.cells[k]
		local f = places.features[cell.kind]
		cell.underLinks = {}
		if f then
			if f.inside and r() < (f.insideChance or 1) then
				cell.inside = f.inside
			end
			if f.below and r() < (f.below.chance or 1) and (f.below.from ~= "inside" or cell.inside) then
				cell.below = { kind = f.below.kind, from = f.below.from or "outside", cover = f.below.cover }
			end
			if cell.chest and cell.role ~= "start" and f.chest then
				local at = f.chest
				if at == "deepest" then
					at = cell.below and "below" or "inside"
				end
				if (at == "inside" and cell.inside) or (at == "below" and cell.below) then
					cell.chestAt = at
				end
			end
			local notGoal = k ~= gen.goal
			cell.insideEnemies = cell.inside and notGoal and enemyCount(r, tables, cell.inside, cell, alone) or 0
			cell.belowEnemies = cell.below and notGoal and enemyCount(r, tables, cell.below.kind, cell, alone) or 0
		end
	end
	-- passages: neighbors in the same act, both with stairs down, a listed pair
	local function pairChance(a, b)
		for _, c in ipairs(places.connections or {}) do
			local p = c.between or c
			if (p[1] == a and p[2] == b) or (p[1] == b and p[2] == a) then
				return c.chance or 1
			end
		end
		return 0
	end
	for k = 0, MAP * MAP - 1 do
		local cell = gen.cells[k]
		for _, d in ipairs({ { 1, 0, "E", "W" }, { 0, 1, "S", "N" } }) do
			local x, y = cell.x + d[1], cell.y + d[2]
			if x < MAP and y < MAP then
				local other = gen.cells[y * MAP + x]
				if cell.below and other.below and cell.act == other.act and r() < pairChance(cell.kind, other.kind) then
					-- a hidden passage: behind a web between caves, rubble elsewhere
					local link = {}
					if r() < (places.hiddenPassages or 0) then
						link.covered = (cell.below.kind == "cave" or other.below.kind == "cave") and "web" or "rubble"
					end
					cell.underLinks[d[3]] = link
					other.underLinks[d[4]] = link
				end
			end
		end
	end
end

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
		cell.enemies = k ~= gen.goal and enemyCount(r, tables, cell.kind, cell, alone) or 0
	end
	rollFeatures(gen, tables, alone)
	return gen
end

Game.storyRoller = story
