-- Cemetery: a fenced graveyard with a gap in its fence, graves inside and
-- dead trees around. When the cell has stairs down (data/places.lua), one
-- grave hides them: walk into it to push it aside. The crypt below holds
-- the area's chest.

local layout <const> = Game.layout
local rng <const> = Game.rng
local helpers <const> = Game.areaHelpers

local YARDS = { { 6, 5 }, { 5, 5 }, { 6, 4 }, { 5, 4 }, { 4, 4 } }

-- The fence: a w x h rectangle at a random free spot with a gap in the
-- side facing the room's middle row. Returns the cells inside it, or nil.
local function placeYard(area, r, kit, anchors)
	for _, size in ipairs(YARDS) do
		local w, h = size[1], size[2]
		local spots = {}
		for y0 = 2, area.rows - h do
			for x0 = 2, area.cols - w do
				spots[#spots + 1] = { x0, y0 }
			end
		end
		for i = #spots, 2, -1 do
			local j = rng.int(r, 1, i)
			spots[i], spots[j] = spots[j], spots[i]
		end
		for _, s in ipairs(spots) do
			local x0, y0 = s[1], s[2]
			local x1, y1 = x0 + w - 1, y0 + h - 1
			local free = true
			for y = y0, y1 do
				for x = x0, x1 do
					local k = layout.key(x, y)
					if area.tiles[y][x] ~= nil or area.solid[y][x] or area.reserved[k] then
						free = false
					end
				end
			end
			if free then
				-- the gap: in the bottom side if there's room below, else the top
				local gapY = y1 < area.rows - 1 and y1 or y0
				local gapX = rng.int(r, x0 + 1, x1 - 1)
				local outside = { gapX, gapY == y1 and y1 + 1 or y0 - 1 }
				local inside = { gapX, gapY == y1 and y1 - 1 or y0 + 1 }
				local fence = {}
				for y = y0, y1 do
					for x = x0, x1 do
						local edge = x == x0 or x == x1 or y == y0 or y == y1
						if edge and not (x == gapX and y == gapY) then
							layout.set(area, x, y, rng.pick(r, kit.fence), true)
							fence[#fence + 1] = { x, y }
						end
					end
				end
				local all = { table.unpack(anchors) }
				all[#all + 1] = outside
				all[#all + 1] = inside
				if outside[2] > 1 and outside[2] < area.rows and layout.connected(area, all) then
					area.reserved[layout.key(gapX, gapY)] = true
					area.reserved[layout.key(inside[1], inside[2])] = true
					anchors[#anchors + 1] = inside
					local cells = {}
					for y = y0 + 1, y1 - 1 do
						for x = x0 + 1, x1 - 1 do
							if not area.reserved[layout.key(x, y)] then
								cells[#cells + 1] = { x, y }
							end
						end
					end
					return cells
				end
				for _, c in ipairs(fence) do
					layout.set(area, c[1], c[2], nil, false)
				end
			end
		end
	end
	return nil
end

Game.areaKinds.cemetery = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.cemetery
		area.surface = "grass"
		layout.border(area, r, kit.border)
		layout.openings(area, ctx, kit.border)
		local anchors = layout.anchors(area)
		local yard = placeYard(area, r, kit, anchors)
		if not yard then
			layout.addHub(area)
			anchors = layout.anchors(area)
		end
		local graves = yard or layout.shuffledInterior(area, r)
		-- the grave hiding the crypt: the one farthest in
		if ctx.cell.below and ctx.cell.below.from == "outside" then
			local far = {}
			local free = layout.freeCells(area, { anchors[#anchors] })
			local inYard = {}
			for _, c in ipairs(graves) do
				inYard[layout.key(c[1], c[2])] = true
			end
			for i = #free, 1, -1 do
				if inYard[layout.key(free[i][1], free[i][2])] then
					far[#far + 1] = free[i]
				end
			end
			helpers.stairsDown(area, ctx, far, anchors)
		end
		helpers.placeChest(area, ctx, anchors)
		for _, c in ipairs(graves) do
			if r() < 0.45 then
				layout.tryPlace(area, c[1], c[2], rng.pick(r, kit.grave), Game.walls.cemetery.grave, anchors)
			end
		end
		helpers.scatter(area, r, 0.10, kit.tree, Game.walls.cemetery.tree, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.enemies, kit.enemy, 1)
		helpers.scatter(area, r, 0.08, kit.decor, Game.walls.cemetery.decor, anchors)
	end,
}
