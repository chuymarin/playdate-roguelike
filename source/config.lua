-- Game-wide constants. Screen layout: rooms are 12x7 tiles of 32px
-- (384x224), placed 8px in from the sides with a 16px HUD strip on top.
-- The 4x4 map screen shows every area at 8px tiles, 100x60px per area.

Game.config = {
	TILE = 32,
	COLS = 12,
	ROWS = 7,
	ORIGIN_X = 8,
	ORIGIN_Y = 16,
	HUD_HEIGHT = 16,

	MAP = 4,      -- the world is MAP x MAP cells

	MAX_HEARTS = 3,

	-- Seed overrides for testing one kind of area: set e.g. house = 42 and
	-- every house interior is built from seed 42 (nil = derived from the
	-- world seed, so each area is different but the same world always
	-- rebuilds the same way). Kinds: town, house, dungeon, forest, ruins, camp,
	-- entrance.
	SEEDS = {},
}
