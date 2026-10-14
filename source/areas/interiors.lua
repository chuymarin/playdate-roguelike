-- Insides ("h", through a building's door) and lower levels ("u", down
-- the stairs): shaped rooms floating in the dark, entered from the bottom
-- (helpers.shapedRoom). Which places get which, and where the chest goes:
-- data/places.lua. A lower level has passages to its neighbors' when the
-- world joined them.
--   ruinedHouse  broken furniture, rubble, the odd skeleton; maybe stairs
--                down under rubble
--   chapel       pews either side of the aisle, an altar in the apse, a
--                priest with hints; maybe stairs down to a crypt
--   crypt        graves along the walls, candles (under a cemetery or a
--                church)
--   cave         chambers and corridors, rocks and bones (behind a web in a
--                forest)
--   cellar       the same shape, rubble (under ruins or a ruined house)
-- Upper levels ("a", up the stairs), stairs back down where you came up:
--   ridge        the top of a mountain: open rock in the sky, boulders
--   tower        over the dungeon: stone halls, pillars, tougher enemies
-- A lower or upper level can spread over its neighbors' cells in the same
-- act (world/story.lua): those have no stairs, only passages.
-- Ruined houses, caves and cellars draw their walls with the build
-- template (kits.build: a piece for each side the floor is on).

local layout <const> = Game.layout
local rng <const> = Game.rng
local helpers <const> = Game.areaHelpers

-- The chest (if it's in here) goes on the free cell farthest from the way in.
local function chest(area, ctx, anchors, prefer)
	return helpers.placeChest(area, ctx, anchors, prefer)
end

-- Tiles along the walls, each with the given chance.
local function lineWalls(area, r, chance, tiles, solid, anchors)
	if #tiles == 0 then
		return
	end
	for _, c in ipairs(helpers.alongWalls(area, r)) do
		if r() < chance then
			layout.tryPlace(area, c[1], c[2], rng.pick(r, tiles), solid, anchors)
		end
	end
end


Game.areaKinds.ruinedHouse = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.ruinedHouse
		area.surface = "concrete"
		local anchors = helpers.shapedRoom(area, ctx, { shape = "house", walls = ctx.kits.build, exit = kit.door })
		if ctx.cell.below and ctx.cell.below.from == "inside" then
			helpers.farStairsDown(area, ctx, anchors, { area.entry })
		end
		chest(area, ctx, anchors)
		lineWalls(area, r, 0.3, kit.furniture, Game.walls.ruinedHouse.furniture, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.insideEnemies or 0, kit.enemy, 1)
		helpers.scatter(area, r, 0.16, kit.floor, Game.walls.ruinedHouse.floor, anchors)
	end,
}

-- The chapel follows the church scenario: the apse holds candles and the
-- altar, pews fill both sides of the aisle, the way out is two cells wide.
Game.areaKinds.chapel = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.church
		area.surface = "wood"
		local anchors = helpers.shapedRoom(area, ctx, { shape = "church", walls = kit.wall, exit = kit.door, wide = true })
		local mx = layout.midX(area)[1]
		for _, x in ipairs({ mx - 1, mx + 2 }) do
			layout.tryPlace(area, x, 2, rng.pick(r, kit.candle), Game.walls.church.candle, anchors)
		end
		local altar = rng.pick(r, kit.altar)
		layout.tryPlace(area, mx, 3, altar, Game.walls.church.altar, anchors)
		-- the priest beside the altar, the aisle kept clear
		for y = 3, area.rows - 1 do
			area.reserved[layout.key(mx, y)] = y > 3 or nil
			area.reserved[layout.key(mx + 1, y)] = true
		end
		local priest = ctx.kits.characters.priest
		local c = helpers.placeSolid(area, { { mx + 1, 3 } }, anchors)
		if c then
			Game.objects.add(area, "villager", c[1], c[2], {
				tile = rng.pick(r, #priest > 0 and priest or ctx.kits.characters.villager), lines = Game.hintLines(ctx, r),
			})
		end
		-- stairs down to the crypt in a front corner of the nave
		if ctx.cell.below and ctx.cell.below.from == "inside" then
			helpers.stairsDown(area, ctx, { { 3, 3 }, { area.cols - 2, 3 }, { 3, area.rows - 2 }, { area.cols - 2, area.rows - 2 } }, anchors)
		end
		-- pews: two columns either side of the aisle
		for y = 4, area.rows - 2 do
			for _, x in ipairs({ mx - 2, mx - 1, mx + 2, mx + 3 }) do
				layout.tryPlace(area, x, y, rng.pick(r, kit.pew), Game.walls.church.pew, anchors)
			end
		end
		for y = 3, area.rows - 1 do
			area.reserved[layout.key(mx, y)] = nil
			area.reserved[layout.key(mx + 1, y)] = nil
		end
		area.reserved[layout.key(mx, area.rows - 1)] = true
		area.reserved[layout.key(mx + 1, area.rows - 1)] = true
		chest(area, ctx, anchors, { { area.cols - 2, 3 }, { 3, 3 }, { area.cols - 2, 4 }, { 3, 4 } })
		helpers.scatter(area, r, 0.05, kit.floor, Game.walls.church.floor, anchors)
	end,
}

