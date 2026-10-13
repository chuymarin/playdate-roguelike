-- The story tables (Rulebook Appendix A): one row per act. Editing these
-- changes worlds without touching code; tools/story_check.lua checks that
-- every seed can still be finished.
--
--   name   the act's title, shown when you first walk into its region
--   kinds  { kind, weight } rolled for the act's areas, in this order (the
--          start town and Act IV's entrance and rooms are fixed)
--   camps  at most this many camps in the act

Game.story = {
	acts = {
		{
			name = "Act I: Awakening",
			kinds = { { "forest", 1 }, { "ruins", 1 }, { "camp", 1 }, { "town", 1 } },
			camps = 1,
		},
		{
			name = "Act II: The Road",
			kinds = { { "forest", 1 }, { "ruins", 1 }, { "camp", 1 }, { "town", 1 } },
			camps = 1,
		},
		{
			name = "Act III: The Trial",
			kinds = { { "forest", 1 }, { "ruins", 1 }, { "camp", 1 } },
			camps = 1,
		},
		{
			name = "Act IV: The Dungeon",
		},
	},
}
