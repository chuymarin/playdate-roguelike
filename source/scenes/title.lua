-- The title screen, before every run and after it ends. Pages:
--
--   main      Start, Settings, Past runs
--   heroes    pick the hero to play, or make a new one (the name is typed
--             on the Playdate keyboard); Start goes straight to naming
--             when there's no hero yet
--   settings  one row per setting, ◀ ▶ changes it (for now: difficulty,
--             data/difficulty.lua); more rows come later
--   runs      the last runs from runs.txt (core/profile.lua)
--
-- Up/down moves, Ⓐ picks, Ⓑ goes back a page. Texts: text.json `title`.

local gfx <const> = playdate.graphics
local pd <const> = playdate
local profile <const> = Game.profile
local difficulty <const> = Game.difficulty

local Title = {}
Title.__index = Title

local ROW_H <const> = 24
local LIST_Y <const> = 80
local RUNS_SHOWN <const> = 8

-- onStart(hero): start a run with that hero.
function Title.new(onStart)
	local self = setmetatable({ onStart = onStart, frame = 0 }, Title)
	self:open("main")
	return self
end

local function T()
	return Game.text.title
end

-- The rows of a page: { label, act = function } (settings rows also have
-- value/change).
function Title:rows(page)
	local t = T()
	if page == "main" then
		return {
			{ label = t.start, act = function() self:start() end },
			{ label = t.settings, act = function() self:open("settings") end },
			{ label = t.runs, act = function() self:open("runs") end },
		}
	elseif page == "heroes" then
		local rows = {}
		for _, name in ipairs(profile.heroes()) do
			rows[#rows + 1] = { label = name, act = function() self:play(name) end }
		end
		rows[#rows + 1] = { label = t.newHero, act = function() self:nameHero() end }
		return rows
	elseif page == "settings" then
		return {
			{
				label = t.difficulty,
				value = function() return difficulty.current.name end,
				note = function() return self:difficultyNote(difficulty.current) end,
				change = function(step) self:stepDifficulty(step) end,
			},
		}
	end
	return {}
end

function Title:open(page)
	self.page, self.rowsCache, self.message = page, self:rows(page), nil
	self.index = 1
	if page == "heroes" then
		-- start on the hero played last
		for i, row in ipairs(self.rowsCache) do
			if row.label == profile.hero() then
				self.index = i
			end
		end
	elseif page == "runs" then
		self.runLines = profile.runs(RUNS_SHOWN)
	end
end

function Title:start()
	if #profile.heroes() == 0 then
		self:open("heroes")
		self:nameHero()
	else
		self:open("heroes")
	end
end

function Title:play(name)
	profile.pickHero(name)
	self.onStart(name)
end

-- Opens the keyboard; Ⓐ on OK makes the hero and starts the run.
function Title:nameHero()
	local kb = pd.keyboard
	self.naming = true
	kb.keyboardWillHideCallback = function(ok)
		self.naming = false
		if not ok then
			return
		end
		local name = profile.addHero(kb.text)
		if name then
			self:play(name)
		else
			self.message = T().badName
		end
	end
	kb.show("")
end

function Title:stepDifficulty(step)
	local list, at = difficulty.list, 1
	for i, d in ipairs(list) do
		if d == difficulty.current then
			at = i
		end
	end
	local d = list[(at - 1 + step) % #list + 1]
	difficulty.apply(d.id)
	profile.setSetting("difficulty", d.id)
end

-- "5 hearts, 3 shield pushes": what a difficulty means, in short.
function Title:difficultyNote(d)
	local c = Game.config
	return (T().difficultyNote):format(c.MAX_HEARTS, Game.items.shield.pushesToDefeat or 0)
end

function Title:update()
	self.frame = self.frame + 1
	if self.naming or (pd.keyboard and pd.keyboard.isVisible and pd.keyboard.isVisible()) then
		return
	end
	local rows = self.rowsCache
	if pd.buttonJustPressed(pd.kButtonB) then
		if self.page ~= "main" then
			self:open("main")
		end
		return
	end
	if #rows == 0 then
		if pd.buttonJustPressed(pd.kButtonA) then
			self:open("main")
		end
		return
	end
	if pd.buttonJustPressed(pd.kButtonUp) then
		self.index = (self.index - 2) % #rows + 1
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		self.index = self.index % #rows + 1
	end
	local row = rows[self.index]
	if row.change then
		if pd.buttonJustPressed(pd.kButtonLeft) then
			row.change(-1)
		elseif pd.buttonJustPressed(pd.kButtonRight) then
			row.change(1)
		end
	end
	if pd.buttonJustPressed(pd.kButtonA) then
		if row.act then
			row.act()
		elseif self.page == "settings" then
			self:open("main")
		end
	end
end

-- Draws text centered in the screen's first `width` pixels (all of it).
local function centered(text, y, width)
	width = width or 400
	local w = gfx.getTextSize(text)
	gfx.drawText(text, (width - w) // 2, y)
end

function Title:draw()
	local t = T()
	gfx.clear(gfx.kColorWhite)
	gfx.setColor(gfx.kColorBlack)
	if self.naming then
		-- the keyboard covers the right side
		local left = 400 - (pd.keyboard.width and pd.keyboard.width() or 0)
		centered(t.name, 24, left)
		centered(t.nameHero, LIST_Y - 8, left)
		gfx.drawRect(12, LIST_Y + ROW_H - 4, left - 24, ROW_H)
		centered((pd.keyboard.text or "") .. "_", LIST_Y + ROW_H, left)
		return
	end
	centered(t.name, 24)
	local heading = self.page ~= "main" and t[self.page .. "Heading"]
	if heading then
		centered(heading, 50)
	elseif profile.hero() then
		centered((t.playing):format(profile.hero()), 50)
	end

	if self.page == "runs" then
		if #self.runLines == 0 then
			centered(t.noRuns, LIST_Y)
		end
		for i, line in ipairs(self.runLines) do
			local r = profile.parseRun(line)
			local text = (t.runLine):format((r.date or ""):sub(6, 10), r.hero or "?", r.result or "?", (r.act or ""):gsub("act ", ""))
			gfx.drawText(text, 24, LIST_Y + (i - 1) * 18)
		end
	else
		for i, row in ipairs(self.rowsCache) do
			local label = row.label
			if row.value then
				label = label .. ":  < " .. row.value() .. " >"
			end
			local y = LIST_Y + (i - 1) * ROW_H
			centered(label, y)
			if i == self.index then
				local w = gfx.getTextSize(label)
				gfx.drawRect((400 - w) // 2 - 8, y - 4, w + 16, ROW_H)
			end
		end
		local row = self.rowsCache[self.index]
		if row and row.note then
			centered(row.note(), LIST_Y + #self.rowsCache * ROW_H + 12)
		end
	end
	if self.message then
		centered(self.message, 186)
	end
	centered(self.page == "main" and t.hintMain or self.page == "runs" and t.hintRuns or t.hintBack, 212)
end

Game.Title = Title
