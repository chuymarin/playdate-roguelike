-- Playdate stand-in for running the game in plain Lua 5.4 (used by the other
-- scripts here): records draw calls and sounds instead of showing them.
-- Records draw calls per frame; `frames` holds what was drawn on screen.
local stub = {}
local src = assert(SRC, "set SRC")
local loaded = {}
function import(name)
  if loaded[name] then return nil end
  loaded[name] = true
  if name:match("^CoreLibs") then return nil end
  local r = assert(loadfile(src .. "/" .. name .. ".lua"))()
  if name == "scenes/explore" then
    local new = Game.Explore.new
    Game.Explore.new = function(...) local e = new(...); stub.explore = e; return e end
  end
  return r
end

local screen = { list = {} }
local target = screen
local ctxStack = {}
local Canvas = {}; Canvas.__index = Canvas
function Canvas:draw(x, y) table.insert(target.list, { "canvas", self, x, y }) end
local Img = {}; Img.__index = Img
function Img:draw(x, y, flip) table.insert(target.list, { "tile", self.size, self.index, x, y, flip or "none" }) end
local Table = {}; Table.__index = Table
function Table:getImage(n) if n < 1 or n > 1078 then return nil end return setmetatable({ size = self.size, index = n - 1 }, Img) end

stub.pressed, stub.justPressed = {}, {}
stub.menu = {}
stub.sounds = {}
local textW = 7
playdate = {
  graphics = {
    kColorBlack = "black", kColorWhite = "white", kColorClear = "clear",
    kImageUnflipped = "none", kImageFlippedX = "flipX", kImageFlippedY = "flipY", kImageFlippedXY = "flipXY",
    kDrawModeCopy = "copy", kDrawModeFillWhite = "fillWhite",
    imagetable = { new = function(path) local s = tonumber(path:match("tiles(%d+)")); return setmetatable({ size = s }, Table) end },
    image = { new = function(w, h, color) return setmetatable({ list = { { "fill", 0, 0, w, h, color } } }, Canvas) end },
    pushContext = function(img) table.insert(ctxStack, target); target = img end,
    popContext = function() target = table.remove(ctxStack) end,
    clear = function(c) target.list = { { "fill", 0, 0, 400, 240, c } } end,
    setColor = function(c) stub.color = c end,
    setLineWidth = function() end,
    fillRect = function(x, y, w, h) table.insert(target.list, { "fill", x, y, w, h, stub.color }) end,
    drawRect = function(x, y, w, h) table.insert(target.list, { "rect", x, y, w, h, stub.color }) end,
    drawText = function(t, x, y) table.insert(target.list, { "text", t, x, y }) end,
    drawTextInRect = function(t, x, y, w, h) table.insert(target.list, { "text", t, x, y, w }) end,
    getTextSize = function(t) return #t * textW, 16 end,
    setBackgroundColor = function() end,
    setImageDrawMode = function() end,
  },
  sound = { sampleplayer = { new = function(path) return { play = function() table.insert(stub.sounds, path) end, stop = function() end } end } },
  getSystemMenu = function() return { addMenuItem = function(_, name, fn) stub.menu[name] = fn end } end,
  getSecondsSinceEpoch = function() return stub.time or 1 end,
  buttonJustPressed = function(b) return stub.justPressed[b] == true end,
  buttonIsPressed = function(b) return stub.pressed[b] == true end,
  kButtonA = "A", kButtonB = "B", kButtonUp = "up", kButtonDown = "down", kButtonLeft = "left", kButtonRight = "right",
}

-- One frame with the given buttons just pressed (and held).
function stub.frame(buttons, held)
  stub.justPressed, stub.pressed = {}, {}
  for _, b in ipairs(buttons or {}) do stub.justPressed[b] = true; stub.pressed[b] = true end
  for _, b in ipairs(held or {}) do stub.pressed[b] = true end
  playdate.update()
end

-- Flattens the screen's draw list (canvases inlined) into JSON-ish lines.
local function flatten(list, ox, oy, out)
  for _, c in ipairs(list) do
    if c[1] == "canvas" then flatten(c[2].list, ox + c[3], oy + c[4], out)
    elseif c[1] == "tile" then out[#out + 1] = ("T %d %d %d %d %s"):format(c[2], c[3], c[4] + ox, c[5] + oy, c[6])
    elseif c[1] == "fill" or c[1] == "rect" then out[#out + 1] = ("%s %d %d %d %d %s"):format(c[1] == "fill" and "F" or "R", c[2] + ox, c[3] + oy, c[4], c[5], c[6])
    elseif c[1] == "text" then out[#out + 1] = ("X %d %d %d %s"):format(c[3] + ox, c[4] + oy, c[5] or 0, (c[2]:gsub("\n", " "))) end
  end
  return out
end
function stub.snapshot(path)
  local f = io.open(path, "w"); f:write(table.concat(flatten(screen.list, 0, 0, {}), "\n"), "\n"); f:close()
end
function stub.boot()
  assert(loadfile(src .. "/main.lua"))()
end
return stub
