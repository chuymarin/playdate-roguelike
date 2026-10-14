-- The item table (Rulebook 3.1): config/items.json, everything the hero
-- can carry. The HUD always shows a slot for each item in `slots` (the
-- shield and the weapon: empty until found), then the other carried items
-- in `order`. Sprites:
-- Game.itemTile(id), one tile per world from the item's slot in kits.json.
--
--   ability   what the item lets a button do: "swing" (Ⓐ) or "guard" (Ⓑ)
--   consumed  used up by the rule that needs it (keys); informational, the
--             rule's `take` effect does the removing
--   heart     taken at once: one more heart to hold, and all refilled
--   quiet     picked up with a sound and a toast instead of a dialogue
--   lines     what the dialogue says on pickup: a key of text.json
--   toast     the toast instead (quiet items): a key of text.json

local text <const> = Game.text

local items = Game.loadConfig("items")
for id, def in pairs(items) do
	if id ~= "order" and id ~= "slots" then
		for _, field in ipairs({ "lines", "toast" }) do
			if def[field] then
				def[field] = assert(text[def[field]], "items.json: " .. id .. "." .. field .. " names no text")
			end
		end
	end
end
Game.items = items
