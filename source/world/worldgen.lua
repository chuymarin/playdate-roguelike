-- Builds the world map: 12 areas on a 4x4 grid, linked into paths.
--
-- 1. Blanks: the 4 unused cells are separate spots of 1-3 cells that don't
--    touch each other, and the cells left must stay connected.
-- 2. Dungeon: 4-6 connected cells grown from a cell on the map's edge, with
--    one entrance from the overworld, locked. The NPC (the goal) is locked
--    in a cell in its deepest room; the cell key is in a chest in the
--    deepest other room (not the entrance).
-- 3. Start: the overworld cell farthest from the dungeon door, in the town.
-- 4. Town: 2-4 cells. Two sit together around the start; each extra one goes
--    next to them or far away as an outpost (50/50).
-- 5. The rest: forest and ruins mazes at dead ends, deepest first, holding
--    the key chest, the sword chest and extra chests; camps in between. The
--    cell just outside the dungeon door prefers to be a camp.
--
-- Same algorithm and random sequence as the Room Scale Lab artifact.

local grid <const> = Game.grid
local rng <const> = Game.rng
local config <const> = Game.config

local worldgen = {}

local MAP <const> = config.MAP
local CELLS = {}
for k = 0, MAP * MAP - 1 do
	CELLS[#CELLS + 1] = k
end

local function nbrs(k)
	return grid.cellNeighbors(k, MAP)
end

local function onEdge(k)
	local x, y = k % MAP, k // MAP
	return x == 0 or y == 0 or x == MAP - 1 or y == MAP - 1
end

-- All neighbors of every cell in list, duplicates kept (they weight the pick).
local function flatNbrs(list)
	local out = {}
	for _, k in ipairs(list) do
		for _, n in ipairs(nbrs(k)) do
			out[#out + 1] = n
		end
	end
	return out
end

local function maxOf(list, fn)
	local best = -math.huge
	for _, v in ipairs(list) do
		best = math.max(best, fn(v))
	end
	return best
end

local function placeBlanks(r, blanks)
	for attempt = 0, 599 do
		local touchOk = attempt >= 400 -- fallback, only if spots can't stay apart
		local blank = grid.set()
		local function fits(k)
			if blank:has(k) then
				return false
			end
			if touchOk then
				return true
			end
			for _, n in ipairs(nbrs(k)) do
				if blank:has(n) then
					return false
				end
			end
			return true
		end
		local left, stuck = blanks, false
		while left > 0 do
			local size = math.min(left, rng.int(r, 1, 3))
			local free = grid.filter(CELLS, fits)
			if #free == 0 then
				stuck = true
				break
			end
			local spot = { rng.pick(r, free) }
			while #spot < size do
				local opts = grid.filter(flatNbrs(spot), function(n)
					return not grid.contains(spot, n) and fits(n)
				end)
				if #opts == 0 then
					break
				end
				spot[#spot + 1] = rng.pick(r, opts)
			end
			for _, k in ipairs(spot) do
				blank:add(k)
			end
			left = left - #spot
		end
		if not stuck then
			local open = grid.set(grid.filter(CELLS, function(k)
				return not blank:has(k)
			end))
			if grid.connected(open, MAP) then
				return open
			end
		end
	end
	return nil
end

-- Random spanning tree over `cells` (a Set) grown from root; the `first`
-- cells are joined before the rest.
local function growTree(r, cells, root, first)
	local inTree = grid.set({ root })
	local edges, depth = {}, { [root] = 0 }
	local function grow(only)
		while true do
			local opts = {}
			for _, a in ipairs(inTree.items) do
				for _, b in ipairs(nbrs(a)) do
					if cells:has(b) and not inTree:has(b) and (not only or only:has(b)) then
						opts[#opts + 1] = { a, b }
					end
				end
			end
			if #opts == 0 then
				return
			end
			local e = rng.pick(r, opts)
			inTree:add(e[2])
			edges[#edges + 1] = e
			depth[e[2]] = depth[e[1]] + 1
		end
	end
	if first and #first > 0 then
		grow(grid.set(first))
	end
	grow(nil)
	return { edges = edges, depth = depth, complete = inTree:size() == cells:size() }
end

-- Returns the world description, or nil if no valid map came out (the
-- caller tries the next seed). Cells: { k, x, y, kind, role, links = {N=true..},
-- locked = dir, lockedTo = dir, chest = contents, enemies, outpost }.
function worldgen.generate(seed, loop)
	if loop == nil then
		loop = true
	end
	local r = rng.new(seed)
	for _ = 1, 200 do
		local open = placeBlanks(r, MAP * MAP - config.AREAS)
		if open then
			local result = worldgen.try(r, open, loop, seed)
			if result then
				return result
			end
		end
	end
	return nil
end

function worldgen.try(r, open, loop, seed)
	local D = rng.int(r, 4, 6)
	local T = rng.int(r, 2, math.min(4, 9 - D))

	-- dungeon, grown from an edge cell; the overworld must stay in one piece
	local dun = grid.set({ rng.pick(r, grid.filter(open.items, onEdge)) })
	while dun:size() < D do
		local opts = grid.filter(flatNbrs(dun.items), function(n)
			return open:has(n) and not dun:has(n)
		end)
		if #opts == 0 then
			break
		end
		dun:add(rng.pick(r, opts))
	end
	local over = grid.set(grid.filter(open.items, function(k)
		return not dun:has(k)
	end))
	if dun:size() < D or not grid.connected(over, MAP) then
		return nil
	end
	local doors = {}
	for _, k in ipairs(dun.items) do
		for _, n in ipairs(nbrs(k)) do
			if over:has(n) then
				doors[#doors + 1] = { k, n }
			end
		end
	end
	local door = rng.pick(r, doors)
	local ein, eout = door[1], door[2]

	-- start: the overworld cell farthest from the dungeon door
	local fromDoor = grid.cellDistances(eout, over, MAP)
	local maxD = maxOf(over.items, function(k)
		return fromDoor[k]
	end)
	local start = rng.pick(r, grid.filter(over.items, function(k)
		return fromDoor[k] == maxD
	end))
	local fromStart = grid.cellDistances(start, over, MAP)

	-- town: the start plus a neighbor, then extra houses near or far (outposts)
	local town, outposts = { start }, {}
	local function near()
		local seen = grid.set(flatNbrs(town))
		return grid.filter(seen.items, function(n)
			return over:has(n) and not grid.contains(town, n) and n ~= eout
		end)
	end
	if #near() > 0 then
		town[#town + 1] = rng.pick(r, near())
	end
	while #town + #outposts < T do
		local function taken(k)
			return grid.contains(town, k) or grid.contains(outposts, k)
		end
		local coin = r() < 0.5
		if coin and #near() > 0 then
			town[#town + 1] = rng.pick(r, near())
		else
			local far = grid.filter(over.items, function(k)
				if taken(k) then
					return false
				end
				for _, t in ipairs(town) do
					if grid.contains(nbrs(t), k) then
						return false
					end
				end
				return true
			end)
			if #far == 0 then
				if #near() > 0 then
					town[#town + 1] = rng.pick(r, near())
				else
					break
				end
			else
				local best = maxOf(far, function(k)
					return fromStart[k]
				end)
				outposts[#outposts + 1] = rng.pick(r, grid.filter(far, function(k)
					return fromStart[k] == best
				end))
			end
		end
	end
	if #town + #outposts < T then
		return nil
	end

	local tree = growTree(r, over, start, town)
	if not tree.complete then
		return nil
	end
	local dtree = growTree(r, dun, ein)
	if not dtree.complete then
		return nil
	end

	local cells = {}
	for _, k in ipairs(open.items) do
		cells[k] = { k = k, x = k % MAP, y = k // MAP, links = {}, linkCount = 0, enemies = 0, dungeon = dun:has(k) }
	end
	local function link(a, b)
		local da, db = grid.cellDir(a, b, MAP), grid.cellDir(b, a, MAP)
		if not cells[a].links[da] then
			cells[a].linkCount = cells[a].linkCount + 1
		end
		if not cells[b].links[db] then
			cells[b].linkCount = cells[b].linkCount + 1
		end
		cells[a].links[da] = true
		cells[b].links[db] = true
	end
	for _, e in ipairs(tree.edges) do
		link(e[1], e[2])
	end
	for _, e in ipairs(dtree.edges) do
		link(e[1], e[2])
	end
	link(ein, eout)
	cells[ein].locked = grid.cellDir(ein, eout, MAP)
	cells[eout].lockedTo = grid.cellDir(eout, ein, MAP)
	if loop then
		local cand = {}
		for _, a in ipairs(over.items) do
			for _, b in ipairs(nbrs(a)) do
				if over:has(b) and a < b and not cells[a].links[grid.cellDir(a, b, MAP)] then
					cand[#cand + 1] = { a, b }
				end
			end
		end
		if #cand > 0 then
			local e = rng.pick(r, cand)
			link(e[1], e[2])
		end
	end

	-- kinds and roles
	for _, k in ipairs(dun.items) do
		cells[k].kind = "dungeon"
	end
	for _, k in ipairs(town) do
		cells[k].kind = "town"
	end
	for _, k in ipairs(outposts) do
		cells[k].kind = "town"
		cells[k].outpost = true
	end
	cells[start].role = "start"
	local deepest = maxOf(dun.items, function(k)
		return dtree.depth[k]
	end)
	local npc = rng.pick(r, grid.filter(dun.items, function(k)
		return dtree.depth[k] == deepest
	end))
	cells[npc].role = "goal"

	local rest = grid.filter(over.items, function(k)
		return not cells[k].kind
	end)
	local campCount = #rest >= 5 and 2 or 1
	local camps = {}
	if grid.contains(rest, eout) then
		camps[#camps + 1] = eout
	end
	rest = grid.filter(rest, function(k)
		return k ~= eout
	end)
	-- dead ends first, then the deepest; stable (ties keep their order)
	local order = {}
	for i, k in ipairs(rest) do
		order[k] = i
	end
	table.sort(rest, function(a, b)
		local la, lb = cells[a].linkCount == 1 and 1 or 0, cells[b].linkCount == 1 and 1 or 0
		if la ~= lb then
			return la > lb
		end
		if fromStart[a] ~= fromStart[b] then
			return fromStart[a] > fromStart[b]
		end
		return order[a] < order[b]
	end)
	local poiCount = math.max(2, #rest - math.max(0, campCount - #camps))
	local pois = {}
	for i, k in ipairs(rest) do
		if i <= poiCount then
			pois[#pois + 1] = k
		else
			camps[#camps + 1] = k
		end
	end
	for _, k in ipairs(camps) do
		cells[k].kind = "camp"
	end
	for _, k in ipairs(pois) do
		cells[k].kind = r() < 0.5 and "forest" or "ruins"
	end
	if #pois < 2 then
		return nil
	end
	-- every point of interest has a closed chest: the key, the sword, then hearts
	cells[pois[1]].chest = "key"
	cells[pois[2]].chest = "sword"
	for i = 3, #pois do
		cells[pois[i]].chest = "heart"
	end
	for _, k in ipairs(pois) do
		cells[k].enemies = 1 + (r() < 0.4 and 1 or 0)
	end
	-- you reach the sword without one, so its guard is a single enemy
	cells[pois[2]].enemies = 1
	for _, k in ipairs(dun.items) do
		if k ~= npc and k ~= ein then
			cells[k].enemies = r() < 0.7 and 1 or 0
		end
	end
	-- the cell key: deepest dungeon room besides the NPC's and the entrance,
	-- lowest cell on ties (no random draw, so maps still match the lab)
	local keyRoom = nil
	for _, k in ipairs(dun.items) do
		if k ~= npc and k ~= ein then
			if not keyRoom or dtree.depth[k] > dtree.depth[keyRoom] or (dtree.depth[k] == dtree.depth[keyRoom] and k < keyRoom) then
				keyRoom = k
			end
		end
	end
	if not keyRoom then
		return nil
	end
	cells[keyRoom].chest = "cellKey"

	return {
		seed = seed,
		cells = cells,
		start = start,
		goal = npc,
		cellKey = keyRoom,
		dungeonDoor = { inside = ein, outside = eout },
		census = { dungeon = D, town = T, poi = #pois, camp = #camps },
	}
end

Game.worldgen = worldgen
