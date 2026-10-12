-- Town: one house per area, built from house wall tiles with a door you can
-- walk into (its inside is areas/house.lua), with dirt paths from every
-- doorway to the house door, a short fence and some trees and flowers.

local layout <const> = Game.layout
local rng <const> = Game.rng
local helpers <const> = Game.areaHelpers

local SIZES = { { 4, 3 }, { 3, 3 }, { 4, 2 }, { 3, 2 } }

-- Tries house rectangles (biggest first, random positions) until one keeps
-- every doorway connected to the spot in front of its door.
local function placeHouse(area, r, kit, anchors)
	for _, size in ipairs(SIZES) do
		local w, h = size[1], size[2]
		local spots = {}
		for hy = 2, area.rows - 1 - h do
			for hx = 2, area.cols - w do
				spots[#spots + 1] = { hx, hy }
			end
		end
		for i = #spots, 2, -1 do
			local j = rng.int(r, 1, i)
			spots[i], spots[j] = spots[j], spots[i]
		end
		for _, s in ipairs(spots) do
			local hx, hy = s[1], s[2]
			local doorX = hx + (w == 4 and rng.int(r, 1, 2) or 1)
			local doorY = hy + h - 1
			local front = { doorX, doorY + 1 }
			local windowX = doorX == hx + 1 and hx + w - 1 or hx
			for y = hy, hy + h - 1 do
				for x = hx, hx + w - 1 do
					local tile = rng.pick(r, kit.wall)
					if y == hy and #kit.roof > 0 then
						tile = rng.pick(r, kit.roof)
					elseif y == doorY and x == windowX and #kit.window > 0 then
						tile = rng.pick(r, kit.window)
					end
					layout.set(area, x, y, tile, true)
				end
			end
			layout.set(area, doorX, doorY, rng.pick(r, kit.door), false)
			local all = { table.unpack(anchors) }
			all[#all + 1] = front
			if layout.connected(area, all) then
				return { x = doorX, y = doorY, frontX = front[1], frontY = front[2], left = hx, right = hx + w - 1 }
			end
			for y = hy, hy + h - 1 do
				for x = hx, hx + w - 1 do
					layout.set(area, x, y, nil, false)
				end
			end
		end
	end
	return nil
end

Game.areaKinds.town = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.town
		area.surface = "grass"
		layout.border(area, r, kit.border)
		layout.openings(area, ctx, kit.border)
		local anchors = layout.anchors(area)

		local house = placeHouse(area, r, ctx.kits.house, anchors)
		if house then
			area.house = house
			area.reserved[layout.key(house.frontX, house.frontY)] = true
			anchors[#anchors + 1] = { house.frontX, house.frontY }
			local inside = layout.midX(area)[1]
			area.portals[#area.portals + 1] = {
				x = house.x, y = house.y, to = "h" .. ctx.cell.k, toX = inside, toY = area.rows - 1, facing = "N",
			}
			for _, a in ipairs(layout.anchors(area)) do
				layout.carvePath(area, r, a, { house.frontX, house.frontY }, kit.path)
			end
			-- a short fence off one side of the house
			local side = r() < 0.5 and -1 or 1
			local x0 = side < 0 and house.left - 1 or house.right + 1
			for i = 0, rng.int(r, 0, 2) do
				layout.tryPlace(area, x0 + side * i, house.y, rng.pick(r, kit.fence), true, anchors)
			end
		end

		helpers.scatter(area, r, 0.16, kit.tree, true, anchors)
		helpers.scatter(area, r, 0.10, kit.decor, false, anchors)
	end,
}
