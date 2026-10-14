-- House interior: a walled room in the dark (helpers.shapedRoom) with the
-- door at the end of a short corridor out of the bottom, a table and
-- chairs, furniture along the walls. Home (the start town's house) holds the
-- first chest, with the shield; other houses have a villager with hints
-- about their region: where its key is, where the sword is (until Act II),
-- and which way the gate out is (Rulebook B.3).

local layout <const> = Game.layout
local rng <const> = Game.rng
local helpers <const> = Game.areaHelpers
local config <const> = Game.config

-- "north-east" etc. from one world cell to another.
local function compass(from, to)
	local dx, dy = to % config.MAP - from % config.MAP, to // config.MAP - from // config.MAP
	local ns = dy < 0 and "north" or dy > 0 and "south" or ""
	local ew = dx > 0 and "east" or dx < 0 and "west" or ""
	if ns ~= "" and ew ~= "" then
		return ns .. "-" .. ew
	end
	return ns .. ew
end

local PLACE_NAMES = {
	forest = "the forest", ruins = "the ruins", town = "a town", camp = "a camp",
	entrance = "the clearing by the dungeon", dungeon = "the dungeon",
	ruinedTown = "the ruined town", church = "the church", cemetery = "the cemetery",
	creepyForest = "the dark woods", mountain = "the mountain",
}

-- "the ruins to the north-east", or "this town" for the villager's own cell.
local function where(gen, here, k)
	if k == here then
		return Game.text.hereTown
	end
	return PLACE_NAMES[gen.cells[k].kind] .. " to the " .. compass(here, k)
end

local function hintLines(ctx, r)
	local gen, here, act = ctx.world.gen, ctx.cell.k, ctx.cell.act
	local text = Game.text
	local lines = { rng.pick(r, text.greetings) }
	if gen.keys and gen.keys[act] then
		local k = gen.keys[act]
		lines[#lines + 1] = text.hintKey:format(where(gen, here, k))
		local below = gen.cells[k].below
		if below and gen.cells[k].chestAt == "below" and below.cover then
			lines[#lines + 1] = text["hint_" .. below.cover]
		elseif gen.cells[k].chestAt == "above" then
			lines[#lines + 1] = text.hint_above
		end
	end
	if gen.sword and act <= gen.cells[gen.sword].act then
		lines[#lines + 1] = text.hintSword:format(where(gen, here, gen.sword))
	end
	local gate = gen.gates[act]
	if gate then
		local dir = gate.from == here and text.hereGate or ("to the " .. compass(here, gate.from))
		lines[#lines + 1] = text.hintGate:format(dir)
	end
	return lines
end
Game.hintLines = hintLines

Game.areaKinds.house = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.house
		area.surface = "wood"
		local anchors = helpers.shapedRoom(area, ctx, { shape = "house", walls = kit.wall, exit = kit.door })

		-- the home chest against a wall, far from the door; a villager near the middle
		local free = layout.freeCells(area, { area.entry })
		if ctx.cell.role == "start" then
			area.home = true
			local wall = {}
			for i = #free, 1, -1 do
				local c = free[i]
				for _, d in ipairs(Game.grid.DIRS) do
					if area.solid[c[2] + d[2]][c[1] + d[1]] then
						wall[#wall + 1] = c
						break
					end
				end
			end
			local c = helpers.placeSolid(area, wall, anchors)
			if c then
				Game.objects.add(area, "chest", c[1], c[2], { item = ctx.cell.chest, tile = ctx.kits.objects.chestClosed[1], openTile = ctx.kits.objects.chestOpen[1], openBlocks = ctx.kits.objects.chestOpen[1] ~= nil or nil })
			end
		else
			local c = helpers.placeSolid(area, layout.byCenter(area, free), anchors)
			if c then
				Game.objects.add(area, "villager", c[1], c[2], {
					tile = rng.pick(r, ctx.kits.characters.villager), lines = hintLines(ctx, r),
				})
			end
		end

		-- a table with a chair each side, then furniture along the walls
		if #kit.table > 0 then
			for _, c in ipairs(layout.shuffledInterior(area, r)) do
				local x, y = c[1], c[2]
				local ok = x > 2 and x < area.cols - 1
				for dx = -1, 1 do
					local k = layout.key(x + dx, y)
					ok = ok and not area.solid[y][x + dx] and area.tiles[y][x + dx] == nil and not area.reserved[k] and not area.occupied[k]
				end
				if ok and layout.tryPlace(area, x, y, rng.pick(r, kit.table), Game.walls.house.table, anchors) then
					for _, dx in ipairs({ -1, 1 }) do
						layout.tryPlace(area, x + dx, y, rng.pick(r, kit.chair), Game.walls.house.chair, anchors)
					end
					break
				end
			end
		end
		for _, c in ipairs(helpers.alongWalls(area, r)) do
			if r() < 0.45 then
				layout.tryPlace(area, c[1], c[2], rng.pick(r, kit.furniture), Game.walls.house.furniture, anchors)
			end
		end
		helpers.scatter(area, r, 0.08, kit.floor, Game.walls.house.floor, anchors)
	end,
}
