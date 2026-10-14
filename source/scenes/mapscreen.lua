-- The map screen: the 4x4 world on one 400x240 screen, each area 100x60
-- with its tiles at 8px (a quarter of the room size). It shows the layer
-- you're on (outside, inside, below or above), and only the areas of that
-- layer you've visited; the one you're in has a blinking frame. A thick
-- line marks where one act's region meets another's, with a gap at the
-- gate outside (the gate itself shows locked or open in the area's
-- border). Ⓐ or Ⓑ goes back.

local gfx <const> = playdate.graphics
local pd <const> = playdate
local config <const> = Game.config
local tiles <const> = Game.tiles
local pickup <const> = Game.pickup

local MapScreen = {}
MapScreen.__index = MapScreen

local SCALE <const> = 4
local SMALL <const> = config.TILE // SCALE
local AREA_W <const>, AREA_H <const> = 400 // config.MAP, 240 // config.MAP
local BORDER <const> = 2
local GATE_GAP <const> = 18

function MapScreen.new(world, explore, onClose)
	return setmetatable({ world = world, explore = explore, onClose = onClose, frame = 0 }, MapScreen)
end

-- The areas the map draws: the visited ones on `layer` ("c", "h", "u",
-- "a"), as a map cell k -> area.
function MapScreen.shown(world, layer)
	local out = {}
	for k = 0, config.MAP * config.MAP - 1 do
		local area = world.visited[layer .. k] and world.areas[layer .. k]
		if area then
			out[k] = area
		end
	end
	return out
end

function MapScreen:update()
	self.frame = self.frame + 1
	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		self.onClose()
	end
end

function MapScreen:draw()
	gfx.clear(gfx.kColorBlack)
	local world, here = self.world, self.explore.area
	local layer = here.id:sub(1, 1)
	local shown = MapScreen.shown(world, layer)
	for k, area in pairs(shown) do
		local ax = (k % config.MAP) * AREA_W + config.ORIGIN_X // SCALE
		local ay = (k // config.MAP) * AREA_H + config.ORIGIN_Y // SCALE
		local function toMap(x, y)
			return ax + (x - 1) * SMALL, ay + (y - 1) * SMALL
		end
		for y = 1, area.rows do
			for x = 1, area.cols do
				local tile = area.tiles[y][x]
				if tile then
					local px, py = toMap(x, y)
					tiles.draw(SMALL, tile, px, py)
				end
			end
		end
		Game.objects.draw(area, world, tiles, SMALL, toMap, true)
		pickup.draw(area, tiles, Game.kits, toMap, SMALL)
	end
	-- region borders: wherever a shown area meets another act's area
	local cells = world.gen.cells
	gfx.setColor(gfx.kColorWhite)
	for k in pairs(shown) do
		local ax, ay = (k % config.MAP) * AREA_W, (k // config.MAP) * AREA_H
		for _, d in ipairs(Game.grid.DIRS) do
			local nx, ny = k % config.MAP + d[1], k // config.MAP + d[2]
			local other = nx >= 0 and ny >= 0 and nx < config.MAP and ny < config.MAP and cells[ny * config.MAP + nx]
			if other and other.act ~= cells[k].act then
				-- a gap in the line where the gate is
				local gap = layer == "c" and cells[k].gates[d[3]] and GATE_GAP or 0
				if d[3] == "N" or d[3] == "S" then
					local y = d[3] == "N" and ay - 1 or ay + AREA_H - 1
					local half = (AREA_W - gap) // 2
					gfx.fillRect(ax, y, half, BORDER)
					gfx.fillRect(ax + AREA_W - half, y, half, BORDER)
				else
					local x = d[3] == "W" and ax - 1 or ax + AREA_W - 1
					local half = (AREA_H - gap) // 2
					gfx.fillRect(x, ay, BORDER, half)
					gfx.fillRect(x, ay + AREA_H - half, BORDER, half)
				end
			end
		end
	end

	-- where you are: your tile and a blinking frame
	local k = here.cell.k
	local ax, ay = (k % config.MAP) * AREA_W, (k // config.MAP) * AREA_H
	local px, py = self.explore.player.x, self.explore.player.y
	if (self.frame // 8) % 2 == 0 then
		gfx.setColor(gfx.kColorWhite)
		gfx.drawRect(ax, ay, AREA_W, AREA_H)
		tiles.drawSolid(SMALL, Game.kits.characters.player[1], ax + config.ORIGIN_X // SCALE + (px - 1) * SMALL, ay + config.ORIGIN_Y // SCALE + (py - 1) * SMALL)
	end

	local label = Game.text.mapLayers[layer] .. " - Seed " .. world.seed
	local w = gfx.getTextSize(label) + 12
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(400 - w - 4, 240 - 24, w, 20)
	gfx.drawText(label, 400 - w + 2, 240 - 22)
end

Game.MapScreen = MapScreen
