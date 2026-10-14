-- Forest, creepy forest, ruins and mountain: small mazes. The area's chest
-- ends up in the maze's farthest corner, or down below when the cell has a
-- lower level (data/places.lua): a cave behind a web (a mountain's is
-- open) in the border, or a cellar under rubble you push aside; or up top
-- (a mountain's ridge, up the stairs).
-- Some walls are knocked down (15% of the trees, 30% of the ruin walls,
-- leaving rubble), which opens loops to run around enemies.

local layout <const> = Game.layout
local rng <const> = Game.rng
local helpers <const> = Game.areaHelpers

local function build(area, ctx, kit, walls, borderTiles)
	local r = ctx.r
	layout.border(area, r, borderTiles)
	layout.openings(area, ctx, borderTiles)
	layout.carveMaze(area, r, walls)
	-- knock some walls down: loops let you run around an enemy you can't fight yet
	local chance = area.kind == "ruins" and 0.3 or 0.15
	for y = 2, area.rows - 1 do
		for x = 2, area.cols - 1 do
			if area.solid[y][x] and r() < chance then
				local rubble = kit.rubble and #kit.rubble > 0 and r() < 0.5 and rng.pick(r, kit.rubble) or nil
				layout.set(area, x, y, rubble, false)
			end
		end
	end
	layout.joinOpenings(area)
	local anchors = layout.anchors(area)
	helpers.wayDown(area, ctx, anchors)
	helpers.wayUp(area, ctx, anchors)
	helpers.placeChest(area, ctx)
	helpers.spawnEnemies(area, r, ctx.cell.enemies, kit.enemy, 1)
end

Game.areaKinds.forest = {
	build = function(area, ctx)
		local kit = ctx.kits.forest
		area.surface = "grass"
		build(area, ctx, kit, kit.tree, kit.tree)
		local anchors = layout.anchors(area)
		if area.down then
			anchors[#anchors + 1] = { area.down.frontX, area.down.frontY }
		end
		helpers.scatter(area, ctx.r, 0.12, kit.decor, Game.walls.forest.decor, anchors)
	end,
}

Game.areaKinds.creepyForest = {
	build = function(area, ctx)
		local kit = ctx.kits.creepyForest
		area.surface = "grass"
		build(area, ctx, kit, kit.tree, kit.tree)
		local anchors = layout.anchors(area)
		if area.down then
			anchors[#anchors + 1] = { area.down.frontX, area.down.frontY }
		end
		helpers.scatter(area, ctx.r, 0.14, kit.decor, Game.walls.creepyForest.decor, anchors)
	end,
}

Game.areaKinds.ruins = {
	build = function(area, ctx)
		local kit = ctx.kits.ruins
		area.surface = "concrete"
		build(area, ctx, kit, kit.wall, kit.wall)
	end,
}

-- A maze of cliffs and boulders, an open cave mouth in its border and
-- stairs up to the ridge (the mountain's upper level).
Game.areaKinds.mountain = {
	build = function(area, ctx)
		local kit = ctx.kits.mountain
		area.surface = "concrete"
		build(area, ctx, kit, kit.cliff, kit.border)
		local anchors = layout.anchors(area)
		for _, way in ipairs({ area.down, area.up }) do
			anchors[#anchors + 1] = { way.frontX, way.frontY }
		end
		helpers.scatter(area, ctx.r, 0.06, kit.rock, Game.walls.mountain.rock, anchors)
		helpers.scatter(area, ctx.r, 0.1, kit.decor, Game.walls.mountain.decor, anchors)
	end,
}
