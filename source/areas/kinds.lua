-- Registry of area generators, filled in by areas/town.lua, areas/house.lua,
-- etc. Each kind is { build = function(area, ctx) }, where ctx has:
--   world  the World (world/world.lua)
--   cell   the world cell this area sits in (world/worldgen.lua)
--   r      this area's own random sequence (see areas/area.lua)
--   kits   tile picks per kind (tiles/kits.lua)
--   parent the outdoor area, for a house interior
-- Adding a kind: write areas/<kind>.lua, import it in main.lua.

Game.areaKinds = {}

local layout <const> = Game.layout
local rng <const> = Game.rng

-- Helpers several kinds use.
local helpers = {}

-- A free cell next to c that the anchors can reach, kept clear so the
-- player can always stand there (to open a chest or talk).
function helpers.standingSpot(area, c, anchors)
	local dist = layout.reach(area, { anchors[1] }, area.occupied)
	for _, d in ipairs({ { 0, 1 }, { -1, 0 }, { 1, 0 }, { 0, -1 } }) do
		local x, y = c[1] + d[1], c[2] + d[2]
		if dist[layout.key(x, y)] and x > 1 and y > 1 and x < area.cols and y < area.rows then
			area.reserved[layout.key(x, y)] = true
			return { x, y }
		end
	end
	return nil
end

-- Puts a solid thing (chest / NPC) on the first cell of `cells` that keeps
-- the anchors connected, and adds the spot in front of it as an anchor.
function helpers.placeSolid(area, cells, anchors)
	local c = layout.claimSolid(area, cells, anchors)
	if c then
		local spot = helpers.standingSpot(area, c, anchors)
		if spot then
			anchors[#anchors + 1] = spot
		end
	end
	return c
end

-- Enemy spawns, away from the doorways.
function helpers.spawnEnemies(area, r, count, tiles, hp)
	local cells = layout.spawnCells(area, 3)
	if #cells < count then
		cells = layout.spawnCells(area, 1)
	end
	for _ = 1, count do
		if #cells == 0 then
			return
		end
		local i = rng.int(r, 1, #cells)
		local c = table.remove(cells, i)
		layout.claimSpawn(area, c)
		area.enemySpawns[#area.enemySpawns + 1] = { x = c[1], y = c[2], tile = rng.pick(r, tiles), hp = hp }
	end
end

-- Scatters tiles over free interior cells with the given chance each.
function helpers.scatter(area, r, chance, tiles, solid, anchors)
	if #tiles == 0 then
		return
	end
	for _, c in ipairs(layout.shuffledInterior(area, r)) do
		if r() < chance then
			layout.tryPlace(area, c[1], c[2], rng.pick(r, tiles), solid, anchors)
		end
	end
end

Game.areaHelpers = helpers
