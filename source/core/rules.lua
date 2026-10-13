-- The law of interaction (Rulebook Chapter 5): when something happens to
-- an object (the trigger), if its conditions hold, its effects happen;
-- otherwise its `otherwise` effects do.
--
--   { on = "bump", when = { has = { "key" } },
--     does = { take = "key", status = "open" },
--     otherwise = { say = { "The door is locked." } } }
--
-- Triggers: use (Ⓐ facing it), bump (walking into it), defeat (an enemy at
-- 0 hit points), enter (walking into its area; not fired yet).
--
-- Conditions (all must hold):
--   has    = { "key", "lamp" }   carry each listed item
--   has    = { coin = 3 }        carry at least that many
--   status = { [objectId] = s }  that object has that status
--   is = s                       this object has status s
--
-- Effects happen in this fixed order (a Lua table has no key order):
-- take, give, status, shove, drop, sound, toast, say, win. `say` shows its
-- lines and `win` waits for the dialogue to close. `shove = true` pushes
-- the object's cover one cell away from the player (a secret's grave).
--
-- ctx is what the rules act on, given by the caller (scenes/explore.lua):
--   player          has(id, n), give(id), take(id)
--   statusOf(id)    another object's status, for `status` conditions
--   objectStatus(obj)  this object's status, for `is`
--   setStatus(obj, s), shove(obj), drop(item, x, y), sound(name), toast(text),
--   say(lines, onDone), win()

local rules = {}

local function holds(when, obj, ctx)
	if not when then
		return true
	end
	if when.has then
		for k, v in pairs(when.has) do
			local id, n = k, v
			if type(k) == "number" then
				id, n = v, 1
			end
			if not ctx.player:has(id, n) then
				return false
			end
		end
	end
	if when.is then
		local s = ctx.objectStatus and ctx.objectStatus(obj) or ctx.statusOf(obj.id) or obj.initial
		if s ~= when.is then
			return false
		end
	end
	if when.status then
		for id, s in pairs(when.status) do
			if ctx.statusOf(id) ~= s then
				return false
			end
		end
	end
	return true
end

local function apply(does, obj, ctx)
	if does.take then
		ctx.player:take(does.take)
	end
	if does.give then
		ctx.player:give(does.give)
	end
	if does.status then
		ctx.setStatus(obj, does.status)
	end
	if does.shove and ctx.shove then
		ctx.shove(obj)
	end
	if does.drop then
		ctx.drop(does.drop, obj.x, obj.y)
	end
	if does.sound then
		ctx.sound(does.sound)
	end
	if does.toast then
		ctx.toast(does.toast)
	end
	if does.say then
		ctx.say(does.say, does.win and ctx.win or nil)
	elseif does.win then
		ctx.win()
	end
end

-- Runs the object's first rule for this trigger. Returns true if it had one.
function rules.fire(trigger, obj, ctx)
	for _, rule in ipairs(obj.rules or {}) do
		if rule.on == trigger then
			if holds(rule.when, obj, ctx) then
				apply(rule.does or {}, obj, ctx)
			elseif rule.otherwise then
				apply(rule.otherwise, obj, ctx)
			end
			return true
		end
	end
	return false
end

rules.holds = holds

Game.rules = rules
