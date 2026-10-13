-- Object templates (Rulebook 3.2 and 5.5). An object is an instance of one
-- of these (world/objects.lua): a string like "{item}" is a hole filled in
-- per object, so one chest template serves every chest.
--
--   kind     chest / gate / cell / npc / enemy (defaults to the template name)
--   status   the status it starts with
--   blocks   statuses in which nothing can walk onto it
--   tiles    the tile drawn for each status (none: nothing drawn)
--   persist  false: the status lives on the object, not in the world, so it
--            starts over each time you enter the area (enemies, Rule 3.2.3)
--   rules    see core/rules.lua (a drop lands on the nearest free cell
--            you can reach, never on the object itself)

local text <const> = Game.text

Game.objectKinds = {
	chest = {
		status = "closed",
		blocks = { closed = true, open = "{openBlocks}" }, -- an open chest is in the way only if it's drawn
		tiles = { closed = "{tile}", open = "{openTile}" },
		rules = {
			{ on = "use", when = { is = "closed" }, does = { status = "open", drop = "{item}", sound = "chest" } },
		},
	},

	gate = {
		status = "blocked",
		blocks = { blocked = true },
		tiles = { blocked = "{lockedTile}", open = "{openTile}" },
		rules = {
			{
				on = "bump",
				when = { has = { "key" } },
				does = { take = "key", status = "open", sound = "unlock", toast = text.unlocked },
				otherwise = { sound = "locked", say = "{lockedLines}" },
			},
		},
	},

	cell = {
		status = "locked",
		blocks = { locked = true },
		tiles = { locked = "{lockedTile}", open = "{openTile}" },
		rules = {
			{
				on = "bump",
				when = { has = { "cellKey" } },
				does = { take = "cellKey", status = "open", sound = "unlock", toast = text.cellOpened },
				otherwise = { sound = "locked", say = text.cellLocked },
			},
		},
	},

	captive = {
		kind = "npc",
		status = "waiting",
		blocks = { waiting = true, done = true },
		sprite = "{tile}",
		rules = {
			{ on = "use", does = { status = "done", say = text.goal, win = true } },
		},
	},

	villager = {
		kind = "npc",
		status = "waiting",
		blocks = { waiting = true, done = true },
		sprite = "{tile}",
		rules = {
			{ on = "use", does = { say = "{lines}" } },
		},
	},

	-- A grave or a web hiding a way down: walk into it or press Ⓐ on it.
	-- Open, it shows the stairs (or the cave mouth) under it, which you walk
	-- onto to go down (the area's portal there); a grave slides aside.
	secret = {
		status = "hidden",
		blocks = { hidden = true },
		tiles = { hidden = "{tile}", open = "{openTile}" },
		rules = {
			{ on = "bump", when = { is = "hidden" }, does = { status = "open", shove = "{slides}", sound = "door", toast = "{found}" } },
			{ on = "use", when = { is = "hidden" }, does = { status = "open", shove = "{slides}", sound = "door", toast = "{found}" } },
		},
	},

	enemy = {
		status = "alive",
		persist = false,
		rules = {
			{ on = "defeat", does = { status = "defeated", drop = "coin" } },
		},
	},
}
