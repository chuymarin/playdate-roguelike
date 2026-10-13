-- House interior: wall border, an exit door in the middle of the bottom
-- wall, furniture along the walls. Home (the start town's house) holds the
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
		lines[#lines + 1] = text.hintKey:format(where(gen, here, gen.keys[act]))
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

Game.areaKinds.house = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.house
		area.surface = "wood"
		area.interior = true
		layout.border(area, r, kit.wall)
		local ex = layout.midX(area)[1]
		layout.set(area, ex, area.rows, rng.pick(r, kit.door), false)
		local outside = ctx.parent.house
		area.portals[#area.portals + 1] = { x = ex, y = area.rows, to = ctx.parent.id, toX = outside.frontX, toY = outside.frontY, facing = "S" }
		area.entry = { ex, area.rows - 1 }
		area.reserved[layout.key(ex, area.rows - 1)] = true
		local anchors = { { ex, area.rows }, area.entry }

		local cells = layout.byCenter(area, layout.freeCells(area, { area.entry }))
		if ctx.cell.role == "start" then
			area.home = true
			local c = helpers.placeSolid(area, cells, anchors)
			if c then
				Game.objects.add(area, "chest", c[1], c[2], { item = ctx.cell.chest, tile = ctx.kits.items.chest[1] })
			end
		else
			local c = helpers.placeSolid(area, cells, anchors)
			if c then
				Game.objects.add(area, "villager", c[1], c[2], {
					tile = rng.pick(r, ctx.kits.characters.villager), lines = hintLines(ctx, r),
				})
			end
		end

		-- furniture: mostly against the top wall, some against the sides
		for x = 2, area.cols - 1 do
			if r() < 0.45 then
				layout.tryPlace(area, x, 2, rng.pick(r, kit.furniture), true, anchors)
			end
		end
		for y = 3, area.rows - 2 do
			for _, x in ipairs({ 2, area.cols - 1 }) do
				if r() < 0.3 then
					layout.tryPlace(area, x, y, rng.pick(r, kit.furniture), true, anchors)
				end
			end
		end
		helpers.scatter(area, r, 0.08, kit.floor, false, anchors)
	end,
}
