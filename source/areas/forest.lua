-- Forest and ruins: small mazes. The area's chest (placed by areas/area.lua)
-- ends up in the maze's farthest corner.
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
	helpers.placeChest(area, ctx)
	helpers.spawnEnemies(area, r, ctx.cell.enemies, kit.enemy, 1)
end

Game.areaKinds.forest = {
	build = function(area, ctx)
		local kit = ctx.kits.forest
		area.surface = "grass"
		build(area, ctx, kit, kit.tree, kit.tree)
		helpers.scatter(area, ctx.r, 0.12, kit.decor, false, layout.anchors(area))
	end,
}

Game.areaKinds.ruins = {
	build = function(area, ctx)
		local kit = ctx.kits.ruins
		area.surface = "concrete"
		build(area, ctx, kit, kit.wall, kit.wall)
	end,
}
