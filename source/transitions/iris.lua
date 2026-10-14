-- "iris": a circle closes on the hero, the screen stays black a moment,
-- then a circle opens on the hero in the new room.
-- Options: hold (0 to 1, the share of the time spent black; default 0.15).

local gfx <const> = playdate.graphics

local mask -- reused every frame: black with a clear hole

-- Distance from (x, y) to the farthest screen corner: a circle this big
-- shows the whole screen.
local function cover(x, y)
	local w, h = math.max(x, 400 - x), math.max(y, 240 - y)
	return math.sqrt(w * w + h * h)
end

Game.transitions.register("iris", {
	draw = function(p, from, to, info, options)
		local hold = options.hold or 0.15
		local half = (1 - hold) / 2
		local image, x, y, open
		if p < half then
			image, x, y, open = from, info.fromX, info.fromY, 1 - p / half
		elseif p > 1 - half then
			image, x, y, open = to, info.toX, info.toY, (p - (1 - half)) / half
		else
			gfx.setColor(gfx.kColorBlack)
			gfx.fillRect(0, 0, 400, 240)
			return
		end
		image:draw(0, 0)
		mask = mask or gfx.image.new(400, 240)
		gfx.pushContext(mask)
		gfx.clear(gfx.kColorBlack)
		gfx.setColor(gfx.kColorClear)
		gfx.fillCircleAtPoint(x, y, math.floor(cover(x, y) * open))
		gfx.popContext()
		mask:draw(0, 0)
	end,
})
