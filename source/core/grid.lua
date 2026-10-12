-- Grid helpers shared by the world map (4x4 cells) and rooms (12x7 tiles).
--
-- Directions are "N", "E", "S", "W". World cells are numbered from 0,
-- row by row (k = y * MAP + x), matching the Room Scale Lab.

local grid = {}

grid.DIRS = {
	{ 0, -1, "N" },
	{ 1, 0, "E" },
	{ 0, 1, "S" },
	{ -1, 0, "W" },
}
grid.DELTA = { N = { 0, -1 }, E = { 1, 0 }, S = { 0, 1 }, W = { -1, 0 } }
grid.OPP = { N = "S", S = "N", E = "W", W = "E" }

-- An insertion-ordered set: iterate with set.items (a list), test with
-- set:has(k). Keeps generation deterministic (plain Lua tables iterate in
-- no fixed order).
local Set = {}
Set.__index = Set

function grid.set(list)
	local s = setmetatable({ items = {}, index = {} }, Set)
	for _, v in ipairs(list or {}) do
		s:add(v)
	end
	return s
end

function Set:add(v)
	if not self.index[v] then
		self.index[v] = true
		self.items[#self.items + 1] = v
	end
end

function Set:has(v)
	return self.index[v] == true
end

function Set:size()
	return #self.items
end

function grid.contains(list, v)
	for _, x in ipairs(list) do
		if x == v then
			return true
		end
	end
	return false
end

function grid.filter(list, fn)
	local out = {}
	for _, v in ipairs(list) do
		if fn(v) then
			out[#out + 1] = v
		end
	end
	return out
end

-- ---------- world cells ----------

function grid.cellX(k, size)
	return k % size
end

function grid.cellY(k, size)
	return k // size
end

-- Neighbor cells in N, E, S, W order.
function grid.cellNeighbors(k, size)
	local x, y = k % size, k // size
	local out = {}
	for _, d in ipairs(grid.DIRS) do
		local nx, ny = x + d[1], y + d[2]
		if nx >= 0 and ny >= 0 and nx < size and ny < size then
			out[#out + 1] = ny * size + nx
		end
	end
	return out
end

-- Direction from cell a to its neighbor b.
function grid.cellDir(a, b, size)
	local dx, dy = b % size - a % size, b // size - a // size
	for _, d in ipairs(grid.DIRS) do
		if d[1] == dx and d[2] == dy then
			return d[3]
		end
	end
end

-- Distances from `from` over the cells in `open` (a Set), optionally only
-- along pairs where linked(a, b) is true. Returns map k -> distance and the
-- cells in visit order.
function grid.cellDistances(from, open, size, linked)
	local dist, order, q, head = { [from] = 0 }, { from }, { from }, 1
	while head <= #q do
		local k = q[head]
		head = head + 1
		for _, n in ipairs(grid.cellNeighbors(k, size)) do
			if open:has(n) and dist[n] == nil and (not linked or linked(k, n)) then
				dist[n] = dist[k] + 1
				order[#order + 1] = n
				q[#q + 1] = n
			end
		end
	end
	return dist, order
end

function grid.connected(set, size)
	if set:size() == 0 then
		return true
	end
	local _, order = grid.cellDistances(set.items[1], set, size)
	return #order == set:size()
end

Game.grid = grid
