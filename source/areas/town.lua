-- Settlements: an open area with one building you can walk into (its inside
-- is the cell's `inside`: areas/house.lua, areas/interiors.lua), dirt paths
-- from every doorway to its door, and trees and decor around.
--   town        a 3x2 house (a roof row, then window, door, wall) with a
--               villager inside; a short fence
--   ruinedTown  the same house in ruins: one you can go into (its chest
--               inside or in the cellar below), or one fallen in, a block
--               of rubble drawn with the build template; rubble around
--   church      the church from its blueprint, a priest (and the area's
--               chest) inside, maybe stairs down to a crypt

local layout <const> = Game.layout
local rng <const> = Game.rng
local helpers <const> = Game.areaHelpers

-- Border, doorways, the building and the paths to its door. Returns the
-- anchors (doorways and the spot in front of the door).
-- place(anchors) builds the building and returns its door.
local function settle(area, ctx, borderTiles, place, pathTiles)
	local r = ctx.r
	area.surface = "grass"
	layout.border(area, r, borderTiles)
	layout.openings(area, ctx, borderTiles)
	local anchors = layout.anchors(area)
	local door = ctx.cell.inside and place(anchors)
	if door == true then
		door = nil
	end
	if door then
		helpers.wayIn(area, ctx, door, anchors)
		for _, a in ipairs(layout.anchors(area)) do
			layout.carvePath(area, r, a, { door.frontX, door.frontY }, pathTiles)
		end
	else
		layout.addHub(area)
		anchors = layout.anchors(area)
	end
	return anchors, door
end

-- Houses (from the user's scenarios): a roof row over window, door, wall
-- (or mirrored).
local HOUSES = { { "LRG", "XDW" }, { "LRG", "WDX" } }

local function placeHouse(area, r, kit, anchors)
	local legend = { L = kit.roofLeft, R = kit.roof, G = kit.roofRight, X = kit.window, D = kit.door, W = kit.wall }
	local rows = HOUSES[rng.int(r, 1, #HOUSES)]
	return helpers.placeBlueprint(area, r, rows, legend, anchors)
end

-- A ruined house you can walk into: roof, then wall, doorway, wall.
local function placeRuin(area, r, kit, anchors)
	local legend = { L = kit.roofLeft, R = kit.roof, G = kit.roofRight, A = kit.wallLeft, D = kit.door, B = kit.wallRight }
	return helpers.placeBlueprint(area, r, { "LRG", "ADB" }, legend, anchors)
end

-- A house fallen in: a block of rubble walls (the build template, as if
-- the floor were all around it), overgrown in the middle of its front.
local function placeFallen(area, r, ctx, anchors)
	local build, kit = ctx.kits.build, ctx.kits.ruinedHouse
	local function wall(x, y, w, h)
		return helpers.buildTile(r, build, y == 1, y == h, x == 1, x == w)
	end
	local legend = { B = wall, g = #kit.overgrown > 0 and kit.overgrown or nil }
	if not legend.g then
		legend.g = wall
	end
	return helpers.placeBlueprint(area, r, { "BBB", "BgB" }, legend, anchors, { g = #kit.overgrown > 0 })
end

Game.areaKinds.town = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.town
		local anchors, house = settle(area, ctx, kit.border, function(a)
			return placeHouse(area, r, ctx.kits.house, a) or helpers.placeBuilding(area, r, ctx.kits.house, a)
		end, kit.path)
		if house then
			area.house = house
			-- a short fence off one side of the house
			local side = r() < 0.5 and -1 or 1
			local x0 = side < 0 and house.left - 1 or house.right + 1
			for i = 0, rng.int(r, 0, 2) do
				layout.tryPlace(area, x0 + side * i, house.y, rng.pick(r, kit.fence), Game.walls.town.fence, anchors)
			end
		end
		helpers.placeChest(area, ctx, anchors)
		helpers.scatter(area, r, 0.16, kit.tree, Game.walls.town.tree, anchors)
		helpers.scatter(area, r, 0.10, kit.decor, Game.walls.town.decor, anchors)
	end,
}

Game.areaKinds.ruinedTown = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.ruinedTown
		local anchors = settle(area, ctx, kit.border, function(a)
			return placeRuin(area, r, ctx.kits.ruinedHouse, a)
		end, kit.path)
		area.surface = "concrete"
		if not ctx.cell.inside then
			placeFallen(area, r, ctx, anchors)
		end
		helpers.placeChest(area, ctx, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.enemies, kit.enemy, 1)
		helpers.scatter(area, r, 0.12, kit.tree, Game.walls.ruinedTown.tree, anchors)
		helpers.scatter(area, r, 0.14, kit.rubble, Game.walls.ruinedTown.rubble, anchors)
	end,
}

-- The church, 3x3: a steeple over a cross window over an arched door. The
-- two-row one is tried when it doesn't fit (doorways keep the cells just
-- inside them clear).
local CHURCHES = {
	{ "LSG", "WXW", "WDW" },
	{ "LSG", "WDW" },
}

Game.areaKinds.church = {
	build = function(area, ctx)
		local r, kit, church = ctx.r, ctx.kits.town, ctx.kits.church
		local legend = {
			L = church.roofLeft, G = church.roofRight, S = church.steeple,
			W = church.wall, X = church.window, D = church.door,
		}
		local anchors, door = settle(area, ctx, kit.border, function(a)
			for _, rows in ipairs(CHURCHES) do
				local door = helpers.placeBlueprint(area, r, rows, legend, a)
				if door then
					return door
				end
			end
			return nil
		end, church.path)
		if door then
			-- flowers either side of the path in front of the door
			for _, dx in ipairs({ -1, 1 }) do
				for dy = 1, 2 do
					layout.tryPlace(area, door.x + dx, door.y + dy, rng.pick(r, church.flowers), false, anchors)
				end
			end
		end
		helpers.placeChest(area, ctx, anchors)
		helpers.scatter(area, r, 0.12, kit.tree, Game.walls.town.tree, anchors)
		helpers.scatter(area, r, 0.08, ctx.kits.cemetery.grave, Game.walls.cemetery.grave, anchors)
		helpers.scatter(area, r, 0.08, kit.decor, Game.walls.town.decor, anchors)
	end,
}
