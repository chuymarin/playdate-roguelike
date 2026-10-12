-- Sound effects (built by tools/build_sounds.py into sounds/). Samples load
-- the first time they play.

local audio = {}

local samples = {}
local STEP_VARIATIONS <const> = 5
local lastStep = {}

local function sample(name)
	if samples[name] == nil then
		samples[name] = playdate.sound.sampleplayer.new("sounds/" .. name) or false
	end
	return samples[name]
end

-- Names: sword, shield, hit, hurt, chest, pickup, unlock, door, locked, faint, win.
function audio.play(name)
	local s = sample(name)
	if s then
		s:play()
	end
end

-- A footstep for the surface ("grass", "wood", "concrete"), never the same
-- variation twice in a row.
function audio.step(surface)
	local i = math.random(0, STEP_VARIATIONS - 1)
	if i == lastStep[surface] then
		i = (i + 1) % STEP_VARIATIONS
	end
	lastStep[surface] = i
	audio.play("steps/" .. surface .. "_" .. i)
end

Game.audio = audio
