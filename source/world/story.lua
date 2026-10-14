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
local LEVELS_SALT <const> = 15
local GROW_CHANCE <const> = 0.6 -- each extra cell a level spreads over

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

-- Spreads the level `layer` ("below" / "above") of cell k0 over cells
-- linked to it in the same act's piece (so the level has part of the
-- piece's shape), up to spec.spread more, of the kinds in spec.over, never
-- the entrance or the captive's room or a cell that has that level
-- already. A spread-to cell has no way there of its own: you walk in from
-- k0's level, through passages along the piece's links (cell.underLinks
-- below, cell.overLinks above).
local function grow(gen, r, k0, layer, spec)
	local MAP <const> = Game.config.MAP
	local cells = gen.cells
	local act = cells[k0].act
	local over = {}
	for _, kind in ipairs(spec.over or {}) do
		over[kind] = true
	end
	local group = { k0 }
	local linksKey = layer == "below" and "underLinks" or "overLinks"
	for _ = 1, spec.spread or 0 do
		if r() >= GROW_CHANCE then
			break
		end
		local options = {}
		for _, k in ipairs(group) do
			for _, d in ipairs(grid.DIRS) do
				local n = k + d[1] + d[2] * MAP
				local other = cells[k].links[d[3]] and cells[n]
				if other and other.act == act and over[other.kind] and not other[layer] and n ~= gen.goal and other.role ~= "entrance" then
					options[#options + 1] = { k, n, d[3] }
				end
			end
		end
		if #options == 0 then
			break
		end
		local o = rng.pick(r, options)
		local other = cells[o[2]]
		other[layer] = { kind = spec.kind, root = k0 }
		cells[o[1]][linksKey][o[3]] = {}
		other[linksKey][grid.OPP[o[3]]] = {}
		group[#group + 1] = o[2]
	end
end

-- Each area's features (data/places.lua), on its own sub-seed: its inside
-- (cell.inside, insideEnemies), its lower level (cell.below = { kind,
-- from, cover }, belowEnemies), its upper level (cell.above = { kind,
-- from }, aboveEnemies), each level maybe spread over its neighbors
-- (grow), where its chest is (cell.chestAt), then the passages between
-- neighboring lower levels (cell.underLinks[dir]).
local function rollFeatures(gen, tables, alone)
	local places = Game.places
	local r = rng.new(rng.derive(gen.seed, FEATURES_SALT))
	local MAP <const> = Game.config.MAP
	for k = 0, MAP * MAP - 1 do
		local cell = gen.cells[k]
		local f = places.features[cell.kind]
		cell.underLinks = {}
		cell.overLinks = {}
		if f then
			if f.inside and r() < (f.insideChance or 1) then
				cell.inside = f.inside
			end
			if f.below and r() < (f.below.chance or 1) and (f.below.from ~= "inside" or cell.inside) then
				cell.below = { kind = f.below.kind, from = f.below.from or "outside", cover = f.below.cover }
			end
			local notGoal = k ~= gen.goal
			cell.insideEnemies = cell.inside and notGoal and enemyCount(r, tables, cell.inside, cell, alone) or 0
			cell.belowEnemies = cell.below and notGoal and enemyCount(r, tables, cell.below.kind, cell, alone) or 0
		end
	end
	-- upper levels, then every level spreads (its own sub-seed: the rolls
	-- above stay as they were)
	local r2 = rng.new(rng.derive(gen.seed, LEVELS_SALT))
	for k = 0, MAP * MAP - 1 do
		local cell = gen.cells[k]
		local f = places.features[cell.kind]
		if f and f.above and k ~= gen.goal and r2() < (f.above.chance or 1) then
			cell.above = { kind = f.above.kind, from = "outside" }
		end
	end
	for k = 0, MAP * MAP - 1 do
		local cell = gen.cells[k]
		local f = places.features[cell.kind]
		for _, layer in ipairs({ "below", "above" }) do
			if f and f[layer] and cell[layer] and cell[layer].from then
				grow(gen, r2, k, layer, f[layer])
			end
		end
	end
	for k = 0, MAP * MAP - 1 do
		local cell = gen.cells[k]
		local notGoal = k ~= gen.goal
		if cell.below and cell.below.from == nil then
			cell.belowEnemies = notGoal and enemyCount(r2, tables, cell.below.kind, cell, alone) or 0
		end
		cell.aboveEnemies = cell.above and notGoal and enemyCount(r2, tables, cell.above.kind, cell, alone) or 0
	end
	-- where each chest goes: only into a level this area has its own way
	-- to (a spread-to level is found from its neighbor)
	for k = 0, MAP * MAP - 1 do
		local cell = gen.cells[k]
		local f = places.features[cell.kind]
		if f and cell.chest and cell.role ~= "start" and f.chest and r2() < (f.chestChance or 1) then
			local own = function(layer)
				return cell[layer] and cell[layer].from ~= nil
			end
			local at = f.chest
			if at == "deepest" then
				at = own("below") and "below" or "inside"
			elseif at == "highest" then
				at = own("above") and "above" or nil
			end
			if (at == "inside" and cell.inside) or (at == "below" and own("below")) or (at == "above" and own("above")) then
				cell.chestAt = at
			end
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
				if cell.below and other.below and cell.act == other.act and not cell.underLinks[d[3]] and r() < pairChance(cell.kind, other.kind) then
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
