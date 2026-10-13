-- Tile picks per area kind: config/kits.json (made with the Kit Builder
-- artifact). Numbers are sheet indices (from 0); the image tables in
-- tiles/tileset.lua hold sheet tile n at index n + 1.
--
-- Game.walls: for the slots where it's a choice (decor, furniture, trees
-- in the open...), the set of tiles that block movement; a slot's other
-- tiles can be walked over.

local data <const> = Game.loadConfig("kits")

Game.kits = data.kits

Game.walls = {}
for kind, slots in pairs(data.walls or {}) do
	Game.walls[kind] = {}
	for slot, tiles in pairs(slots) do
		local set = {}
		for _, t in ipairs(tiles) do
			set[t] = true
		end
		Game.walls[kind][slot] = set
	end
end
