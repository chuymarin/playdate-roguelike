-- Entry point: imports every module once (Playdate's import returns nil
-- when a file is imported a second time, so modules never import each
-- other; each one adds itself to the Game table instead) and runs the
-- active scene: the title screen (scenes/title.lua), then a run in a new
-- world; when the run ends (completed, died or quit) it's logged
-- (core/profile.lua) and the title screen comes back.
--
-- System menu: "map" shows the world map, "quit run" ends the run and goes
-- back to the title screen.

Game = {}

import "CoreLibs/graphics"
import "CoreLibs/keyboard"

import "config"
import "core/rng"
import "core/grid"
import "data/text"
import "tiles/kits"
import "data/items"
import "data/difficulty"
import "core/profile"
import "tiles/tileset"
import "audio"
import "core/rules"
import "data/objects"
import "world/objects"
import "data/story"
import "data/places"
import "world/worldgen"
import "world/story"
import "world/world"
import "areas/layout"
import "areas/kinds"
import "areas/town"
import "areas/house"
import "areas/dungeon"
import "areas/forest"
import "areas/camp"
import "areas/cemetery"
import "areas/interiors"
import "areas/entrance"
import "areas/area"
import "entities/player"
import "entities/enemy"
import "entities/npc"
import "entities/pickup"
import "ui/hud"
import "ui/dialogue"
import "transitions/transitions"
import "transitions/cut"
import "transitions/slide"
import "transitions/iris"
import "transitions/fade"
import "scenes/explore"
import "scenes/mapscreen"
import "scenes/title"

local pd <const> = playdate
local gfx <const> = pd.graphics

local world, explore, active

-- The furthest act this run reached.
local function actReached()
	local best = 1
	for act in pairs(world.actsSeen) do
		best = math.max(best, act)
	end
	return best
end

-- Logs the run that's playing (result: "completed", "died" or "quit").
local function logRun(result)
	if world then
		Game.profile.logRun({
			hero = Game.profile.hero(),
			difficulty = Game.difficulty.current.id,
			seed = world.seed,
			result = result,
			act = actReached(),
		})
	end
	world, explore = nil, nil
end

function Game.showTitle()
	world, explore = nil, nil
	active = Game.Title.new(function()
		Game.newWorld()
	end)
end

-- Starts a run in a new world (from the seed, or a random one).
function Game.newWorld(seed)
	seed = seed or math.random(1, 99999)
	world = Game.World.new(seed)
	explore = Game.Explore.new(world, function(result)
		logRun(result)
		Game.showTitle()
	end)
	active = explore
end

local function toggleMap()
	if not explore then
		return
	end
	if active == explore then
		active = Game.MapScreen.new(world, explore, function()
			active = explore
		end)
	else
		active = explore
	end
end

-- The scene running (the title screen, a run, or the map).
function Game.scene()
	return active
end

local menu = pd.getSystemMenu()
menu:addMenuItem("map", toggleMap)
menu:addMenuItem("quit run", function()
	if explore then
		logRun("quit")
		Game.showTitle()
	end
end)

gfx.setBackgroundColor(gfx.kColorBlack)
math.randomseed(pd.getSecondsSinceEpoch())
Game.difficulty.apply(Game.profile.setting("difficulty"))
Game.showTitle()

function pd.update()
	active:update()
	gfx.clear(gfx.kColorBlack)
	active:draw()
end
