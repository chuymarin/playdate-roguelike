-- A text box showing one line at a time; Ⓐ (or Ⓑ) shows the next, and
-- after the last line onDone runs. The box sits at the bottom of the
-- screen, or at the top when the player stands in the bottom half.

local gfx <const> = playdate.graphics
local pd <const> = playdate

local Dialogue = {}
Dialogue.__index = Dialogue

local BOX_X <const>, BOX_W <const>, BOX_H <const> = 16, 368, 64
local PAD <const> = 10

function Dialogue.new(lines, onDone, atTop)
	return setmetatable({ lines = lines, index = 1, onDone = onDone, atTop = atTop, age = 0 }, Dialogue)
end

-- Returns true once the last line has been dismissed.
function Dialogue:update()
	self.age = self.age + 1
	-- ignore the press that opened the box
	if self.age > 1 and (pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB)) then
		self.index = self.index + 1
		if self.index > #self.lines then
			return true
		end
	end
	return false
end

function Dialogue:draw()
	local y = self.atTop and 24 or 240 - BOX_H - 8
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(BOX_X, y, BOX_W, BOX_H)
	gfx.setColor(gfx.kColorBlack)
	gfx.setLineWidth(2)
	gfx.drawRect(BOX_X + 2, y + 2, BOX_W - 4, BOX_H - 4)
	gfx.setLineWidth(1)
	gfx.drawTextInRect(self.lines[self.index], BOX_X + PAD, y + PAD, BOX_W - PAD * 2, BOX_H - PAD * 2)
end

Game.Dialogue = Dialogue
