-- Registry of area generators, filled in by areas/town.lua, areas/house.lua,
-- etc. Each kind is { build = function(area, ctx) }, where ctx has:
--   world  the World (world/world.lua)
--   cell   the world cell this area sits in (world/worldgen.lua)
--   r      this area's own random sequence (see areas/area.lua)
--   kits   tile picks per kind (tiles/kits.lua)
--   parent the area you come from: the outdoor area for an inside ("h"),
--          the outdoor area or the inside for a lower level ("u")
-- Adding a kind: write areas/<kind>.lua, import it in main.lua.
--
-- Layers (data/places.lua): an outdoor area whose cell has an `inside`
-- builds a door to it (helpers.wayIn, area.door); the cell's lower level
-- (`below`) is reached by stairs, in the outdoor area or in the inside
-- (helpers.stairsDown / helpers.hiddenCave, area.down). Insides and lower
-- levels are shaped rooms (helpers.shapedRoom); lower levels also open
-- passages to their neighbors' (cell.underLinks).

Game.areaKinds = {}

local layout <const> = Game.layout
local rng <const> = Game.rng

-- Helpers several kinds use.
local helpers = {}

-- A free cell next to c that the anchors can reach, kept clear so the
-- player can always stand there (to open a chest or talk).
function helpers.standingSpot(area, c, anchors)
	local dist = layout.reach(area, { anchors[1] }, area.occupied)
	for _, d in ipairs({ { 0, 1 }, { -1, 0 }, { 1, 0 }, { 0, -1 } }) do
		local x, y = c[1] + d[1], c[2] + d[2]
		if dist[layout.key(x, y)] and x > 1 and y > 1 and x < area.cols and y < area.rows then
			area.reserved[layout.key(x, y)] = true
			return { x, y }
		end
	end
	return nil
end

