-- The item table (Rulebook 3.1): everything the hero can carry. The HUD
-- shows carried items in this order. Sprites are kits.items[id][1].
--
--   ability   what the item lets a button do: "swing" (Ⓐ) or "guard" (Ⓑ)
--   consumed  used up by the rule that needs it (keys); informational, the
--             rule's `take` effect does the removing
--   heart     taken at once: one more heart to hold, and all refilled
--   quiet     picked up with a sound and a toast instead of a dialogue
--   lines     what the dialogue says on pickup (Game.text)

local text <const> = Game.text

Game.items = {
	order = { "shield", "sword", "key", "cellKey", "coin" },
	shield = { ability = "guard", lines = text.shield },
	sword = { ability = "swing", lines = text.sword },
	key = { consumed = true, lines = text.key },
	cellKey = { consumed = true, lines = text.cellKey },
	heart = { heart = true, lines = text.heart },
	coin = { quiet = true, toast = text.coin },
}
