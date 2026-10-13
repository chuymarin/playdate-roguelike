-- Entrance (Act IV): the outside of the dungeon. A clearing ringed by trees
-- and old stones, with the gate from Act III on one side and the locked
-- dungeon door (see layout.openings) on another. Its chest holds the
-- dungeon key.

local layout <const> = Game.layout
local helpers <const> = Game.areaHelpers

Game.areaKinds.entrance = {
	build = function(area, ctx)
		local r, kits = ctx.r, ctx.kits
		area.surface = "grass"
		layout.border(area, r, kits.forest.tree)
		layout.openings(area, ctx, kits.forest.tree)
		layout.addHub(area)
		local anchors = layout.anchors(area)
		helpers.placeChest(area, ctx, anchors)
		helpers.scatter(area, r, 0.10, kits.dungeon.pillar, Game.walls.dungeon.pillar, anchors)
		helpers.scatter(area, r, 0.08, kits.forest.tree, true, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.enemies, kits.forest.enemy, 1)
		helpers.scatter(area, r, 0.08, kits.forest.decor, Game.walls.forest.decor, anchors)
	end,
}
