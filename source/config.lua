-- Game-wide constants, and the loader for the settings files in config/
-- (JSON you can edit without touching the code; see config/README.md).
-- Screen layout: rooms are 12x7 tiles of 32px (384x224), placed 8px in
-- from the sides with a 16px HUD strip on top. The 4x4 map screen shows
-- every area at 8px tiles, 100x60px per area.

-- JSON numbers can come back as floats: whole ones become integers (tile
-- indices, counts), and keys starting with "_" are notes, dropped.
local function clean(v)
	if type(v) == "number" then
		return math.tointeger(v) or v
	end
	if type(v) == "table" then
		local out = {}
		for k, x in pairs(v) do
			if not (type(k) == "string" and k:sub(1, 1) == "_") then
				out[k] = clean(x)
			end
		end
		return out
	end
	return v
end

-- Reads config/<name>.json.
function Game.loadConfig(name)
	local path = "config/" .. name .. ".json"
	local data = json.decodeFile(path)
	assert(data, "can't read " .. path .. " (is it valid JSON?)")
	return clean(data)
end

local settings <const> = Game.loadConfig("settings")

Game.config = {
	TILE = 32,
	COLS = 12,
	ROWS = 7,
	ORIGIN_X = 8,
	ORIGIN_Y = 16,
	HUD_HEIGHT = 16,

	MAP = 4,      -- the world is MAP x MAP cells

	-- from config/settings.json
	MAX_HEARTS = settings.maxHearts,
	SEEDS = settings.seeds or {}, -- per area kind: build every one from this seed
	WALK_REPEAT_DELAY = settings.walkRepeatDelay, -- frames held before walking repeats
	WALK_REPEAT_EVERY = settings.walkRepeatEvery,
	EFFECT_FRAME_TIME = settings.effectFrameTime, -- frames each tile of an effect shows
	SWING_FRAMES = settings.swingFrames, -- the sword stays out
	GUARD_FRAMES = settings.guardFrames, -- the shield stays up
	HURT_FRAMES = settings.hurtFrames, -- you blink and can't be hurt again
	ENEMY_CHASE_RANGE = settings.enemyChaseRange, -- tiles: closer than this, enemies chase
	ENEMY_CHASE_FRAMES = settings.enemyChaseFrames, -- frames between steps, chasing
	ENEMY_WANDER_FRAMES = settings.enemyWanderFrames, -- and wandering
	ENEMY_IDLE_CHANCE = settings.enemyIdleChance, -- a wandering enemy stands still
	ENEMY_STUN_FRAMES = settings.enemyStunFrames, -- after a push or a hit
	TRANSITIONS = settings.transitions or {}, -- per kind of move: { effect, frames, ... } (transitions/)
}
