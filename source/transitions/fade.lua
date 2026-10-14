-- "fade": the old room fades to black through the screen's dither
-- patterns, then the new one fades in.
-- Options: dither (a playdate.graphics dither name: "bayer8x8", "bayer4x4",
-- "diagonalLine", "floydSteinberg"...; default "bayer8x8").

local gfx <const> = playdate.graphics

local DITHERS <const> = {
	bayer2x2 = gfx.image.kDitherTypeBayer2x2,
	bayer4x4 = gfx.image.kDitherTypeBayer4x4,
	bayer8x8 = gfx.image.kDitherTypeBayer8x8,
	diagonalLine = gfx.image.kDitherTypeDiagonalLine,
	verticalLine = gfx.image.kDitherTypeVerticalLine,
	horizontalLine = gfx.image.kDitherTypeHorizontalLine,
	floydSteinberg = gfx.image.kDitherTypeFloydSteinberg,
	burkes = gfx.image.kDitherTypeBurkes,
	atkinson = gfx.image.kDitherTypeAtkinson,
	screen = gfx.image.kDitherTypeScreen,
}

Game.transitions.register("fade", {
	draw = function(p, from, to, info, options)
		local dither = DITHERS[options.dither or "bayer8x8"] or gfx.image.kDitherTypeBayer8x8
		gfx.setColor(gfx.kColorBlack)
		gfx.fillRect(0, 0, 400, 240)
		if p < 0.5 then
			from:drawFaded(0, 0, 1 - p * 2, dither)
		else
			to:drawFaded(0, 0, p * 2 - 1, dither)
		end
	end,
})
