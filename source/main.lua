-- Entry point: imports every module once (Playdate's import returns nil
-- when a file is imported a second time, so modules never import each
-- other; each one adds itself to the Game table instead), builds a world
-- and runs the active scene.
--
-- System menu: "map" shows the world map, "new world" starts over with a
-- new seed.

Game = {}

import "CoreLibs/graphics"

import "config"
import "core/rng"
import "core/grid"
import "data/text"
import "tiles/kits"
import "data/items"
import "tiles/tileset"
import "audio"
import "core/rules"
import "data/objects"
import "world/objects"
import "world/worldgen"
import "world/world"
import "areas/layout"
import "areas/kinds"
import "areas/town"
import "areas/house"
import "areas/dungeon"
import "areas/forest"
import "areas/camp"
import "areas/area"
import "entities/player"
import "entities/enemy"
import "entities/npc"
import "entities/pickup"
import "ui/hud"
import "ui/dialogue"
import "scenes/explore"
import "scenes/mapscreen"

local pd <const> = playdate
local gfx <const> = pd.graphics

local world, explore, active

function Game.newWorld(seed)
	seed = seed or math.random(1, 99999)
	world = Game.World.new(seed)
	explore = Game.Explore.new(world, function()
		Game.newWorld()
	end)
	active = explore
end

local function toggleMap()
	if active == explore then
		active = Game.MapScreen.new(world, explore, function()
			active = explore
		end)
	else
		active = explore
	end
end

local menu = pd.getSystemMenu()
menu:addMenuItem("map", toggleMap)
menu:addMenuItem("new world", function()
	Game.newWorld()
end)

gfx.setBackgroundColor(gfx.kColorBlack)
math.randomseed(pd.getSecondsSinceEpoch())
Game.newWorld()

function pd.update()
	active:update()
	gfx.clear(gfx.kColorBlack)
	active:draw()
end
