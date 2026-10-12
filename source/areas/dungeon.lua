-- Dungeon: wall border, scattered pillars, enemies with 2 hit points. The
-- entrance from the overworld is the locked door (see layout.openings).
--
-- The deepest room holds the NPC, locked in a barred cell against the
-- north or south wall (whichever has no doorway). The cell door opens with
-- the cell key, which is in a chest in another dungeon room.

local layout <const> = Game.layout
local rng <const> = Game.rng
local helpers <const> = Game.areaHelpers

-- The cell: two tiles wide, bars around it, the door in front of the NPC.
-- Cells are given for the north side; the south side mirrors them.
--   x: 5 6 7 8
--      B N . B   row 2 (against the wall)
--      B D B B   row 3
local function buildCell(area, ctx, kit)
	local r = ctx.r
	local mx = layout.midX(area)[1]
	local north = not ctx.cell.links.N
	local back = north and 2 or area.rows - 1
	local front = north and back + 1 or back - 1
	local function bars(x, y)
		layout.set(area, x, y, rng.pick(r, kit.bars), true)
	end
	bars(mx - 1, back)
	bars(mx + 2, back)
	bars(mx - 1, front)
	bars(mx + 1, front)
	bars(mx + 2, front)
	-- the door isn't solid: the explore scene blocks it until it's unlocked
	layout.set(area, mx, front, nil, false)
	area.cellLock = { x = mx, y = front, tile = rng.pick(r, kit.cellDoor), openTile = rng.pick(r, kit.cellOpen) }
	area.reserved[layout.key(mx, front)] = true
	area.reserved[layout.key(mx + 1, back)] = true
	area.occupied[layout.key(mx, back)] = true
	area.npcs[#area.npcs + 1] = {
		x = mx, y = back, tile = rng.pick(r, ctx.kits.characters.goal), lines = Game.text.goal, goal = true,
	}
end

Game.areaKinds.dungeon = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.dungeon
		area.surface = "concrete"
		layout.border(area, r, kit.wall)
		layout.openings(area, ctx, kit.wall)
		layout.addHub(area)
		local anchors = layout.anchors(area)

		if ctx.cell.role == "goal" then
			buildCell(area, ctx, kit)
		end
		if ctx.cell.chest then
			-- farthest from the doorways
			local cells = layout.freeCells(area, anchors)
			local far = {}
			for i = #cells, 1, -1 do
				far[#far + 1] = cells[i]
			end
			local c = helpers.placeSolid(area, far, anchors)
			if c then
				area.chests[#area.chests + 1] = { x = c[1], y = c[2], contents = ctx.cell.chest }
			end
		end

		helpers.scatter(area, r, 0.14, kit.pillar, true, anchors)
		helpers.spawnEnemies(area, r, ctx.cell.enemies, kit.enemy, 2)
		helpers.scatter(area, r, 0.06, kit.decor, false, anchors)
	end,
}
