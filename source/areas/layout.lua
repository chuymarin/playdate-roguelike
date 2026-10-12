-- Building blocks the area generators share: an empty area, borders,
-- doorways, reachability checks, placing things without cutting paths,
-- maze carving and paths.
--
-- Room coordinates are 1-based: x = 1..cols, y = 1..rows. The border is
-- x = 1 / cols and y = 1 / rows; doorways open in the middle of each side.

local rng <const> = Game.rng
local grid <const> = Game.grid
local config <const> = Game.config

local layout = {}

local function key(x, y)
	return y * 100 + x
end
layout.key = key

function layout.new(id, kind, cols, rows)
	local area = {
		id = id,
		kind = kind,
		cols = cols or config.COLS,
		rows = rows or config.ROWS,
		tiles = {},    -- [y][x] sheet index of the tile drawn there, or nil
		solid = {},    -- [y][x] true when nothing can walk there
		reserved = {}, -- [key] cells kept clear (paths, spots in front of doors)
		openings = {}, -- [dir] = list of { x, y } border cells open toward a neighbor
		portals = {},  -- { x, y, to = area id, toX, toY, facing }
		chests = {},   -- { x, y, contents, opened }
		items = {},    -- { x, y, item } lying on the ground
		npcs = {},     -- { x, y, tile, lines, goal }
		enemySpawns = {}, -- { x, y, tile, hp }
		occupied = {}, -- [key] cells taken by a chest or NPC (they block the way)
		spawnTaken = {}, -- [key] enemy spawn cells (enemies move, so they don't block)
	}
	for y = 1, area.rows do
		area.tiles[y] = {}
		area.solid[y] = {}
	end
	return area
end

function layout.set(area, x, y, tile, solid)
	area.tiles[y][x] = tile
	area.solid[y][x] = solid and true or false
end

function layout.inside(area, x, y)
	return x >= 1 and y >= 1 and x <= area.cols and y <= area.rows
end

-- Middle columns / rows where doorways open (two when the side is even).
function layout.midX(area)
	if area.cols % 2 == 1 then
		return { area.cols // 2 + 1 }
	end
	return { area.cols // 2, area.cols // 2 + 1 }
end

function layout.midY(area)
	if area.rows % 2 == 1 then
		return { area.rows // 2 + 1 }
	end
	return { area.rows // 2, area.rows // 2 + 1 }
end

function layout.sideCells(area, dir)
	local out = {}
	if dir == "N" or dir == "S" then
		local y = dir == "N" and 1 or area.rows
		for _, x in ipairs(layout.midX(area)) do
			out[#out + 1] = { x, y }
		end
	else
		local x = dir == "W" and 1 or area.cols
		for _, y in ipairs(layout.midY(area)) do
			out[#out + 1] = { x, y }
		end
	end
	return out
end

function layout.border(area, r, tiles)
	for x = 1, area.cols do
		layout.set(area, x, 1, rng.pick(r, tiles), true)
		layout.set(area, x, area.rows, rng.pick(r, tiles), true)
	end
	for y = 1, area.rows do
		layout.set(area, 1, y, rng.pick(r, tiles), true)
		layout.set(area, area.cols, y, rng.pick(r, tiles), true)
	end
end

-- The cell just inside a border cell, toward the room's middle.
local function inward(c, dir)
	local d = grid.DELTA[grid.OPP[dir]]
	return c[1] + d[1], c[2] + d[2]
end

-- Opens the border toward each linked neighbor. The dungeon's locked
-- entrance gets a lock tile on its first cell (area.lock; walkable once the
-- world is unlocked) and closes the rest of that gap; any other passage
-- between dungeon and overworld gets a door tile.
function layout.openings(area, ctx, borderTiles)
	local cell, world, r = ctx.cell, ctx.world, ctx.r
	local dungeonKit = ctx.kits.dungeon
	for _, d in ipairs(grid.DIRS) do
		local dir = d[3]
		if cell.links[dir] then
			local cells = layout.sideCells(area, dir)
			local other = world.gen.cells[cell.k + d[1] + d[2] * config.MAP]
			local locked = cell.locked == dir or cell.lockedTo == dir
			local doorTile = nil
			if locked then
				doorTile = rng.pick(r, dungeonKit.locked)
			elseif other and other.dungeon ~= cell.dungeon then
				doorTile = rng.pick(r, dungeonKit.door)
			end
			area.openings[dir] = {}
			-- keep the tile just inside the doorway clear, so a doorway is never walled off
			local inX, inY = inward(cells[1], dir)
			area.reserved[key(inX, inY)] = true
			for i, c in ipairs(cells) do
				if doorTile and i > 1 then
					layout.set(area, c[1], c[2], rng.pick(r, borderTiles), true)
				else
					layout.set(area, c[1], c[2], i == 1 and doorTile or nil, false)
					area.openings[dir][#area.openings[dir] + 1] = c
				end
			end
			if locked then
				local c = cells[1]
				area.lock = { x = c[1], y = c[2], tile = doorTile, openTile = rng.pick(r, dungeonKit.door) }
			end
		end
	end
end

-- Reserves the room's middle cell as an anchor, so rooms with a single
-- doorway can't get walled off behind it (used by open rooms, not mazes).
function layout.addHub(area)
	local x, y = layout.midX(area)[1], layout.midY(area)[1]
	area.reserved[key(x, y)] = true
	area.hub = { x, y }
end

-- The first opening cell of every doorway, the hub, plus any extra { x, y } anchors.
function layout.anchors(area, extra)
	local out = {}
	if area.hub then
		out[1] = area.hub
	end
	for _, d in ipairs(grid.DIRS) do
		local cells = area.openings[d[3]]
		if cells then
			out[#out + 1] = cells[1]
		end
	end
	for _, c in ipairs(extra or {}) do
		out[#out + 1] = c
	end
	return out
end

-- Breadth-first walk over walkable cells from the given starts. Returns
-- dist[key] and the cells in visit order (nearest first).
function layout.reach(area, starts, blocked)
	local dist, order, q, head = {}, {}, {}, 1
	for _, s in ipairs(starts) do
		local k = key(s[1], s[2])
		if dist[k] == nil then
			dist[k] = 0
			q[#q + 1] = s
			order[#order + 1] = s
		end
	end
	while head <= #q do
		local c = q[head]
		head = head + 1
		for _, d in ipairs(grid.DIRS) do
			local nx, ny = c[1] + d[1], c[2] + d[2]
			local k = key(nx, ny)
			if layout.inside(area, nx, ny) and not area.solid[ny][nx] and dist[k] == nil and not (blocked and blocked[k]) then
				dist[k] = dist[key(c[1], c[2])] + 1
				local n = { nx, ny }
				q[#q + 1] = n
				order[#order + 1] = n
			end
		end
	end
	return dist, order
end

function layout.connected(area, anchors)
	if #anchors < 2 then
		return true
	end
	local dist = layout.reach(area, { anchors[1] }, area.occupied)
	for _, a in ipairs(anchors) do
		if dist[key(a[1], a[2])] == nil then
			return false
		end
	end
	return true
end

local function isAnchor(anchors, x, y)
	for _, a in ipairs(anchors) do
		if a[1] == x and a[2] == y then
			return true
		end
	end
	return false
end

-- Puts a tile on an empty, unreserved cell. A solid tile is only kept if
-- every anchor can still reach every other one. Returns true when placed.
function layout.tryPlace(area, x, y, tile, solid, anchors)
	local k = key(x, y)
	if area.tiles[y][x] ~= nil or area.solid[y][x] or area.reserved[k] or area.occupied[k] or area.spawnTaken[k] or isAnchor(anchors, x, y) then
		return false
	end
	layout.set(area, x, y, tile, solid)
	if solid and not layout.connected(area, anchors) then
		layout.set(area, x, y, nil, false)
		return false
	end
	return true
end

-- Interior cells (inside the border) in random order.
function layout.shuffledInterior(area, r)
	local cells = {}
	for y = 2, area.rows - 1 do
		for x = 2, area.cols - 1 do
			cells[#cells + 1] = { x, y }
		end
	end
	for i = #cells, 2, -1 do
		local j = rng.int(r, 1, i)
		cells[i], cells[j] = cells[j], cells[i]
	end
	return cells
end

-- Fills the interior with walls and carves a maze through it (passages on
-- every other cell), then joins each doorway to the nearest passage.
function layout.carveMaze(area, r, wallTiles)
	for y = 2, area.rows - 1 do
		for x = 2, area.cols - 1 do
			layout.set(area, x, y, rng.pick(r, wallTiles), true)
		end
	end
	local function open(x, y)
		layout.set(area, x, y, nil, false)
	end
	local stack = { { 2, 2 } }
	open(2, 2)
	while #stack > 0 do
		local top = stack[#stack]
		local x, y = top[1], top[2]
		local opts = {}
		for _, d in ipairs({ { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }) do
			local nx, ny = x + d[1], y + d[2]
			if nx >= 2 and ny >= 2 and nx <= area.cols - 1 and ny <= area.rows - 1 and area.solid[ny][nx] then
				opts[#opts + 1] = { nx, ny, x + d[1] // 2, y + d[2] // 2 }
			end
		end
		if #opts == 0 then
			stack[#stack] = nil
		else
			local o = rng.pick(r, opts)
			open(o[3], o[4])
			open(o[1], o[2])
			stack[#stack + 1] = { o[1], o[2] }
		end
	end
end

-- Digs inward from each doorway until it meets an open passage.
function layout.joinOpenings(area)
	local inward = { N = { 0, 1 }, S = { 0, -1 }, W = { 1, 0 }, E = { -1, 0 } }
	for _, d in ipairs(grid.DIRS) do
		local cells = area.openings[d[3]]
		for _, c in ipairs(cells or {}) do
			local x, y = c[1], c[2]
			local dx, dy = inward[d[3]][1], inward[d[3]][2]
			for _ = 1, math.max(area.cols, area.rows) do
				x, y = x + dx, y + dy
				if x < 2 or y < 2 or x > area.cols - 1 or y > area.rows - 1 then
					break
				end
				local wasOpen = not area.solid[y][x]
				if area.solid[y][x] then
					layout.set(area, x, y, nil, false)
				end
				local sides = dx ~= 0 and { { x, y - 1 }, { x, y + 1 } } or { { x - 1, y }, { x + 1, y } }
				local sideOpen = false
				for _, s in ipairs(sides) do
					if not area.solid[s[2]][s[1]] then
						sideOpen = true
					end
				end
				if wasOpen or sideOpen then
					break
				end
			end
		end
	end
end

-- Marks the shortest walkable path between two cells with path tiles (on
-- cells that have no tile yet) and reserves it so nothing is placed on it.
function layout.carvePath(area, r, from, to, pathTiles)
	local prev, q, head = { [key(from[1], from[2])] = false }, { from }, 1
	while head <= #q do
		local c = q[head]
		head = head + 1
		if c[1] == to[1] and c[2] == to[2] then
			break
		end
		for _, d in ipairs(grid.DIRS) do
			local nx, ny = c[1] + d[1], c[2] + d[2]
			local k = key(nx, ny)
			if layout.inside(area, nx, ny) and not area.solid[ny][nx] and prev[k] == nil then
				prev[k] = c
				q[#q + 1] = { nx, ny }
			end
		end
	end
	local c = to
	while c do
		local k = key(c[1], c[2])
		if prev[k] == nil then
			return
		end
		area.reserved[k] = true
		local onBorder = c[1] == 1 or c[2] == 1 or c[1] == area.cols or c[2] == area.rows
		if area.tiles[c[2]][c[1]] == nil and not onBorder and #pathTiles > 0 then
			layout.set(area, c[1], c[2], rng.pick(r, pathTiles), false)
		end
		c = prev[k]
	end
end

-- Walkable interior cells with nothing on them, nearest to `from` first.
function layout.freeCells(area, from)
	local _, order = layout.reach(area, from)
	local out = {}
	for _, c in ipairs(order) do
		local x, y = c[1], c[2]
		local k = key(x, y)
		local interior = x > 1 and y > 1 and x < area.cols and y < area.rows
		if interior and not area.occupied[k] and not area.spawnTaken[k] and not area.reserved[k] and area.tiles[y][x] == nil then
			out[#out + 1] = c
		end
	end
	return out
end

-- Takes a cell for an enemy spawn so nothing else lands on it.
function layout.claimSpawn(area, c)
	area.spawnTaken[key(c[1], c[2])] = true
	return c
end

-- The free cell closest to the middle of the room.
function layout.nearCenter(area, cells)
	local mx, my = (area.cols + 1) / 2, (area.rows + 1) / 2
	local best, bestD = nil, math.huge
	for _, c in ipairs(cells) do
		local d = math.abs(c[1] - mx) + math.abs(c[2] - my)
		if d < bestD then
			best, bestD = c, d
		end
	end
	return best
end

-- Places a solid thing (chest, NPC) on one of `cells` without cutting any
-- anchor off. Tries cells in order; returns the cell or nil.
function layout.claimSolid(area, cells, anchors)
	for _, c in ipairs(cells) do
		local k = key(c[1], c[2])
		if not area.occupied[k] then
			area.occupied[k] = true
			if layout.connected(area, anchors) then
				return c
			end
			area.occupied[k] = nil
		end
	end
	return nil
end

-- Sorts cells by distance to the middle of the room (closest first).
function layout.byCenter(area, cells)
	local mx, my = (area.cols + 1) / 2, (area.rows + 1) / 2
	local out = {}
	for i, c in ipairs(cells) do
		out[i] = c
	end
	table.sort(out, function(a, b)
		local da = math.abs(a[1] - mx) + math.abs(a[2] - my)
		local db = math.abs(b[1] - mx) + math.abs(b[2] - my)
		if da ~= db then
			return da < db
		end
		return key(a[1], a[2]) < key(b[1], b[2])
	end)
	return out
end

-- Enemy spawns: free cells at least `gap` steps from every doorway.
function layout.spawnCells(area, gap)
	local dist = layout.reach(area, layout.anchors(area))
	local out = {}
	for _, c in ipairs(layout.freeCells(area, layout.anchors(area))) do
		if (dist[key(c[1], c[2])] or 0) >= gap then
			out[#out + 1] = c
		end
	end
	return out
end

Game.layout = layout
