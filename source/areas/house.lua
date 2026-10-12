-- House interior: wall border, an exit door in the middle of the bottom
-- wall, furniture along the walls. Home (the start town's house) holds the
-- first chest, with the shield; other houses have a villager with a hint.

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

local PLACE_NAMES = { forest = "the forest", ruins = "the ruins" }

local function hintLines(ctx, r)
	local gen, here = ctx.world.gen, ctx.cell.k
	local hints = {}
	for k, cell in pairs(gen.cells) do
		if cell.chest == "key" then
			hints[#hints + 1] = "They say the dungeon key is hidden in " .. PLACE_NAMES[cell.kind] .. " to the " .. compass(here, k) .. "."
		elseif cell.chest == "sword" then
			hints[#hints + 1] = "A sword was left in a chest in " .. PLACE_NAMES[cell.kind] .. " to the " .. compass(here, k) .. "."
		end
	end
	hints[#hints + 1] = "The dungeon door is to the " .. compass(here, gen.dungeonDoor.outside) .. ". Someone is locked up deep inside."
	table.sort(hints)
	return { rng.pick(r, Game.text.greetings), rng.pick(r, hints) }
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
				area.chests[#area.chests + 1] = { x = c[1], y = c[2], contents = "shield" }
			end
		else
			local c = helpers.placeSolid(area, cells, anchors)
			if c then
				area.npcs[#area.npcs + 1] = {
					x = c[1], y = c[2], tile = rng.pick(r, ctx.kits.characters.villager), lines = hintLines(ctx, r),
				}
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
