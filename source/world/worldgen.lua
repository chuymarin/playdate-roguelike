-- Builds the world map (Rulebook Chapter 2 and Chapter 6, steps 1-5): the
-- 4x4 map cut into four tetromino pieces, one per act, joined by gates.
--
-- 1. Cut the map: one of the 117 ways to tile 4x4 with tetrominoes
--    (I, O, T, L, J, S, Z in every rotation and mirror), found once by
--    backtracking. T pieces always come in pairs.
-- 2. Order the acts so each piece touches the next one.
-- 3. Act IV's entrance: a cell of the last piece next to Act III whose
--    removal leaves the other three connected (an end of the piece).
-- 4. Link the areas of each piece: every neighbor pair inside it, except an
--    O, which is a loop or a U (Act IV's O is always a U, with the entrance
--    at one end, so the entrance has a single door into the dungeon).
-- 5. Gates: one shared side between each act and the next (Act III's gate
--    leads into the entrance). No other links between pieces.
-- 6. Kinds: the start town in Act I (the cell farthest from Act I's gate),
--    the entrance and 3 dungeon rooms in Act IV (the captive in the
--    deepest), the rest rolled per act from data/story.lua.
--
-- The chests (what each area holds) are rolled by world/story.lua.
-- Same algorithm and random sequence as the Room Scale Lab artifact.

local grid <const> = Game.grid
local rng <const> = Game.rng
local config <const> = Game.config

local worldgen = {}

local MAP <const> = config.MAP

local function nbrs(k)
	return grid.cellNeighbors(k, MAP)
end

-- ---------- the 117 tilings ----------

-- Each base shape's cells; rotations are generated, duplicates dropped.
local BASE_SHAPES = {
	{ "I", { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 } } },
	{ "O", { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } },
	{ "T", { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 1, 1 } } },
	{ "L", { { 0, 0 }, { 0, 1 }, { 0, 2 }, { 1, 2 } } },
	{ "J", { { 1, 0 }, { 1, 1 }, { 1, 2 }, { 0, 2 } } },
	{ "S", { { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } } },
	{ "Z", { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } } },
}

-- Cells sorted top to bottom, left to right, moved so the first is (0, 0).
local function normalize(cells)
	local out = {}
	for i, c in ipairs(cells) do
		out[i] = { c[1], c[2] }
	end
	table.sort(out, function(a, b)
		if a[2] ~= b[2] then
			return a[2] < b[2]
		end
		return a[1] < b[1]
	end)
	local ox, oy = out[1][1], out[1][2]
	for _, c in ipairs(out) do
		c[1], c[2] = c[1] - ox, c[2] - oy
	end
	return out
end

