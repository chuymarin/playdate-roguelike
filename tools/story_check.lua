-- Story check: rolls many worlds with the game's own code and checks that
-- each one follows the Rulebook and can be finished (Rule 6.1). Run it
-- after editing data/story.lua or data/objects.lua, before building.
--
--   lua tools/story_check.lua [count] [--no-areas] [--source DIR] [--dump]
--
-- count       seeds 1..count (default 5000)
-- --no-areas  skip building every area (faster; areas are built for the
--             first 500 seeds by default to check every object's holes)
-- --source    the game's source folder (default: ../source next to this file)
-- --dump      instead of checking, print one line per seed describing its
--             world (tiling, act order, entrance, captive, then per cell: act,
--             shape, kind, role, chest, enemies, links, gates, dungeon door),
--             to compare with the Room Scale Lab's port of the generator
--
-- Needs plain Lua 5.4. Exits with status 1 if any check fails.

local count, buildAreas, source, dump = 5000, true, nil, false
local i = 1
while arg[i] do
	if arg[i] == "--no-areas" then
		buildAreas = false
	elseif arg[i] == "--dump" then
		dump = true
	elseif arg[i] == "--source" then
		i = i + 1
		source = arg[i]
	else
		count = assert(tonumber(arg[i]), "usage: lua tools/story_check.lua [count] [--no-areas] [--source DIR]")
	end
	i = i + 1
end
source = source or (arg[0]:match("^(.*)[/\\]") or ".") .. "/../source"

-- ---------- load the game's world code (no Playdate API needed) ----------

dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/json.lua")(source)
Game = {}
local SKIP = { ["CoreLibs/graphics"] = true, ["tiles/tileset"] = true, ["audio"] = true }
for line in io.lines(source .. "/main.lua") do
	local name = line:match('^import "([^"]+)"')
	if name and not SKIP[name] then
		if name:match("^entities/") then
			break -- everything from here on draws or plays
		end
		assert(loadfile(source .. "/" .. name .. ".lua"))()
	end
end

local MAP = Game.config.MAP
local grid, objects = Game.grid, Game.objects

-- ---------- checks ----------

local failures, failCount = {}, 0
local function fail(seed, msg)
	failCount = failCount + 1
	failures[msg] = failures[msg] or { n = 0, seeds = {} }
	local f = failures[msg]
	f.n = f.n + 1
	if #f.seeds < 5 then
		f.seeds[#f.seeds + 1] = seed
	end
end

-- The tables themselves, once.
local function checkTables()
	local story, items = Game.story, Game.items
	local problems = {}
	local function bad(msg)
		problems[#problems + 1] = msg
	end
	if not story.acts or #story.acts ~= 4 then
		bad("story.acts must have 4 acts")
		return problems
	end
	for act, row in ipairs(story.acts) do
		if not row.name or row.name == "" then
			bad(("act %d has no name"):format(act))
		end
		if act <= 3 then
			if not row.kinds or #row.kinds == 0 then
				bad(("act %d: kinds is empty"):format(act))
			end
			for _, k in ipairs(row.kinds or {}) do
				if not Game.areaKinds[k[1]] then
					bad(("act %d: unknown kind %s"):format(act, tostring(k[1])))
				end
				if type(k[2]) ~= "number" or k[2] <= 0 then
					bad(("act %d: kind %s needs a weight above 0"):format(act, tostring(k[1])))
				end
			end
		end
		if not row.chests or #row.chests == 0 then
			bad(("act %d: chests is empty"):format(act))
		end
		for n, c in ipairs(row.chests or {}) do
			if not items[c.item] then
				bad(("act %d chest %d: unknown item %s"):format(act, n, tostring(c.item)))
			end
		end
	end
	for kind, e in pairs(story.enemies or {}) do
		if not Game.areaKinds[kind] then
			bad("enemies: unknown kind " .. kind)
		end
		if not e.min or not e.max or e.min > e.max then
			bad("enemies: " .. kind .. " needs min <= max")
		end
	end
	-- every item a rule gives, takes, drops or needs exists
	for name, def in pairs(Game.objectKinds) do
		for _, rule in ipairs(def.rules or {}) do
			for _, part in ipairs({ rule.does or {}, rule.otherwise or {} }) do
				for _, key in ipairs({ "give", "take", "drop" }) do
					local v = part[key]
					if v and not v:match("^{%w+}$") and not items[v] then
						bad(("object %s: %s %s is not an item"):format(name, key, v))
					end
				end
			end
			for k, v in pairs(rule.when and rule.when.has or {}) do
				local id = type(k) == "number" and v or k
				if not items[id] then
					bad(("object %s: needs %s, which is not an item"):format(name, id))
				end
			end
		end
	end
	return problems
end

local function gateId(a, b)
	return "gate:" .. math.min(a, b) .. "-" .. math.max(a, b)
end

local function neighbor(k, dir)
	local d = grid.DELTA[dir]
	return k + d[1] + d[2] * MAP
end

-- Is the side (k, dir) a gate? Returns the template holding its rule.
local function gateOf(cell, dir)
	if cell.gates[dir] or cell.locked == dir or cell.lockedTo == dir then
		return Game.objectKinds.gate
	end
	return nil
end

-- Plays the world as a puzzle: walk everywhere reachable, open chests, open
-- any gate whose `bump` rule's conditions hold. Returns nil when the captive
-- can be freed, else why not.
local function solve(gen)
	local inv = {}
	local player = {
		has = function(_, id, n)
			return (inv[id] or 0) >= (n or 1)
		end,
	}
	local ctx = { player = player, statusOf = function() return nil end }
	local open, taken = {}, {}
	local function bumpRule(template)
		for _, rule in ipairs(template.rules) do
			if rule.on == "bump" then
				return rule
			end
		end
	end
	local reached, closed
	while true do
		reached = { [gen.start] = true }
		local queue = { gen.start }
		closed = {}
		while #queue > 0 do
			local k = table.remove(queue)
			local cell = gen.cells[k]
			if cell.chest and not taken[k] then
				taken[k] = true
				if not Game.items[cell.chest].heart then
					inv[cell.chest] = (inv[cell.chest] or 0) + 1
				end
			end
			for dir in pairs(cell.links) do
				local n = neighbor(k, dir)
				local gate = gateOf(cell, dir)
				if gate and not open[gateId(k, n)] then
					closed[#closed + 1] = { k, n, gate }
				elseif not reached[n] then
					reached[n] = true
					queue[#queue + 1] = n
				end
			end
		end
		local progress = false
		for _, g in ipairs(closed) do
			local id = gateId(g[1], g[2])
			if not open[id] then
				local rule = bumpRule(g[3])
				if Game.rules.holds(rule.when, nil, ctx) then
					open[id] = true
					if rule.does and rule.does.take then
						inv[rule.does.take] = inv[rule.does.take] - 1
					end
					progress = true
					break -- one gate at a time, like a player
				end
			end
		end
		if not progress then
			break
		end
	end
	if not reached[gen.goal] then
		local acts = {}
		for k in pairs(reached) do
			acts[gen.cells[k].act] = true
		end
		local top = 0
		for a in pairs(acts) do
			top = math.max(top, a)
		end
		local needs = {}
		for _, g in ipairs(closed) do
			for k, v in pairs(bumpRule(g[3]).when.has or {}) do
				needs[type(k) == "number" and v or k] = true
			end
		end
		local carry = {}
		for id, n in pairs(inv) do
			if n > 0 then
				carry[#carry + 1] = id
			end
		end
		table.sort(carry)
		local need = {}
		for id in pairs(needs) do
			need[#need + 1] = id
		end
		table.sort(need)
		return ("stuck in act %d: the way on needs %s, carrying %s"):format(
			top, table.concat(need, " + "), #carry > 0 and table.concat(carry, ", ") or "nothing")
	end
	local cellRule = bumpRule(Game.objectKinds.cell)
	if not Game.rules.holds(cellRule.when, nil, ctx) then
		return "reached the captive but can't open the cell"
	end
	return nil
end

-- Every "{hole}" in a template must be filled in the object, except a
-- status's tile or whether it blocks (an empty Kit Builder slot: not drawn).
local function holesFilled(template, obj, path)
	for k, v in pairs(template) do
		local p = path .. "." .. tostring(k)
		if path:match("%.tiles$") or path:match("%.blocks$") then
			-- optional
		elseif type(v) == "string" and v:match("^{%w+}$") then
			if obj == nil or obj[k] == nil then
				return p
			end
		elseif type(v) == "table" then
			local missing = holesFilled(v, obj and obj[k], p)
			if missing then
				return missing
			end
		end
	end
	return nil
end

local stats = { shapes = {}, oLoop = 0, oU = 0, kinds = { {}, {}, {}, {} }, hearts = 0, worlds = 0 }

local function checkWorld(seed, withAreas)
	local ok, gen = pcall(function()
		return Game.storyRoller.roll(Game.worldgen.generate(seed))
	end)
	if not ok then
		fail(seed, "error rolling the world: " .. tostring(gen))
		return
	end
	stats.worlds = stats.worlds + 1
	local cells = gen.cells

	-- 16 areas in 4 pieces of 4, each piece walkable inside
	for act = 1, 4 do
		local list = gen.actCells[act]
		if #list ~= 4 then
			fail(seed, "an act's piece doesn't have 4 areas")
		end
		local seen, queue = { [list[1]] = true }, { list[1] }
		while #queue > 0 do
			local k = table.remove(queue)
			for dir in pairs(cells[k].links) do
				local n = neighbor(k, dir)
				if cells[n].act == act and not seen[n] then
					seen[n] = true
					queue[#queue + 1] = n
				end
			end
		end
		for _, k in ipairs(list) do
			if not seen[k] then
				fail(seed, "a piece can't be walked end to end")
			end
		end
		local s = gen.shapes[act]
		stats.shapes[s.shape] = (stats.shapes[s.shape] or 0) + 1
		if s.shape == "O" then
			if s.loop then
				stats.oLoop = stats.oLoop + 1
			else
				stats.oU = stats.oU + 1
			end
		end
	end

	-- links between pieces are gates, exactly one per consecutive pair
	local gateSides = {}
	for k = 0, MAP * MAP - 1 do
		local cell = cells[k]
		for dir in pairs(cell.links) do
			local other = cells[neighbor(k, dir)]
			if other.act ~= cell.act then
				if not cell.gates[dir] then
					fail(seed, "two acts are linked without a gate")
				elseif math.abs(other.act - cell.act) ~= 1 then
					fail(seed, "a gate joins acts that aren't consecutive")
				end
				local low = math.min(cell.act, other.act)
				gateSides[low] = (gateSides[low] or 0) + 1
			end
		end
	end
	for act = 1, 3 do
		if gateSides[act] ~= 2 then -- one gate, counted from both sides
			fail(seed, ("acts %d and %d don't have exactly one gate"):format(act, act + 1))
		end
	end

	-- Act IV: the entrance is an end of its piece, beside Act III's gate
	local e = gen.entrance
	if cells[e].act ~= 4 or cells[e].kind ~= "entrance" then
		fail(seed, "the entrance isn't in Act IV")
	end
	if gen.gates[3].to ~= e then
		fail(seed, "Act III's gate doesn't lead into the entrance")
	end
	local inside = 0
	for dir in pairs(cells[e].links) do
		if cells[neighbor(e, dir)].act == 4 then
			inside = inside + 1
		end
	end
	if inside ~= 1 or not cells[e].locked then
		fail(seed, "the entrance isn't an end of its piece with one dungeon door")
	end
	if cells[gen.goal].act ~= 4 or cells[gen.goal].kind ~= "dungeon" then
		fail(seed, "the captive isn't in a dungeon room")
	end

	-- v1 items: shield at home in Act I, sword in Act II (Rule 3.1.3)
	if cells[gen.start].act ~= 1 or cells[gen.start].chest ~= "shield" then
		fail(seed, "the shield isn't in the home chest in Act I")
	end
	if not gen.sword or cells[gen.sword].act ~= 2 then
		fail(seed, "the sword isn't in Act II")
	end
	-- one chest per area, none in the captive's room (Rule B.1)
	for k = 0, MAP * MAP - 1 do
		if k == gen.goal then
			if cells[k].chest then
				fail(seed, "the captive's room has a chest")
			end
		elseif not cells[k].chest then
			fail(seed, "an area has no chest")
		elseif cells[k].chest == "heart" then
			stats.hearts = stats.hearts + 1
		end
		if cells[k].act and cells[k].kind then
			local t = stats.kinds[cells[k].act]
			t[cells[k].kind] = (t[cells[k].kind] or 0) + 1
		end
	end

	-- can it be won? (every condition's item reachable before it's needed)
	local why = solve(gen)
	if why then
		fail(seed, "can't be finished: " .. why)
	end

	-- build every area: every object's holes are filled, every chest is there
	if withAreas then
		local world = setmetatable({ seed = seed, gen = gen, areas = {}, visited = {}, status = {} }, Game.World)
		for k = 0, MAP * MAP - 1 do
			local okA, area = pcall(world.area, world, "c" .. k)
			if not okA then
				fail(seed, "error building an area: " .. tostring(area))
			else
				local all = { area }
				-- its inside and lower level, when there's a way to them
				local function layer(id)
					local okL, l = pcall(world.area, world, id)
					if okL then
						all[#all + 1] = l
						return l
					end
					fail(seed, "error building " .. id:sub(1, 1) .. " layer: " .. tostring(l))
				end
				local inside = area.door and layer("h" .. k)
				if area.down or (inside and inside.down) then
					layer("u" .. k)
				end
				local chests = 0
				for _, a in ipairs(all) do
					for _, obj in ipairs(a.objects) do
						local missing = holesFilled(Game.objectKinds[obj.template], obj, obj.template)
						if missing then
							fail(seed, "an object's hole isn't filled: " .. missing)
						end
						if obj.kind == "chest" then
							chests = chests + 1
							if obj.rules[1].does.drop ~= cells[k].chest then
								fail(seed, "a chest holds something else than its table row")
							end
						end
					end
				end
				if (cells[k].chest and 1 or 0) ~= chests then
					fail(seed, "an area's chest is missing in the built room")
				end
			end
		end
	end
end

-- ---------- run ----------

if dump then
	for seed = 1, count do
		local g = Game.storyRoller.roll(Game.worldgen.generate(seed))
		local parts = { seed, g.tiling, table.concat(g.order, ""), g.entrance, g.goal }
		for k = 0, MAP * MAP - 1 do
			local c = g.cells[k]
			local links, gates = "", ""
			for _, d in ipairs(grid.DIRS) do
				links = links .. (c.links[d[3]] and d[3] or "-")
				gates = gates .. (c.gates[d[3]] and tostring(c.gates[d[3]]) or "-")
			end
			parts[#parts + 1] = table.concat({ c.act, c.shape, c.kind, c.role or "-", c.chest or "-", c.enemies, links, gates,
				(c.locked or "-") .. (c.lockedTo or "-") }, ",")
		end
		print(table.concat(parts, " "))
	end
	os.exit(0)
end

local tableProblems = checkTables()
for _, p in ipairs(tableProblems) do
	print("TABLE: " .. p)
end
local areaSeeds = buildAreas and math.min(count, 500) or 0
for seed = 1, count do
	checkWorld(seed, seed <= areaSeeds)
end

print(("story check: %d seeds (%d with every area built)"):format(count, areaSeeds))
local function sortedKeys(t)
	local out = {}
	for k in pairs(t) do
		out[#out + 1] = k
	end
	table.sort(out)
	return out
end
local shapeLine = {}
for _, s in ipairs(sortedKeys(stats.shapes)) do
	shapeLine[#shapeLine + 1] = s .. "=" .. stats.shapes[s]
end
print("  piece shapes: " .. table.concat(shapeLine, " ") .. (" (O: %d loops, %d U)"):format(stats.oLoop, stats.oU))
for act = 1, 4 do
	local parts = {}
	for _, kind in ipairs(sortedKeys(stats.kinds[act])) do
		parts[#parts + 1] = kind .. "=" .. stats.kinds[act][kind]
	end
	print(("  act %d kinds: %s"):format(act, table.concat(parts, " ")))
end
print(("  heart chests per world: %.2f"):format(stats.hearts / math.max(1, stats.worlds)))
if failCount == 0 and #tableProblems == 0 then
	print("OK: every seed follows the rules and can be finished")
	os.exit(0)
end
for _, msg in ipairs(sortedKeys(failures)) do
	local f = failures[msg]
	local seeds = {}
	for _, s in ipairs(f.seeds) do
		seeds[#seeds + 1] = tostring(s)
	end
	print(("FAIL %s: %d seeds (e.g. %s)"):format(msg, f.n, table.concat(seeds, ", ")))
end
os.exit(1)
