-- Camp: a safe clearing with a tent and a fire, never any enemies.
-- Walking in refills your hearts and makes it the place you wake up after
-- fainting.

local layout <const> = Game.layout
local rng <const> = Game.rng
local helpers <const> = Game.areaHelpers

Game.areaKinds.camp = {
	build = function(area, ctx)
		local r, kit = ctx.r, ctx.kits.camp
		area.surface = "grass"
		area.safe = true
		layout.border(area, r, kit.border)
		layout.openings(area, ctx, kit.border)
		layout.addHub(area)
		local anchors = layout.anchors(area)

		local cells = layout.byCenter(area, layout.freeCells(area, anchors))
		local tent
		for _, c in ipairs(cells) do
			if layout.tryPlace(area, c[1], c[2], rng.pick(r, kit.tent), true, anchors) then
				tent = c
				break
			end
		end
		if tent then
			for _, d in ipairs({ { 1, 1 }, { -1, 1 }, { 1, 0 }, { -1, 0 } }) do
				if layout.tryPlace(area, tent[1] + d[1], tent[2] + d[2], rng.pick(r, kit.fire), true, anchors) then
					break
				end
			end
		end
		local free = layout.byCenter(area, layout.freeCells(area, anchors))
		area.respawn = free[1] or anchors[1]
		area.reserved[layout.key(area.respawn[1], area.respawn[2])] = true
		helpers.scatter(area, r, 0.08, kit.decor, true, anchors)
	end,
}
