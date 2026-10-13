-- The story tables (Rulebook Appendices A and B): config/story.json, one
-- row per act plus the enemy table. Editing it changes worlds without
-- touching code; run tools/story_check.lua afterwards to make sure every
-- seed can still be finished. (The objects' rules are in data/objects.lua.)
--
--   name    the act's title, shown when you first walk into its region
--   kinds   [kind, weight] rolled for the act's areas, in this order (the
--           start town and Act IV's entrance and rooms are fixed)
--           (a kind left out of this world, see data/places.lua, is skipped)
--   camps   at most this many camps in the act
--   chests  what the act's chests hold, placed in this order, one area each:
--             at = "home"      the start town (its chest is in the home)
--             at = "entrance"  Act IV's entrance
--             at = "farthest"  the area farthest from where you come into
--                              the region (Act I: from home)
--             at = "any"       a random area that has no chest yet
--             at = "rest"      every area left (never the captive's room)

-- enemies: per area kind, a count from min to max (each extra one with the
-- given chance); insides and lower levels are counted on their own. Act I
-- has at most `firstAct` (you can only push them there), and an area
-- holding one of the `alone` items has just one.

Game.story = Game.loadConfig("story")
