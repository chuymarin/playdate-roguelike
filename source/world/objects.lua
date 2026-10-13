-- Objects (Rulebook 3.2): everything you interact with. An area builder
-- makes them from the templates in data/objects.lua; the world keeps their
-- statuses (world.status[id]), so an open chest or gate stays open.
--
-- Ids: one per object, stable across rebuilding the area. A gate has one id
-- shared by the areas on both sides, so it opens on both.

local objects = {}

-- Deep copy of a template value with "{name}" holes filled from params.
local function fill(value, params)
	if type(value) == "string" then
		local name = value:match("^{(%w+)}$")
		if name then
			return params[name]
		end
		return value
	end
	if type(value) == "table" then
		local out = {}
		for k, v in pairs(value) do
			out[k] = fill(v, params)
		end
		return out
	end
	return value
end

function objects.new(template, id, x, y, params)
	local def = assert(Game.objectKinds[template], template)
	local obj = fill(def, params or {})
	obj.template = template
	obj.kind = def.kind or template
	obj.id = id
	obj.x, obj.y = x, y
	obj.initial = obj.status
	return obj
end

-- Adds an object to an area, with an id made from the area's and a count
-- (unless one is given).
function objects.add(area, template, x, y, params, id)
	local obj = objects.new(template, id or (template .. ":" .. area.id .. ":" .. (#area.objects + 1)), x, y, params)
	area.objects[#area.objects + 1] = obj
	return obj
end

function objects.status(world, obj)
	if obj.persist == false then
		return obj.status
	end
	return world.status[obj.id] or obj.initial
end

function objects.setStatus(world, obj, status)
	if obj.persist == false then
		obj.status = status
	else
		world.status[obj.id] = status
	end
end

function objects.blocks(world, obj)
	return obj.blocks ~= nil and obj.blocks[objects.status(world, obj)] == true
end

function objects.tile(world, obj)
	return obj.tiles and obj.tiles[objects.status(world, obj)]
end

-- The object at (x, y) that blocks the way, if any.
function objects.at(area, world, x, y)
	for _, obj in ipairs(area.objects) do
		if obj.x == x and obj.y == y and objects.blocks(world, obj) then
			return obj
		end
	end
	return nil
end

-- All objects of a kind in an area.
function objects.ofKind(area, kind)
	local out = {}
	for _, obj in ipairs(area.objects) do
		if obj.kind == kind then
			out[#out + 1] = obj
		end
	end
	return out
end

-- Draws each object's tile for its status (NPCs have sprites instead: the
-- explore scene animates them; the map screen passes withSprites).
function objects.draw(area, world, tiles, size, toScreen, withSprites)
	for _, obj in ipairs(area.objects) do
		local tile = objects.tile(world, obj)
		if not tile and withSprites then
			tile = obj.sprite
		end
		if tile then
			local px, py = toScreen(obj.x, obj.y)
			tiles.draw(size, tile, px, py)
		end
	end
end

Game.objects = objects