-- Puts a solid thing (chest / NPC) on the first cell of `cells` that keeps
-- the anchors connected, and adds the spot in front of it as an anchor.
function helpers.placeSolid(area, cells, anchors)
	local c = layout.claimSolid(area, cells, anchors)
	if c then
		local spot = helpers.standingSpot(area, c, anchors)
		if spot then
			anchors[#anchors + 1] = spot
		end
	end
	return c
end

-- Enemy spawns, away from the doorways.
function helpers.spawnEnemies(area, r, count, tiles, hp)
	local cells = layout.spawnCells(area, 3)
	if #cells < count then
		cells = layout.spawnCells(area, 1)
	end
	for _ = 1, count do
		if #cells == 0 then
			return
		end
		local i = rng.int(r, 1, #cells)
		local c = table.remove(cells, i)
		layout.claimSpawn(area, c)
		area.enemySpawns[#area.enemySpawns + 1] = { x = c[1], y = c[2], tile = rng.pick(r, tiles), hp = hp }
	end
end

-- The area's chest (Rulebook B.1), the one step every kind shares: on the
-- free cell farthest from the doorways that keeps every doorway (and a
-- door or stairs) reachable. Kinds call it after making their ways in and
-- down and before scattering trees and decor, so there's always room.
-- Outdoors, the start town has no chest: its chest is in the home. Pass
-- the builder's anchors so the spot in front of the chest is added to them
-- and later scattering can't wall it off.
-- The chest is in one layer (cell.chestAt): each layer on the way there
-- sets area.chestOnward (to that layer) when it built the way on, and places the chest
-- itself when it couldn't. `prefer`: cells to try first.
function helpers.placeChest(area, ctx, anchors, prefer)
	local cell = ctx.cell
	if not cell.chest then
		return nil
	end
	if ctx.parent then
		if ctx.parent.chestOnward ~= area.id:sub(1, 1) then
			return nil
		end
	elseif area.id:sub(1, 1) ~= "c" then
		return nil -- a level spread over from a neighbor's: the chest isn't here
	elseif cell.role == "start" then
		return nil
	end
	if area.chestOnward then
		return nil
	end
	if not anchors then
		anchors = layout.anchors(area)
		if area.door then
			anchors[#anchors + 1] = { area.door.frontX, area.door.frontY }
		end
		if area.down then
			anchors[#anchors + 1] = { area.down.frontX, area.down.frontY }
		end
	end
	local cells = layout.freeCells(area, anchors)
	local far = {}
	local free = {}
	for _, c in ipairs(cells) do
		free[layout.key(c[1], c[2])] = true
	end
	for _, c in ipairs(prefer or {}) do
		if free[layout.key(c[1], c[2])] then
			far[#far + 1] = c
		end
	end
	-- against a wall first (so it stands aside, not in the way), farthest first
	local function againstWall(c)
		for _, d in ipairs(Game.grid.DIRS) do
			local x, y = c[1] + d[1], c[2] + d[2]
			if area.solid[y] and area.solid[y][x] then
				return true
			end
		end
		return false
	end
	for pass = 1, 2 do
		for i = #cells, 1, -1 do
			if againstWall(cells[i]) == (pass == 1) then
				far[#far + 1] = cells[i]
			end
		end
	end
	local c = helpers.placeSolid(area, far, anchors)
	if c then
		Game.objects.add(area, "chest", c[1], c[2], { item = ctx.cell.chest, tile = ctx.kits.objects.chestClosed[1], openTile = ctx.kits.objects.chestOpen[1], openBlocks = ctx.kits.objects.chestOpen[1] ~= nil or nil })
	end
	return c
end


-- Scatters tiles over free interior cells with the given chance each.
function helpers.scatter(area, r, chance, tiles, solid, anchors)
	if #tiles == 0 then
		return
	end
	for _, c in ipairs(layout.shuffledInterior(area, r)) do
		if r() < chance then
			layout.tryPlace(area, c[1], c[2], rng.pick(r, tiles), solid, anchors)
		end
	end
end

-- ---------- buildings, ways in and down ----------

local BUILDING_SIZES = { { 4, 3 }, { 3, 3 }, { 4, 2 }, { 3, 2 } }

-- A building (kit: wall, roof, window, door): tries rectangles (biggest
-- first, random positions) until one keeps every anchor connected to the
-- spot in front of its door. Returns { x, y, frontX, frontY, left, right }
-- for the door, or nil.
function helpers.placeBuilding(area, r, kit, anchors)
	for _, size in ipairs(BUILDING_SIZES) do
		local w, h = size[1], size[2]
		local spots = {}
		for hy = 2, area.rows - 1 - h do
			for hx = 2, area.cols - w do
				spots[#spots + 1] = { hx, hy }
			end
		end
		for i = #spots, 2, -1 do
			local j = rng.int(r, 1, i)
			spots[i], spots[j] = spots[j], spots[i]
		end
		for _, s in ipairs(spots) do
			local hx, hy = s[1], s[2]
			local free = true
			for y = hy, hy + h do
				for x = hx, hx + w - 1 do
					local k = layout.key(x, y)
					if area.tiles[y][x] ~= nil or area.solid[y][x] or area.reserved[k] or area.occupied[k] then
						free = false
					end
				end
			end
			if free then
				local doorX = hx + (w == 4 and rng.int(r, 1, 2) or 1)
				local doorY = hy + h - 1
				local front = { doorX, doorY + 1 }
				local windowX = doorX == hx + 1 and hx + w - 1 or hx
				for y = hy, hy + h - 1 do
					for x = hx, hx + w - 1 do
						local tile = rng.pick(r, kit.wall)
						if y == hy and kit.roof and #kit.roof > 0 then
							tile = rng.pick(r, kit.roof)
						elseif y == doorY and x == windowX and kit.window and #kit.window > 0 then
							tile = rng.pick(r, kit.window)
						end
						layout.set(area, x, y, tile, true)
					end
				end
				layout.set(area, doorX, doorY, rng.pick(r, kit.door), false)
				local all = { table.unpack(anchors) }
				all[#all + 1] = front
				if layout.connected(area, all) then
					return { x = doorX, y = doorY, frontX = front[1], frontY = front[2], left = hx, right = hx + w - 1 }
				end
				for y = hy, hy + h - 1 do
					for x = hx, hx + w - 1 do
						layout.set(area, x, y, nil, false)
					end
				end
			end
		end
	end
	return nil
end

-- Where a way leads: "h" the inside, entered from the middle of its
-- bottom wall; "u" the lower level, whose stairs back up sit on the same
-- cell as the way down (you arrive on the same spot you stood on).
local function entryX(area)
	return layout.midX(area)[1]
end

-- The cells a passage between lower or upper levels runs through on this
-- cell's sides (cell.underLinks, cell.overLinks): the middle of the side,
-- the cell inside it and one either side. Stairs stay off them, so the
-- stairs back on the other level never block a passage.
local function nearPassage(area, cell, x, y)
	for _, d in ipairs(Game.grid.DIRS) do
		if (cell.underLinks and cell.underLinks[d[3]]) or (cell.overLinks and cell.overLinks[d[3]]) then
			for _, c in ipairs(layout.sideCells(area, d[3])) do
				for i = 0, 1 do
					local px, py = c[1] - d[1] * i, c[2] - d[2] * i
					if math.abs(px - x) + math.abs(py - y) <= 1 then
						return true
					end
				end
			end
		end
	end
	return false
end
helpers.nearPassage = nearPassage

-- The direction from (x, y) to the neighboring cell (tx, ty).
local function dirTo(x, y, tx, ty)
	for _, d in ipairs(Game.grid.DIRS) do
		if x + d[1] == tx and y + d[2] == ty then
			return d[3]
		end
	end
	return "N"
end

-- Makes `way` (a cell walked onto to go through, and the spot in front of
-- it) the way into this cell's inside (layer "h", area.door), lower level
-- ("u", area.down) or upper level ("a", area.up): a portal there, the
-- front kept clear and added to the anchors. Sets chestOnward (to the layer) when the
-- chest lies that way.
function helpers.wayIn(area, ctx, way, anchors, layer)
	layer = layer or "h"
	if layer == "h" then
		area.door = way
	elseif layer == "u" then
		area.down = way
	else
		area.up = way
	end
	area.reserved[layout.key(way.frontX, way.frontY)] = true
	if anchors then
		anchors[#anchors + 1] = { way.frontX, way.frontY }
	end
	local portal = { x = way.x, y = way.y, to = layer .. ctx.cell.k, toX = entryX(area), toY = area.rows - 1, facing = "N" }
	if layer ~= "h" then
		portal.toX, portal.toY = way.frontX, way.frontY
		portal.facing = dirTo(way.x, way.y, way.frontX, way.frontY)
	end
	area.portals[#area.portals + 1] = portal
	local cell = ctx.cell
	local towardInside = layer == "h" and (cell.chestAt == "inside" or (cell.chestAt == "below" and cell.below.from == "inside"))
	local towardBelow = layer == "u" and cell.chestAt == "below"
	local towardAbove = layer == "a" and cell.chestAt == "above"
	if towardInside or towardBelow or towardAbove then
		area.chestOnward = layer
	end
end

-- A secret (data/objects.lua) covering stairs: hit it with the sword or
-- the shield.
-- `slides`: the cover is pushed one cell aside (if there's room) instead
-- of torn away.
local function hide(area, ctx, x, y, cover, openTile, slides, found)
	Game.objects.add(area, "secret", x, y, {
		tile = cover, openTile = openTile, slides = slides, found = found,
	}, "secret:" .. area.id)
end

-- The tile hiding stairs, for a cover name (data/places.lua), or nil.
local function coverTile(ctx, cover)
	local kits, r = ctx.kits, ctx.r
	local tiles = nil
	if cover == "grave" then
		tiles = #kits.cemetery.secret > 0 and kits.cemetery.secret or kits.cemetery.grave
	elseif cover == "rubble" then
		tiles = kits.ruins.rubble
	end
	return tiles and #tiles > 0 and rng.pick(r, tiles) or nil
end

-- Stairs down to the cell's lower level on the first of `cells` (tried in
-- order) that keeps the anchors connected, with a free spot in front;
-- under the cell's cover (a grave, rubble) or in plain sight. Returns
-- true when placed.
function helpers.stairsDown(area, ctx, cells, anchors)
	return helpers.stairs(area, ctx, cells, anchors, "u")
end

-- Stairs to the cell's lower ("u") or upper ("a") level; see stairsDown.
-- Stairs up are never hidden.
function helpers.stairs(area, ctx, cells, anchors, layer)
	local clear = {}
	for _, c in ipairs(cells) do
		if not nearPassage(area, ctx.cell, c[1], c[2]) then
			clear[#clear + 1] = c
		end
	end
	local c = layout.claimSolid(area, clear, anchors)
	if not c then
		return false
	end
	local spot = helpers.standingSpot(area, c, anchors)
	if not spot then
		area.occupied[layout.key(c[1], c[2])] = nil
		return false
	end
	local up = layer == "a"
	local stairs = rng.pick(ctx.r, up and ctx.kits.objects.stairsUp or ctx.kits.objects.stairsDown)
	local cover = not up and coverTile(ctx, ctx.cell.below.cover)
	if cover then
		hide(area, ctx, c[1], c[2], cover, stairs, true, Game.text.foundStairs)
	else
		layout.set(area, c[1], c[2], stairs, false)
	end
	helpers.wayIn(area, ctx, { x = c[1], y = c[2], frontX = spot[1], frontY = spot[2] }, anchors, layer)
	return true
end

-- Stairs up to the cell's upper level (cell.above, when it has its own
-- way up) on the free cell farthest from `from`. Returns true when placed.
function helpers.wayUp(area, ctx, anchors, from)
	local above = ctx.cell.above
	if not above or not above.from then
		return false
	end
	local free = layout.freeCells(area, from or anchors)
	local far = {}
	for i = #free, 1, -1 do
		far[#far + 1] = free[i]
	end
	return helpers.stairs(area, ctx, far, anchors, "a")
end

-- Stairs down on the free cell farthest from the cells `from`.
function helpers.farStairsDown(area, ctx, anchors, from)
	local free = layout.freeCells(area, from)
	local far = {}
	for i = #free, 1, -1 do
		far[#far + 1] = free[i]
	end
	return helpers.stairsDown(area, ctx, far, anchors)
end

-- A cave mouth in the north (else south) border, covered by a web (or
-- left open, cover "mouth"), next to a walkable cell the anchors reach,
-- away from the doorways: the farthest such spot. Leads to the lower
-- level. Returns true when placed.
function helpers.hiddenCave(area, ctx, anchors)
	local r, kit = ctx.r, ctx.kits.cave
	local dist = layout.reach(area, anchors, area.occupied)
	local best, bestD
	for _, side in ipairs({ { 1, 2 }, { area.rows, area.rows - 1 } }) do
		local y, iy = side[1], side[2]
		for x = 3, area.cols - 2 do
			local clear = true
			for _, o in ipairs(area.openings[y == 1 and "N" or "S"] or {}) do
				if math.abs(o[1] - x) <= 1 then
					clear = false
				end
			end
			local k = layout.key(x, iy)
			local d = dist[k]
			clear = clear and not nearPassage(area, ctx.cell, x, y) and not nearPassage(area, ctx.cell, x, iy)
			if d and clear and not area.occupied[k] and not area.spawnTaken[k] and (not bestD or d > bestD) then
				best, bestD = { x, y, iy }, d
			end
		end
		if best then
			break
		end
	end
	if not best then
		return false
	end
	local x, y, iy = best[1], best[2], best[3]
	layout.set(area, x, y, nil, false)
	if #kit.mouthRock > 0 then
		for _, dx in ipairs({ -1, 1 }) do
			layout.set(area, x + dx, y, rng.pick(r, kit.mouthRock), true)
		end
	end
	area.occupied[layout.key(x, y)] = true
	local web = ctx.kits.objects.web
	if ctx.cell.below.cover == "web" then
		hide(area, ctx, x, y, #web > 0 and rng.pick(r, web) or nil, rng.pick(r, kit.mouth), false, Game.text.foundCave)
	else
		layout.set(area, x, y, rng.pick(r, kit.mouth), false) -- an open cave mouth
	end
	helpers.wayIn(area, ctx, { x = x, y = y, frontX = x, frontY = iy }, anchors, "u")
	return true
end

-- The way down, when this cell's stairs are out here (data/places.lua
-- from = "outside"): a cave mouth in the border (maybe behind a web), or
-- stairs (maybe under a cover) on the free cell farthest from the
-- anchors. Returns true when placed.
function helpers.wayDown(area, ctx, anchors)
	local below = ctx.cell.below
	if not below or below.from ~= "outside" then
		return false
	end
	if below.cover == "web" or below.cover == "mouth" then
		return helpers.hiddenCave(area, ctx, anchors)
	end
	return helpers.farStairsDown(area, ctx, anchors, anchors)
end

-- ---------- shaped rooms: insides and lower levels ----------
-- A room is a floor shape floating in the dark: walls only on the cells
-- around the floor, nothing (and no way) anywhere else. Shapes:
--   house   a rectangle of random size, sometimes an alcove on top
--   church  a nave with an apse on top for the altar, a wide entrance
--   crypt   a brick rectangle against the left wall
--   cave    an uneven blob grown around the paths it must join
-- The way back up is a short corridor out of the bottom; a lower level's
-- passages are corridors to the middle of a side (cell.underLinks), some
-- blocked by a web or rubble you push away (a secret shared by both sides).

local function mark(floor, x, y)
	floor[layout.key(x, y)] = { x, y }
end

local function rect(floor, x0, y0, x1, y1)
	for y = y0, y1 do
		for x = x0, x1 do
			mark(floor, x, y)
		end
	end
end

-- The cells of an L-shaped path from a to b, along x first or y first.
local function lPath(a, b, xFirst)
	local out, x, y = { { a[1], a[2] } }, a[1], a[2]
	local function stepX()
		while x ~= b[1] do
			x = x + (b[1] > x and 1 or -1)
			out[#out + 1] = { x, y }
		end
	end
	local function stepY()
		while y ~= b[2] do
			y = y + (b[2] > y and 1 or -1)
			out[#out + 1] = { x, y }
		end
	end
	if xFirst then
		stepX()
		stepY()
	else
		stepY()
		stepX()
	end
	return out
end

-- A corridor from a to b: an L, never through a cell in `avoid` (the
-- stairs back up, which you can't walk across). When both Ls cross one,
-- the shortest way around inside the border.
local function corridor(floor, r, a, b, area, avoid)
	local first = r() < 0.5
	for _, xFirst in ipairs({ first, not first }) do
		local cells, ok = lPath(a, b, xFirst), true
		for _, c in ipairs(cells) do
			if avoid and avoid[layout.key(c[1], c[2])] then
				ok = false
			end
		end
		if ok then
			for _, c in ipairs(cells) do
				mark(floor, c[1], c[2])
			end
			return
		end
	end
	local prev, q, head = { [layout.key(a[1], a[2])] = false }, { a }, 1
	while head <= #q do
		local c = q[head]
		head = head + 1
		if c[1] == b[1] and c[2] == b[2] then
			break
		end
		for _, d in ipairs(Game.grid.DIRS) do
			local nx, ny = c[1] + d[1], c[2] + d[2]
			local k = layout.key(nx, ny)
			if prev[k] == nil and not avoid[k] and nx > 1 and ny > 1 and nx < area.cols and ny < area.rows then
				prev[k] = c
				q[#q + 1] = { nx, ny }
			end
		end
	end
	local c = prev[layout.key(b[1], b[2])] ~= nil and b or nil
	while c do
		mark(floor, c[1], c[2])
		c = prev[layout.key(c[1], c[2])]
	end
end

-- (x, y), or the nearest cell beside it, when it's one to avoid (the
-- stairs back up): where corridors meet.
local function meetAt(x, y, avoid)
	if not avoid[layout.key(x, y)] then
		return { x, y }
	end
	for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, -1 }, { 0, 1 }, { 1, -1 }, { -1, -1 } }) do
		if not avoid[layout.key(x + d[1], y + d[2])] then
			return { x + d[1], y + d[2] }
		end
	end
	return { x, y }
end

-- Each shape fills `floor` and returns its middle (corridors lead there).
local SHAPES = {}

function SHAPES.house(floor, area, r)
	local x0, x1 = rng.int(r, 3, 5), rng.int(r, 7, area.cols - 2)
	local y0 = r() < 0.75 and 3 or 4
	rect(floor, x0, y0, x1, area.rows - 2)
	if y0 == 3 and r() < 0.4 then
		local ax = rng.int(r, x0, x1 - 1)
		rect(floor, ax, 2, ax + 1, 2)
	end
	return { layout.midX(area)[1], 4 }
end

function SHAPES.church(floor, area)
	local mx = layout.midX(area)[1]
	rect(floor, 3, 3, area.cols - 2, area.rows - 2) -- the nave
	rect(floor, mx - 1, 2, mx + 2, 2) -- the apse
	return { mx, 4 }
end

function SHAPES.crypt(floor, area, r)
	local y0 = rng.int(r, 2, 3)
	rect(floor, rng.int(r, 2, 3), y0, rng.int(r, 8, area.cols - 2), area.rows - 2)
	return { layout.midX(area)[1], 4 }
end

function SHAPES.cave(floor, area, r, must)
	-- even shapes: a middle chamber, a side chamber or two, straight
	-- corridors joining them (the build template draws clean corners)
	local mx, my = layout.midX(area)[1], layout.midY(area)[1]
	local w, h = rng.int(r, 2, 4), rng.int(r, 2, 3)
	local x0, y0 = mx - rng.int(r, 0, w - 1), my - rng.int(r, 0, h - 1)
	rect(floor, x0, y0, x0 + w - 1, math.min(y0 + h - 1, area.rows - 2))
	local hub = meetAt(mx, my, must.avoid)
	mark(floor, hub[1], hub[2])
	for _ = 1, rng.int(r, 1, 2) do
		local cw, ch = rng.int(r, 2, 3), 2
		local cx, cy = rng.int(r, 2, area.cols - cw), rng.int(r, 2, area.rows - 1 - ch)
		rect(floor, cx, cy, cx + cw - 1, cy + ch - 1)
		corridor(floor, r, { cx, cy }, hub, area, must.avoid)
	end
	return hub
end

-- The build template (kits.build): a wall piece for each side the floor
-- is on, like a builder's corners. Sides: floor above / below / left /
-- right of the wall cell. Returns a tile, or nil for a cell that only
-- touches the floor at a corner (left empty, so corners stay clean).
function helpers.buildTile(r, kit, above, below, left, right)
	local slot
	if below then
		slot = right and "topLeft" or left and "topRight" or "top"
	elseif above then
		slot = right and "bottomLeft" or left and "bottomRight" or "bottom"
	elseif right then
		slot = "left"
	elseif left then
		slot = "right"
	else
		return nil
	end
	local tiles = kit[slot]
	if not tiles or #tiles == 0 then
		tiles = kit.top
	end
	return tiles and #tiles > 0 and rng.pick(r, tiles) or nil
end

-- A wall tile for (x, y): `walls` is a plain list (drawn all around), or
-- the build template (helpers.buildTile).
local function wallTile(r, walls, floor, x, y)
	if walls.top == nil then
		return #walls > 0 and rng.pick(r, walls) or nil
	end
	local function f(dx, dy)
		return floor[layout.key(x + dx, y + dy)] ~= nil
	end
	return helpers.buildTile(r, walls, f(0, -1), f(0, 1), f(-1, 0), f(1, 0))
end

-- Builds the room. opts: shape (SHAPES), walls, exit (the way back up's
-- tiles), wide (a two-cell way back up). Returns the anchors (the way
-- back up, the cell inside it, the passages).
function helpers.shapedRoom(area, ctx, opts)
	local r = ctx.r
	local layer = area.id:sub(1, 1)
	area.interior = true
	-- passages to the neighbors' levels on this layer (below: cell.underLinks,
	-- above: cell.overLinks), through the middle of a side
	local sideLinks = layer == "u" and ctx.cell.underLinks or layer == "a" and ctx.cell.overLinks or {}
	local links = {}
	for _, d in ipairs(Game.grid.DIRS) do
		local link = sideLinks[d[3]]
		if link then
			local cells = layout.sideCells(area, d[3])
			links[#links + 1] = { dir = d[3], d = d, cells = cells, link = link, inner = { cells[1][1] - d[1], cells[1][2] - d[2] } }
		end
	end
	-- the way back: an inside's is in the middle of the bottom wall; a
	-- lower or upper level's on the cell of the stairs it came from,
	-- entered from the same side (a cave mouth in the border stays in the
	-- border); a level spread over from a neighbor's has none, you come in
	-- through its first passage
	local way = nil
	if ctx.parent then
		way = layer == "h" and ctx.parent.door or layer == "u" and ctx.parent.down or ctx.parent.up
	end
	local exits, entry
	if layer ~= "h" and way then
		exits = { { way.x, way.y } }
		entry = { way.frontX, way.frontY }
	elseif layer ~= "h" and #links > 0 then
		exits = {}
		entry = links[1].inner
	else
		local ex = entryX(area)
		exits = { { ex, area.rows } }
		if opts.wide then
			exits[2] = { ex + 1, area.rows }
		end
		entry = { ex, area.rows - 1 }
	end
	local inward = {} -- for each exit, the cell you step onto from it
	for i, e in ipairs(exits) do
		inward[i] = { e[1] + entry[1] - exits[1][1], e[2] + entry[2] - exits[1][2] }
	end
	local floor = {}
	local must = { entry, avoid = {} }
	for _, e in ipairs(exits) do
		must.avoid[layout.key(e[1], e[2])] = true
	end
	for _, l in ipairs(links) do
		for _, c in ipairs(l.cells) do
			mark(floor, c[1], c[2])
			mark(floor, c[1] - l.d[1], c[2] - l.d[2])
		end
		must[#must + 1] = l.inner
		if l.link.covered then
			-- a hidden passage only leads on: the room's own corridors go around it
			must.avoid[layout.key(l.inner[1], l.inner[2])] = true
		end
	end
	local hub = SHAPES[opts.shape](floor, area, r, must)
	hub = meetAt(hub[1], hub[2], must.avoid)
	for _, p in ipairs(must) do
		corridor(floor, r, p, hub, area, must.avoid)
	end
	for i, e in ipairs(exits) do
		mark(floor, e[1], e[2])
		mark(floor, inward[i][1], inward[i][2])
	end
	-- draw: floor, walls around it, the dark beyond
	for y = 1, area.rows do
		for x = 1, area.cols do
			if floor[layout.key(x, y)] then
				layout.set(area, x, y, nil, false)
			else
				local near = false
				for dy = -1, 1 do
					for dx = -1, 1 do
						if floor[layout.key(x + dx, y + dy)] then
							near = true
						end
					end
				end
				layout.set(area, x, y, near and wallTile(r, opts.walls, floor, x, y) or nil, true)
			end
		end
	end
	-- the way back up
	for i, e in ipairs(exits) do
		layout.set(area, e[1], e[2], rng.pick(r, opts.exit), false)
		area.occupied[layout.key(e[1], e[2])] = true
		if way then
			area.portals[#area.portals + 1] = {
				x = e[1], y = e[2], to = ctx.parent.id, toX = way.frontX, toY = way.frontY,
				facing = dirTo(way.x, way.y, way.frontX, way.frontY),
			}
		end
		area.reserved[layout.key(inward[i][1], inward[i][2])] = true
	end
	area.entry = entry
	area.hub = area.entry -- enemies spawn away from it (layout.spawnCells)
	-- the room's middle is an anchor too, and the cells where the way in
	-- opens into the room stay clear: nothing may cut the room off
	local anchors = { area.entry } -- reach starts here: never across the stairs
	if floor[layout.key(hub[1], hub[2])] then
		anchors[#anchors + 1] = hub
	end
	for i, e in ipairs(exits) do
		local bx, by = 2 * inward[i][1] - e[1], 2 * inward[i][2] - e[2]
		if floor[layout.key(bx, by)] then
			area.reserved[layout.key(bx, by)] = true
		end
	end
	-- the passages, some behind a secret
	for _, l in ipairs(links) do
		area.openings[l.dir] = l.cells
		local first = l.cells[1]
		local ix, iy = first[1] - l.d[1], first[2] - l.d[2]
		area.reserved[layout.key(ix, iy)] = true
		anchors[#anchors + 1] = first
		if l.link.covered then
			local nb = ctx.world:neighbor(ctx.cell.k, l.dir)
			local id = "secret:passage:" .. math.min(ctx.cell.k, nb) .. "-" .. math.max(ctx.cell.k, nb)
			local tiles = l.link.covered == "web" and ctx.kits.objects.web or ctx.kits.ruins.rubble
			Game.objects.add(area, "secret", ix, iy, {
				tile = #tiles > 0 and rng.pick(r, tiles) or nil, slides = false, found = Game.text.foundPassage,
			}, id)
		end
	end
	return anchors
end

-- Free floor cells along a wall (a solid cell beside them), shuffled.
function helpers.alongWalls(area, r)
	local out = {}
	for _, c in ipairs(layout.shuffledInterior(area, r)) do
		local x, y = c[1], c[2]
		local k = layout.key(x, y)
		if not area.solid[y][x] and area.tiles[y][x] == nil and not area.reserved[k] and not area.occupied[k] then
			for _, d in ipairs(Game.grid.DIRS) do
				if area.solid[y + d[2]][x + d[1]] then
					out[#out + 1] = c
					break
				end
			end
		end
	end
	return out
end

-- A building stamped from a blueprint: rows of letters, each naming a tile
-- list in `legend` ("." leaves the cell alone, "D" is the door), tried at
-- random free spots until one keeps the anchors connected to the spot in
-- front of the door. Returns { x, y, frontX, frontY, left, right } or nil.
-- A legend entry can also be function(x, y, w, h) -> tile, for a cell at
-- (x, y) of the w x h blueprint. Letters in `walkable` stay walkable; a
-- blueprint without a "D" is a ruin you can't enter (returns its spot).
function helpers.placeBlueprint(area, r, rows, legend, anchors, walkable)
	local w, h = #rows[1], #rows
	local spots = {}
	for hy = 2, area.rows - 1 - h do
		for hx = 2, area.cols - w do
			spots[#spots + 1] = { hx, hy }
		end
	end
	for i = #spots, 2, -1 do
		local j = rng.int(r, 1, i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	for _, s in ipairs(spots) do
		local hx, hy = s[1], s[2]
		local free, door = true, nil
		for y = 1, h do
			for x = 1, w do
				local ch = rows[y]:sub(x, x)
				local ax, ay = hx + x - 1, hy + y - 1
				local k = layout.key(ax, ay)
				if ch ~= "." and (area.tiles[ay][ax] ~= nil or area.solid[ay][ax] or area.reserved[k] or area.occupied[k]) then
					free = false
				end
				if ch == "D" then
					door = { ax, ay }
				end
			end
		end
		local frontOk = not door or (not area.solid[door[2] + 1][door[1]] and not area.occupied[layout.key(door[1], door[2] + 1)])
		if free and frontOk then
			local placed = {}
			for y = 1, h do
				for x = 1, w do
					local ch = rows[y]:sub(x, x)
					local ax, ay = hx + x - 1, hy + y - 1
					if ch ~= "." then
						local tiles = legend[ch]
						local tile
						if type(tiles) == "function" then
							tile = tiles(x, y, w, h)
						else
							tile = tiles and #tiles > 0 and rng.pick(r, tiles) or nil
						end
						layout.set(area, ax, ay, tile, ch ~= "D" and not (walkable and walkable[ch]))
						placed[#placed + 1] = { ax, ay }
					end
				end
			end
			local all = { table.unpack(anchors) }
			local front = door and { door[1], door[2] + 1 }
			all[#all + 1] = front
			if layout.connected(area, all) then
				if not door then
					return { left = hx, right = hx + w - 1, top = hy }
				end
				return { x = door[1], y = door[2], frontX = front[1], frontY = front[2], left = hx, right = hx + w - 1 }
			end
			for _, c in ipairs(placed) do
				layout.set(area, c[1], c[2], nil, false)
			end
		end
	end
	return nil
end

Game.areaHelpers = helpers
