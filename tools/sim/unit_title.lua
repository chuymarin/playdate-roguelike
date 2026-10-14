-- The title screen: making a hero, settings (difficulty), past runs, and
-- coming back to it when a run ends.
--   lua unit_title.lua <source>
SRC = arg[1]
stub = dofile("stub.lua")
stub.boot(true)
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL " .. msg) end end
local profile, config = Game.profile, Game.config
local function onTitle() return getmetatable(Game.scene()) == Game.Title end
local function inRun() return getmetatable(Game.scene()) == Game.Explore end
check(onTitle(), "the game opens on the title screen, not a run")

-- Start with no hero: the keyboard opens to name one
stub.frame({ "A" })
check(stub.kbVisible, "Start with no hero opens the keyboard")
stub.typeName("   ", true)
check(onTitle() and #profile.heroes() == 0, "an empty name makes no hero")
-- cancel, then a real name
stub.frame({ "A" }) -- New hero (the only row)
check(stub.kbVisible, "New hero opens the keyboard")
stub.typeName("Ana", false)
check(onTitle(), "cancel stays on the title")
stub.frame({ "A" })
stub.typeName("  Ana the Brave and Bold  ", true)
check(inRun(), "naming a hero starts the run")
check(profile.hero() == "Ana the Brav", "names are trimmed to 12 characters: " .. tostring(profile.hero()))
check(stub.saved.profile.heroes[1] == "Ana the Brav", "the hero is saved")

-- quit run from the system menu: logged, back to the title
local seed = stub.explore.world.seed
stub.menu["quit run"]()
check(onTitle(), "quit run goes back to the title")
local r = profile.parseRun(profile.runs(1)[1])
check(r.result == "quit" and r.hero == "Ana the Brav" and r.seed == "seed " .. seed and r.act == "act 1" and r.difficulty == "normal", "quit is logged: " .. profile.runs(1)[1])
check(stub.files["runs.txt"]:find("Ana the Brav") ~= nil, "runs.txt holds the run")
stub.menu["map"]() -- the map does nothing on the title screen
stub.frame({})

-- a second hero, and the same name again is refused
stub.frame({ "A" }) -- Start -> heroes page
stub.frame({ "down" }); stub.frame({ "A" }) -- New hero
stub.typeName("ana the brav", true)
check(#profile.heroes() == 1 and onTitle(), "a taken name is refused")
stub.frame({ "A" })
stub.typeName("Bo", true)
check(#profile.heroes() == 2 and profile.hero() == "Bo", "a second hero")
stub.menu["quit run"]()

-- Settings: difficulty changes hearts and shield pushes, and is saved
stub.frame({ "down" }); stub.frame({ "A" }) -- Settings
stub.frame({ "right" })
check(Game.difficulty.current.id == "hard" and config.MAX_HEARTS == 2 and Game.items.shield.pushesToDefeat == 7, "Hard: 2 hearts, 7 pushes")
check(stub.saved.profile.settings.difficulty == "hard", "the difficulty is saved")
stub.frame({ "right" })
check(Game.difficulty.current.id == "easy" and config.MAX_HEARTS == 5 and config.ENEMY_CHASE_FRAMES == 18, "wraps to Easy")
stub.frame({ "left" })
check(Game.difficulty.current.id == "hard", "left wraps back to Hard")
stub.frame({ "B" }) -- back to main
-- the main page opens on Start
stub.frame({ "A" }); stub.frame({ "A" }) -- heroes page opens on Bo (last played)
check(inRun() and stub.explore.player.maxHearts == 2 and profile.hero() == "Bo", "a run on Hard starts with 2 hearts as Bo")
stub.menu["quit run"]()
check(profile.parseRun(profile.runs(1)[1]).difficulty == "hard", "the run logs its difficulty")
Game.difficulty.apply("normal")
check(config.MAX_HEARTS == 3 and Game.items.shield.pushesToDefeat == 5, "Normal is the file's values")

-- Past runs lists them, newest first
stub.frame({ "down" }); stub.frame({ "down" }); stub.frame({ "A" })
check(#profile.runs(8) == 3, "three runs logged")
check(profile.parseRun(profile.runs(8)[1]).hero == "Bo" and profile.parseRun(profile.runs(8)[3]).hero == "Ana the Brav", "newest first")
local ok = pcall(function() stub.frame({}) end)
check(ok, "the runs page draws")
stub.frame({ "B" })

-- a saved profile is read back when the game starts again
local saved, files = stub.saved, stub.files
Game = nil
stub = dofile("stub.lua")
stub.saved, stub.files = saved, files
stub.boot(true)
check(#Game.profile.heroes() == 2 and Game.profile.hero() == "Bo", "heroes come back")
check(Game.difficulty.current.id == "hard", "the difficulty comes back")
print(fails == 0 and "unit_title: all passed" or ("unit_title: " .. fails .. " failed"))