local function shapeKey(cells)
	local parts = {}
	for _, c in ipairs(cells) do
		parts[#parts + 1] = c[1] .. "," .. c[2]
	end
	return table.concat(parts, ";")
end

-- The 19 fixed tetrominoes: { name, cells } in a fixed order.
local function fixedShapes()
	local out = {}
	for _, base in ipairs(BASE_SHAPES) do
		local seen = {}
		local cur = base[2]
		for _ = 1, 4 do
			local n = normalize(cur)
			local key = shapeKey(n)
			if not seen[key] then
				seen[key] = true
				out[#out + 1] = { base[1], n }
			end
			local rotated = {}
			for i, c in ipairs(cur) do
				rotated[i] = { -c[2], c[1] }
			end
			cur = rotated
		end
	end
	return out
end

-- Every tiling: { piece = {[k] = 1..4}, shapes = { "I", "T", ... } }, in the
-- order a depth-first search finds them (fill the first empty cell, trying
-- shapes in fixedShapes() order).
local function findTilings()
	local shapes = fixedShapes()
	local board, names, out = {}, {}, {}
	local function rec()
		local first = nil
		for k = 0, MAP * MAP - 1 do
			if not board[k] then
				first = k
				break
			end
		end
		if not first then
			local piece = {}
			for k = 0, MAP * MAP - 1 do
				piece[k] = board[k]
			end
			out[#out + 1] = { piece = piece, shapes = { table.unpack(names) } }
			return
		end
		local x0, y0 = first % MAP, first // MAP
		for _, shape in ipairs(shapes) do
			local fits = true
			for _, c in ipairs(shape[2]) do
				local x, y = x0 + c[1], y0 + c[2]
				if x < 0 or y < 0 or x >= MAP or y >= MAP or board[y * MAP + x] then
					fits = false
					break
				end
			end
			if fits then
				names[#names + 1] = shape[1]
				for _, c in ipairs(shape[2]) do
					board[(y0 + c[2]) * MAP + x0 + c[1]] = #names
				end
				rec()
				for _, c in ipairs(shape[2]) do
					board[(y0 + c[2]) * MAP + x0 + c[1]] = nil
				end
				names[#names] = nil
			end
		end
	end
	rec()
	return out
end

worldgen.TILINGS = findTilings()

-- ---------- helpers ----------

local function touches(piece, a, b)
	for k = 0, MAP * MAP - 1 do
		if piece[k] == a then
			for _, n in ipairs(nbrs(k)) do
				if piece[n] == b then
					return true
				end
			end
		end
	end
	return false
end

-- The cells of Act IV's piece that can be its entrance: next to Act III, and
-- the other three stay connected without it (an end of the piece).
local function entranceOptions(piece, order)
	local out = {}
	for k = 0, MAP * MAP - 1 do
		if piece[k] == order[4] then
			local nextToIII = false
			for _, n in ipairs(nbrs(k)) do
				if piece[n] == order[3] then
					nextToIII = true
				end
			end
			if nextToIII then
				local rest = grid.set()
				for j = 0, MAP * MAP - 1 do
					if piece[j] == order[4] and j ~= k then
						rest:add(j)
					end
				end
				if grid.connected(rest, MAP) then
					out[#out + 1] = k
				end
			end
		end
	end
	return out
end

-- Orders of the 4 pieces where each touches the next and Act IV has an
-- entrance, in lexicographic order. (Every tiling has at least one.)
local function actOrders(piece)
	local out = {}
	local used, cur = {}, {}
	local function rec()
		if #cur == 4 then
			if #entranceOptions(piece, cur) > 0 then
				out[#out + 1] = { table.unpack(cur) }
			end
			return
		end
		for p = 1, 4 do
			if not used[p] and (#cur == 0 or touches(piece, cur[#cur], p)) then
				used[p] = true
				cur[#cur + 1] = p
				rec()
				cur[#cur] = nil
				used[p] = nil
			end
		end
	end
	rec()
	return out
end

-- Neighbor pairs { a, b } (a < b) inside a list of cells.
local function innerPairs(cells)
	local out = {}
	for _, a in ipairs(cells) do
		for _, b in ipairs(nbrs(a)) do
			if a < b and grid.contains(cells, b) then
				out[#out + 1] = { a, b }
			end
		end
	end
	return out
end

-- Link distances from `from` over the links between `cells`.
local function linkDistances(cells, from, links)
	local dist = { [from] = 0 }
	local queue, head = { from }, 1
	while head <= #queue do
		local k = queue[head]
		head = head + 1
		for _, n in ipairs(nbrs(k)) do
			if dist[n] == nil and grid.contains(cells, n) and links[k][grid.cellDir(k, n, MAP)] then
				dist[n] = dist[k] + 1
				queue[#queue + 1] = n
			end
		end
	end
	return dist
end
worldgen.linkDistances = linkDistances

-- The cells of `cells` farthest from `from` (by links); ties broken by r.
local function farthest(r, cells, from, links)
	local dist = linkDistances(cells, from, links)
	local best, list = -1, {}
	for _, k in ipairs(cells) do
		local d = dist[k] or -1
		if d > best then
			best, list = d, { k }
		elseif d == best then
			list[#list + 1] = k
		end
	end
	return rng.pick(r, list)
end
worldgen.farthest = farthest

local function rollKind(r, kinds, campsLeft)
	local total, options = 0, {}
	for _, entry in ipairs(kinds) do
		if entry[1] ~= "camp" or campsLeft > 0 then
			options[#options + 1] = entry
			total = total + entry[2]
		end
	end
	local roll = r() * total
	for _, entry in ipairs(options) do
		roll = roll - entry[2]
		if roll < 0 then
			return entry[1]
		end
	end
	return options[#options][1]
end

-- ---------- the generator ----------

-- Returns the world description. Cells: { k, x, y, act, shape, kind, role
-- ("start" / "entrance" / "goal"), links = {N=true..}, linkCount,
-- gates = { [dir] = act } (the gate to the next act or from the previous
-- one), locked / lockedTo = dir (the dungeon door), dungeon, enemies }.
function worldgen.generate(seed)
	local r = rng.new(seed)
	local tilingIndex = rng.int(r, 1, #worldgen.TILINGS)
	local tiling = worldgen.TILINGS[tilingIndex]
	local order = rng.pick(r, actOrders(tiling.piece))

	-- the cells of each act (ascending), and each cell's act
	local actCells, actOf = { {}, {}, {}, {} }, {}
	for act, p in ipairs(order) do
		for k = 0, MAP * MAP - 1 do
			if tiling.piece[k] == p then
				actCells[act][#actCells[act] + 1] = k
				actOf[k] = act
			end
		end
	end

	-- Act IV's entrance: an end of the piece, next to Act III
	local entrance = rng.pick(r, entranceOptions(tiling.piece, order))

	local cells = {}
	for k = 0, MAP * MAP - 1 do
		cells[k] = {
			k = k, x = k % MAP, y = k // MAP, act = actOf[k], shape = tiling.shapes[tiling.piece[k]],
			links = {}, linkCount = 0, gates = {}, enemies = 0, dungeon = false,
		}
	end
	local function link(a, b)
		local da, db = grid.cellDir(a, b, MAP), grid.cellDir(b, a, MAP)
		if not cells[a].links[da] then
			cells[a].linkCount = cells[a].linkCount + 1
			cells[b].linkCount = cells[b].linkCount + 1
		end
		cells[a].links[da] = true
		cells[b].links[db] = true
	end

	-- links inside each piece; an O is a loop or a U
	local shapes = {}
	for act = 1, 4 do
		local inner = innerPairs(actCells[act])
		local shape = cells[actCells[act][1]].shape
		shapes[act] = { shape = shape }
		if shape == "O" then
			local loop = r() < 0.5
			if act == 4 then
				loop = false
			end
			shapes[act].loop = loop
			if not loop then
				local removable = inner
				if act == 4 then
					removable = grid.filter(inner, function(p)
						return p[1] == entrance or p[2] == entrance
					end)
				end
				local cut = rng.pick(r, removable)
				inner = grid.filter(inner, function(p)
					return p ~= cut
				end)
			end
		end
		for _, p in ipairs(inner) do
			link(p[1], p[2])
		end
	end

	-- gates between consecutive acts
	local gates = {}
	for act = 1, 3 do
		local sides = {}
		for _, a in ipairs(actCells[act]) do
			for _, b in ipairs(nbrs(a)) do
				if actOf[b] == act + 1 and (act < 3 or b == entrance) then
					sides[#sides + 1] = { a, b }
				end
			end
		end
		local side = rng.pick(r, sides)
		link(side[1], side[2])
		cells[side[1]].gates[grid.cellDir(side[1], side[2], MAP)] = act
		cells[side[2]].gates[grid.cellDir(side[2], side[1], MAP)] = act
		gates[act] = { from = side[1], to = side[2] }
	end

	-- kinds and roles
	local links = {}
	for k = 0, MAP * MAP - 1 do
		links[k] = cells[k].links
	end
	local start = farthest(r, actCells[1], gates[1].from, links)
	cells[start].kind = "town"
	cells[start].role = "start"
	local acts = Game.story.acts
	for act = 1, 3 do
		local campsLeft = acts[act].camps or 1
		for _, k in ipairs(actCells[act]) do
			if not cells[k].kind then
				local kind = rollKind(r, acts[act].kinds, campsLeft)
				if kind == "camp" then
					campsLeft = campsLeft - 1
				end
				cells[k].kind = kind
			end
		end
	end
	cells[entrance].kind = "entrance"
	cells[entrance].role = "entrance"
	local rooms = grid.filter(actCells[4], function(k)
		return k ~= entrance
	end)
	for _, k in ipairs(rooms) do
		cells[k].kind = "dungeon"
		cells[k].dungeon = true
	end
	local goal = farthest(r, rooms, entrance, links)
	cells[goal].role = "goal"
	-- the dungeon door: from the entrance into its one linked room
	local firstRoom
	for _, d in ipairs(grid.DIRS) do
		if cells[entrance].links[d[3]] and not cells[entrance].gates[d[3]] then
			firstRoom = entrance + d[1] + d[2] * MAP
			cells[entrance].locked = d[3]
			cells[firstRoom].lockedTo = grid.OPP[d[3]]
		end
	end

	return {
		seed = seed,
		cells = cells,
		tiling = tilingIndex,
		order = order,
		shapes = shapes,
		actCells = actCells,
		gates = gates,
		links = links,
		start = start,
		entrance = entrance,
		goal = goal,
		dungeonDoor = { inside = firstRoom, outside = entrance },
	}
end

Game.worldgen = worldgen
