-- Difficulty (config/settings.json `difficulties`): each one changes a few
-- settings from settings.json (hearts, how fast enemies move...) and the
-- shield's pushesToDefeat (items.json); whatever it leaves out stays as
-- the file says. The title screen's Settings picks one; the choice is
-- saved with the profile (core/profile.lua).

local config <const> = Game.config
local settings <const> = Game.loadConfig("settings")

-- settings.json keys a difficulty can change, and their Game.config names
local TUNABLE <const> = {
	maxHearts = "MAX_HEARTS",
	swingFrames = "SWING_FRAMES",
	guardFrames = "GUARD_FRAMES",
	hurtFrames = "HURT_FRAMES",
	enemyChaseRange = "ENEMY_CHASE_RANGE",
	enemyChaseFrames = "ENEMY_CHASE_FRAMES",
	enemyWanderFrames = "ENEMY_WANDER_FRAMES",
	enemyIdleChance = "ENEMY_IDLE_CHANCE",
	enemyStunFrames = "ENEMY_STUN_FRAMES",
}
local basePushes <const> = Game.items.shield.pushesToDefeat

local difficulty = {
	list = settings.difficulties or { { id = "normal", name = "Normal" } },
	default = settings.difficulty or "normal",
}

function difficulty.find(id)
	for _, d in ipairs(difficulty.list) do
		if d.id == id then
			return d
		end
	end
	return nil
end

-- Sets every tunable value from the difficulty `id` (unknown: the default).
-- Returns the difficulty applied.
function difficulty.apply(id)
	local d = difficulty.find(id) or difficulty.find(difficulty.default) or difficulty.list[1]
	for key, name in pairs(TUNABLE) do
		config[name] = d[key] or settings[key]
	end
	Game.items.shield.pushesToDefeat = d.pushesToDefeat or basePushes
	difficulty.current = d
	return d
end

difficulty.apply(difficulty.default)
Game.difficulty = difficulty
