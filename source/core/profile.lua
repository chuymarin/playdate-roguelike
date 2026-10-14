-- What the game keeps between runs, in the Playdate's data folder for this
-- game (Data/com.jcmarin.roguelike on the device):
--
--   profile.json  the heroes made so far, the one last played, and the
--                 settings picked on the title screen (difficulty)
--   runs.txt      one line per finished run, newest last, fields split
--                 by " | ": date, hero, difficulty, seed, how it ended
--                 (completed, died, quit), the furthest act reached

local pd <const> = playdate

local profile = {}

local RUNS <const> = "runs.txt"
local MAX_NAME <const> = 12

local data

local function load()
	data = pd.datastore.read("profile") or {}
	data.heroes = data.heroes or {}
	data.settings = data.settings or {}
end

local function save()
	pd.datastore.write(data, "profile")
end

-- ---------- heroes ----------

function profile.heroes()
	return data.heroes
end

-- The hero playing (the last one picked), or nil.
function profile.hero()
	return data.hero
end

function profile.pickHero(name)
	data.hero = name
	save()
end

-- A name as it's kept: trimmed, at most MAX_NAME characters.
function profile.cleanName(name)
	name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	return name:sub(1, MAX_NAME)
end

-- Adds a hero and picks them. Returns the name kept, or nil when it's
-- empty or already taken.
function profile.addHero(name)
	name = profile.cleanName(name)
	if name == "" then
		return nil
	end
	for _, h in ipairs(data.heroes) do
		if h:lower() == name:lower() then
			return nil
		end
	end
	data.heroes[#data.heroes + 1] = name
	data.hero = name
	save()
	return name
end

-- ---------- settings ----------

function profile.setting(key)
	return data.settings[key]
end

function profile.setSetting(key, value)
	data.settings[key] = value
	save()
end

-- ---------- runs ----------

local function stamp()
	local t = pd.getTime()
	return ("%04d-%02d-%02d %02d:%02d"):format(t.year, t.month, t.day, t.hour, t.minute)
end

-- Adds a line to runs.txt. run: { hero, difficulty, seed, result
-- ("completed", "died" or "quit"), act (the furthest act reached) }.
function profile.logRun(run)
	local line = table.concat({ stamp(), run.hero or "?", run.difficulty or "?",
		"seed " .. (run.seed or 0), run.result, "act " .. (run.act or "?") }, " | ")
	local f = pd.file.open(RUNS, pd.file.kFileAppend)
	if f then
		f:write(line .. "\n")
		f:close()
	end
	return line
end

-- A runs.txt line as { date, hero, difficulty, seed, result, act }.
function profile.parseRun(line)
	local f = {}
	for field in (line .. " | "):gmatch("(.-) | ") do
		f[#f + 1] = field
	end
	return { date = f[1], hero = f[2], difficulty = f[3], seed = f[4], result = f[5], act = f[6] }
end

-- The last n lines of runs.txt, newest first.
function profile.runs(n)
	local lines = {}
	local f = pd.file.open(RUNS, pd.file.kFileRead)
	if f then
		while true do
			local line = f:readline()
			if not line then
				break
			end
			if line ~= "" then
				lines[#lines + 1] = line
			end
		end
		f:close()
	end
	local out = {}
	for i = #lines, math.max(1, #lines - n + 1), -1 do
		out[#out + 1] = lines[i]
	end
	return out
end

load()
Game.profile = profile
