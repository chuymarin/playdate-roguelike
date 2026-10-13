-- The story tables (Rulebook Appendices A and B): one row per act, plus the
-- enemy table. Editing these changes worlds without touching code; run
-- tools/story_check.lua afterwards to make sure every seed can still be
-- finished. (The objects' rules are in data/objects.lua.)
--
--   name    the act's title, shown when you first walk into its region
--   kinds   { kind, weight } rolled for the act's areas, in this order (the
--           start town and Act IV's entrance and rooms are fixed)
--   camps   at most this many camps in the act
--   chests  what the act's chests hold, placed in this order, one area each:
--             at = "home"      the start town (its chest is in the home)
--             at = "entrance"  Act IV's entrance
--             at = "farthest"  the area farthest from where you come into
--                              the region (Act I: from home)
--             at = "any"       a random area that has no chest yet
--             at = "rest"      every area left (never the captive's room)

Game.story = {
	acts = {
		{
			name = "Act I: Awakening",
			kinds = { { "forest", 1 }, { "ruins", 1 }, { "camp", 1 }, { "town", 1 } },
			camps = 1,
			chests = {
				{ item = "shield", at = "home" },
				{ item = "key", at = "farthest" },
				{ item = "heart", at = "rest" },
			},
		},
		{
			name = "Act II: The Road",
			kinds = { { "forest", 1 }, { "ruins", 1 }, { "camp", 1 }, { "town", 1 } },
			camps = 1,
			chests = {
				{ item = "key", at = "farthest" },
				{ item = "sword", at = "any" },
				{ item = "heart", at = "rest" },
			},
		},
		{
			name = "Act III: The Trial",
			kinds = { { "forest", 1 }, { "ruins", 1 }, { "camp", 1 } },
			camps = 1,
			chests = {
				{ item = "key", at = "farthest" },
				{ item = "heart", at = "rest" },
			},
		},
		{
			name = "Act IV: The Dungeon",
			chests = {
				{ item = "key", at = "entrance" },
				{ item = "cellKey", at = "farthest" },
				{ item = "heart", at = "rest" },
			},
		},
	},

	-- Enemies per area: a count from min to max (each extra one with the
	-- given chance). Act I has at most `firstAct` (you can only push them
	-- there), and an area holding one of the `alone` items has just one.
	enemies = {
		forest = { min = 1, max = 2, chance = 0.4 },
		ruins = { min = 1, max = 2, chance = 0.4 },
		entrance = { min = 1, max = 1 },
		dungeon = { min = 0, max = 1, chance = 0.7 },
	},
	firstAct = 1,
	alone = { "sword" },
}
