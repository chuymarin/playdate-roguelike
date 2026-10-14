-- "slide": the old room slides out and the new one slides in from the side
-- you walked toward, like the screens of a map laid side by side. The HUD
-- stays put (it's drawn over the effect).

local gfx <const> = playdate.graphics
local grid <const> = Game.grid

Game.transitions.register("slide", {
	draw = function(p, from, to, info)
		local r = info.room
		local d = grid.DELTA[info.dir] or { 1, 0 }
		local dx, dy = math.floor(d[1] * r.w * p + 0.5), math.floor(d[2] * r.h * p + 0.5)
		gfx.setClipRect(r.x, r.y, r.w, r.h)
		from:draw(-dx, -dy)
		to:draw(d[1] * r.w - dx, d[2] * r.h - dy)
		gfx.clearClipRect()
	end,
})
