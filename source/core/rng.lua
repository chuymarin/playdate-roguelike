-- Seeded random numbers (xorshift32). The same seed always gives the same
-- sequence, so a world seed rebuilds the same map, and every area gets its
-- own sub-seed derived from it. This is the same generator as the Room Scale
-- Lab artifact, so a seed there shows the same world map as in the game.

local rng = {}

local MASK <const> = 0xffffffff

-- Returns a function giving numbers in [0, 1).
function rng.new(seed)
	local s = math.floor(seed) & MASK
	if s == 0 then
		s = 1
	end
	return function()
		s = (s ~ (s << 13)) & MASK
		-- The lab's JavaScript shifts right with sign extension (its `>>` works
		-- on signed 32-bit numbers), so the top bit is copied down here too.
		local shifted = s >> 17
		if s & 0x80000000 ~= 0 then
			shifted = shifted | 0xffff8000
		end
		s = s ~ shifted
		s = (s ~ (s << 5)) & MASK
		-- Only the top 24 bits: on the Playdate, Lua numbers are 32 bits, so the
		-- full state reads as a negative integer when its top bit is set and
		-- s / 2^32 can round up to 1.0 as a float. 24 bits fit a float exactly.
		return ((s >> 8) & 0xffffff) / 16777216
	end
end

-- A random element of a list (nil for an empty list).
function rng.pick(r, list)
	if #list == 0 then
		return nil
	end
	return list[rng.int(r, 1, #list)]
end

-- An integer in [lo, hi]. Clamped because with 32-bit floats r() * n can
-- round up to n.
function rng.int(r, lo, hi)
	return math.min(hi, lo + math.floor(r() * (hi - lo + 1)))
end

-- A sub-seed for one part of the world (an area, a house...), so parts don't
-- share one long sequence: rebuilding one never shifts the others.
function rng.derive(seed, ...)
	local h = math.floor(seed) & MASK
	for _, v in ipairs({ ... }) do
		h = (h * 31 + v * 977 + 0x9e37) & MASK
		h = h ~ (h >> 15)
	end
	return h == 0 and 1 or h
end

Game.rng = rng