Game.areaKinds.crypt = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.crypt
		area.surface = "concrete"
		local anchors = helpers.shapedRoom(area, ctx, { shape = "crypt", walls = kit.wall, exit = ctx.kits.objects.stairsUp })
		chest(area, ctx, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.belowEnemies or 0, kit.enemy, 1)
		lineWalls(area, r, 0.5, kit.grave, Game.walls.crypt.grave, anchors)
		helpers.scatter(area, r, 0.05, kit.candle, Game.walls.crypt.candle, anchors)
		helpers.scatter(area, r, 0.08, kit.decor, Game.walls.crypt.decor, anchors)
	end,
}

Game.areaKinds.cave = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.cave
		area.surface = "concrete"
		local anchors = helpers.shapedRoom(area, ctx, { shape = "cave", walls = ctx.kits.build, exit = ctx.kits.objects.stairsUp })
		chest(area, ctx, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.belowEnemies or 0, kit.enemy, 1)
		for _, s in ipairs(area.enemySpawns) do
			anchors[#anchors + 1] = { s.x, s.y }
		end
		helpers.scatter(area, r, 0.08, kit.rock, Game.walls.cave.rock, anchors)
		helpers.scatter(area, r, 0.12, kit.decor, Game.walls.cave.decor, anchors)
	end,
}

Game.areaKinds.cellar = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.ruins
		area.surface = "concrete"
		local anchors = helpers.shapedRoom(area, ctx, { shape = "cave", walls = ctx.kits.build, exit = ctx.kits.objects.stairsUp })
		chest(area, ctx, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.belowEnemies or 0, kit.enemy, 1)
		helpers.scatter(area, r, 0.12, kit.rubble, false, anchors)
		helpers.scatter(area, r, 0.06, ctx.kits.dungeon.decor, Game.walls.dungeon.decor, anchors)
	end,
}

Game.areaKinds.ridge = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.ridge
		area.surface = "grass"
		local anchors = helpers.shapedRoom(area, ctx, { shape = "cave", walls = kit.edge, exit = ctx.kits.objects.stairsDown })
		chest(area, ctx, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.aboveEnemies or 0, kit.enemy, 1)
		for _, s in ipairs(area.enemySpawns) do
			anchors[#anchors + 1] = { s.x, s.y }
		end
		helpers.scatter(area, r, 0.08, kit.rock, Game.walls.ridge.rock, anchors)
		helpers.scatter(area, r, 0.12, kit.decor, Game.walls.ridge.decor, anchors)
	end,
}

Game.areaKinds.tower = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.tower
		area.surface = "concrete"
		local anchors = helpers.shapedRoom(area, ctx, { shape = "crypt", walls = kit.wall, exit = ctx.kits.objects.stairsDown })
		chest(area, ctx, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.aboveEnemies or 0, kit.enemy, 2)
		helpers.scatter(area, r, 0.1, kit.pillar, Game.walls.tower.pillar, anchors)
		helpers.scatter(area, r, 0.06, kit.decor, Game.walls.tower.decor, anchors)
	end,
}
