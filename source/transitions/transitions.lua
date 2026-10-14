-- Screen transitions: what you see while moving from one room to another.
--
-- The game only says what kind of move it is:
--   edge   walking off a room's edge into the next area (or through a
--          passage between lower or upper levels)
--   layer  a door, stairs or a cave mouth: going inside, outside, down
--          or up
-- config/settings.json `transitions` picks the effect for each kind (and
-- its length in frames, plus anything else the effect reads), so the
-- effect is changed there, never in the game code.
--
-- An effect is a table registered under a name (transitions/slide.lua,
-- iris.lua, fade.lua, cut.lua; a new one is a new file that calls
-- register, and an import in main.lua):
--
--   effect.draw(p, from, to, info, options)
--     p        0 to 1, how far along (eased)
--     from,to  images of the room before and after (400x240, no HUD)
--     info     dir ("N", "E", "S", "W": the way you went), fromX/fromY and
--              toX/toY (the hero's center on screen before and after), room
--              (x, y, w, h: where rooms are drawn)
--     options  the kind's settings.json table (effect, frames, ...)

local transitions = { effects = {} }

-- Off in headless tests that drive the game by frames (tools/sim).
transitions.enabled = true

function transitions.register(name, effect)
	transitions.effects[name] = effect
end

local Runner = {}
Runner.__index = Runner

-- Smooth start and end.
local function ease(t)
	return t * t * (3 - 2 * t)
end

-- A running transition for a move of `kind`, or nil when that kind has none
-- (no entry, 0 frames, or the "cut" effect). update() returns true when it's
-- over; draw() draws the current frame.
function transitions.start(kind, from, to, info)
	local options = Game.config.TRANSITIONS[kind]
	if not transitions.enabled or not options or (options.frames or 0) <= 0 then
		return nil
	end
	local effect = transitions.effects[options.effect]
	assert(effect, "settings.json transitions." .. kind .. ": no effect named " .. tostring(options.effect))
	if effect.instant then
		return nil
	end
	return setmetatable({ effect = effect, options = options, from = from, to = to, info = info, frame = 0 }, Runner)
end

function Runner:update()
	self.frame = self.frame + 1
	return self.frame >= self.options.frames
end

function Runner:draw()
	local p = ease(math.min(self.frame / self.options.frames, 1))
	self.effect.draw(p, self.from, self.to, self.info, self.options)
end

Game.transitions = transitions
