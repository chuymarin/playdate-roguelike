-- The map screen: the 4x4 world on one 400x240 screen, each area 100x60
-- with its tiles at 8px (a quarter of the room size). Only areas you've
-- visited show; the one you're in has a blinking frame. Ⓐ or Ⓑ goes back.

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

function MapScreen.new(world, explore, onClose)
	return setmetatable({ world = world, explore = explore, onClose = onClose, frame = 0 }, MapScreen)
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
	for k in pairs(world.visited) do
		local area = world.areas["c" .. k]
		if area then
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
	end
	-- where you are: your tile (or your house door, when inside) and a blinking frame
	local k = here.cell.k
	local ax, ay = (k % config.MAP) * AREA_W, (k // config.MAP) * AREA_H
	local outside = world.areas["c" .. k]
	local px, py = self.explore.player.x, self.explore.player.y
	if here.interior and outside.house then
		px, py = outside.house.x, outside.house.y
	end
	if (self.frame // 8) % 2 == 0 then
		gfx.setColor(gfx.kColorWhite)
		gfx.drawRect(ax, ay, AREA_W, AREA_H)
		tiles.draw(SMALL, Game.kits.characters.player[1], ax + config.ORIGIN_X // SCALE + (px - 1) * SMALL, ay + config.ORIGIN_Y // SCALE + (py - 1) * SMALL)
	end

	local label = "Seed " .. world.seed
	local w = gfx.getTextSize(label) + 12
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(400 - w - 4, 240 - 24, w, 20)
	gfx.drawText(label, 400 - w + 2, 240 - 22)
end

Game.MapScreen = MapScreen
