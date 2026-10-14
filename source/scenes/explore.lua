-- The main scene: walking around one area at a time.
--
-- Controls: d-pad moves one tile (hold to keep walking). Ⓐ uses the object
-- in front of you (opens a chest, talks to an NPC), otherwise swings the
-- sword (once you have it). Ⓑ raises the shield (once you have it).
--
-- Every interaction goes through the objects' rules (core/rules.lua): Ⓐ
-- fires `use` on the object in front, walking into one fires `bump`, and an
-- enemy at 0 hit points fires `defeat`. This scene only provides what the
-- rules act on (makeContext).
--
-- Walking off a doorway at the room's edge enters the next area; walking
-- onto a house door goes inside. Enemies come back each time you enter an
-- area; opened chests and gates and picked-up items don't.

local gfx <const> = playdate.graphics
local pd <const> = playdate
local grid <const> = Game.grid
local config <const> = Game.config
local layout <const> = Game.layout
local pickup <const> = Game.pickup
local audio <const> = Game.audio
local tiles <const> = Game.tiles
local text <const> = Game.text
local objects <const> = Game.objects
local rules <const> = Game.rules

local Explore = {}
Explore.__index = Explore

local REPEAT_DELAY <const> = config.WALK_REPEAT_DELAY -- frames held before walking repeats
local REPEAT_EVERY <const> = config.WALK_REPEAT_EVERY
local TOAST_FRAMES <const> = 60
local BANNER_FRAMES <const> = 100
local EFFECT_STEP <const> = config.EFFECT_FRAME_TIME -- frames each tile of an effect shows
local EFFECT_MIN <const> = 10 -- an effect with one tile still shows this long
local BUTTON_DIRS = {
	{ pd.kButtonUp, "N" },
	{ pd.kButtonRight, "E" },
	{ pd.kButtonDown, "S" },
	{ pd.kButtonLeft, "W" },
}

local function toScreen(x, y)
	return config.ORIGIN_X + (x - 1) * config.TILE, config.ORIGIN_Y + (y - 1) * config.TILE
end

-- onEnd: called when the run is over (you won or died); main.lua starts a
-- new world.
function Explore.new(world, onEnd)
	local self = setmetatable({
		world = world,
		onEnd = onEnd,
		player = Game.Player.new(Game.kits.characters.player[1]),
		frame = 0,
		held = nil,
		heldFrames = 0,
	}, Explore)
	self.ctx = self:makeContext()
	local start = world:area("c" .. world.gen.start)
	if start.door then
		local home = world:area("h" .. world.gen.start)
		self:enter(home.id, home.entry[1], home.entry[2], "N")
	else
		local free = layout.byCenter(start, layout.freeCells(start, layout.anchors(start)))
		self:enter(start.id, free[1][1], free[1][2], "N")
	end
	self:say(text.intro)
	return self
end

-- ---------- moving between areas ----------

function Explore:enter(id, x, y, facing)
	local area = self.world:area(id)
	self.area = area
	local p = self.player
	p.x, p.y = x, y
	p:face(facing)
	p.swing, p.guard = 0, 0
	self.world.visited[area.cell.k] = true
	-- the act's title, the first time you walk into its region
	local act = area.cell.act
	if act and not self.world.actsSeen[act] then
		self.world.actsSeen[act] = true
		self.bannerText, self.bannerFrames = Game.story.acts[act].name, BANNER_FRAMES
	end
	self.effects = {}
	self.remains = {} -- { x, y, tile } where enemies fell; gone when you leave
	self.enemies = {}
	for i, spawn in ipairs(area.enemySpawns) do
		local enemy = Game.Enemy.new(spawn)
		enemy.obj = objects.new("enemy", "enemy:" .. area.id .. ":" .. i, spawn.x, spawn.y)
		self.enemies[#self.enemies + 1] = enemy
	end
	self.npcs = {}
	for _, obj in ipairs(objects.ofKind(area, "npc")) do
		self.npcs[#self.npcs + 1] = Game.Npc.new(obj)
	end
	self.background = nil
	if area.safe then
		p.hearts = p.maxHearts
		self:toast(text.camp)
	end
end

-- Leaving through the doorway in direction dir, into the neighbor cell
-- (on the same layer: a lower level's passage leads to the neighbor's).
function Explore:leave(dir)
	local area, p = self.area, self.player
	local k = self.world:neighbor(area.cell.k, dir)
	local x = dir == "E" and 1 or dir == "W" and area.cols or p.x
	local y = dir == "S" and 1 or dir == "N" and area.rows or p.y
	self:enter(area.id:sub(1, 1) .. k, x, y, dir)
end

-- ---------- what's where ----------

-- The object blocking (x, y), if any: a closed chest, a locked gate or
-- cell door, an NPC.
function Explore:objectAt(x, y)
	return objects.at(self.area, self.world, x, y)
end

function Explore:enemyAt(x, y)
	for i, e in ipairs(self.enemies) do
		if e.x == x and e.y == y then
			return e, i
		end
	end
	return nil
end

function Explore:portalAt(x, y)
	for _, portal in ipairs(self.area.portals) do
		if portal.x == x and portal.y == y then
			return portal
		end
	end
	return nil
end

-- Enemies keep to the room's inside: off the border, doors and anything solid.
-- Where something dropped at (x, y) lands: the free cell nearest to it
-- that you can walk to (nearest to you on a tie), never the spot itself,
-- your cell, a doorway or a cell that already holds an item or remains.
function Explore:dropSpot(x, y)
	local area, p = self.area, self.player
	local blocked = {}
	for _, obj in ipairs(area.objects) do
		if objects.blocks(self.world, obj) then
			blocked[layout.key(obj.x, obj.y)] = true
		end
	end
	local taken = {}
	for _, it in ipairs(area.items) do
		taken[layout.key(it.x, it.y)] = true
	end
	for _, r in ipairs(self.remains) do
		taken[layout.key(r.x, r.y)] = true
	end
	for _, e in ipairs(self.enemies) do
		taken[layout.key(e.x, e.y)] = true
	end
	local dist, order = layout.reach(area, { { p.x, p.y } }, blocked)
	local best, bestScore
	for _, c in ipairs(order) do
		local k = layout.key(c[1], c[2])
		local near = math.abs(c[1] - x) + math.abs(c[2] - y)
		if near > 0 and not taken[k] and not (c[1] == p.x and c[2] == p.y) and not self:portalAt(c[1], c[2]) then
			local score = near * 1000 + dist[k]
			if not bestScore or score < bestScore then
				best, bestScore = c, score
			end
		end
	end
	if best then
		return best[1], best[2]
	end
	return x, y
end

function Explore:canEnter(x, y, enemy)
	local area = self.area
	if x <= 1 or y <= 1 or x >= area.cols or y >= area.rows then
		return false
	end
	if area.solid[y][x] or self:portalAt(x, y) or self:objectAt(x, y) then
		return false
	end
	local other = self:enemyAt(x, y)
	if other and other ~= enemy then
		return false
	end
	return not (x == self.player.x and y == self.player.y)
end

-- ---------- messages ----------

function Explore:say(lines, onDone)
	self.dialogue = Game.Dialogue.new(lines, onDone, self.player.y > (config.ROWS + 1) / 2)
end

function Explore:toast(message)
	self.toastText, self.toastFrames = message, TOAST_FRAMES
end

-- ---------- what rules act on ----------

function Explore:makeContext()
	local world = self.world
	return {
		player = self.player,
		statusOf = function(id)
			return world.status[id]
		end,
		objectStatus = function(obj)
			return objects.status(world, obj)
		end,
		setStatus = function(obj, status)
			objects.setStatus(world, obj, status)
		end,
		shove = function(obj)
			self:shove(obj)
		end,
		drop = function(item, x, y)
			local cx, cy = self:dropSpot(x, y)
			pickup.drop(self.area, item, cx, cy)
		end,
		sound = audio.play,
		toast = function(message)
			self:toast(message)
		end,
		say = function(lines, onDone)
			self:say(lines, onDone)
		end,
		win = function()
			audio.play("win")
			self:say(text.theEnd, self.onEnd)
		end,
	}
end

-- Pushes a secret's cover (a grave) one cell on, away from the player, if
-- that cell is free floor; it lies there flat (you can walk over it). The
-- area keeps it, so it stays pushed aside.
function Explore:shove(obj)
	local p, area = self.player, self.area
	local dx, dy = obj.x - p.x, obj.y - p.y
	if math.abs(dx) + math.abs(dy) ~= 1 then
		return
	end
	local x, y = obj.x + dx, obj.y + dy
	local free = x > 1 and y > 1 and x < area.cols and y < area.rows and not area.solid[y][x]
		and area.tiles[y][x] == nil and not self:objectAt(x, y) and not self:portalAt(x, y)
		and not pickup.itemAt(area, x, y) and not self:enemyAt(x, y)
	if free then
		obj.slid = { x = x, y = y, tile = obj.tiles.hidden }
	end
end

-- ---------- player actions ----------

function Explore:tryMove(dir)
	local p, area = self.player, self.area
	p:face(dir)
	if p:busy() then
		return
	end
	local d = grid.DELTA[dir]
	local tx, ty = p.x + d[1], p.y + d[2]
	if not layout.inside(area, tx, ty) then
		if area.openings[dir] then
			audio.step(area.surface)
			self:leave(dir)
		end
		return
	end
	local obj = self:objectAt(tx, ty)
	if obj then
		rules.fire("bump", obj, self.ctx)
		return
	end
	if area.solid[ty][tx] then
		return
	end
	local enemy = self:enemyAt(tx, ty)
	if enemy then
		self:hurtPlayer(enemy)
		return
	end
	p.x, p.y = tx, ty
	audio.step(area.surface)

	-- everything lying here (an enemy can drop a coin onto another item)
	while true do
		local _, index = pickup.itemAt(area, tx, ty)
		if not index then
			break
		end
		local def = pickup.collect(area, index, p)
		if def.quiet then
			audio.play("coin")
			self:toast(def.toast)
		else
			audio.play("pickup")
			self:say(def.lines)
		end
	end
	local portal = self:portalAt(tx, ty)
	if portal then
		audio.play("door")
		self:enter(portal.to, portal.toX, portal.toY, portal.facing)
	end
end

function Explore:pressA()
	local p = self.player
	if p:busy() then
		return
	end
	local fx, fy = p:front()
	local obj = self:objectAt(fx, fy)
	if obj and rules.fire("use", obj, self.ctx) then
		return
	end
	if p:can("swing") then
		p:startSwing()
		self.swingHits = {}
		audio.play("sword")
	end
end

function Explore:pressB()
	local p = self.player
	if p:can("guard") and not p:busy() then
		p:startGuard()
		self.guardPushed = {}
		audio.play("shield")
	end
end

-- ---------- combat ----------

-- Moves an enemy one tile in dir if it can go there; stuns it either way.
function Explore:push(enemy, dir)
	local d = grid.DELTA[dir]
	local nx, ny = enemy.x + d[1], enemy.y + d[2]
	if self:canEnter(nx, ny, enemy) then
		enemy.x, enemy.y = nx, ny
	end
	enemy:stunFor()
end

-- A quick effect (kits.effects: hurt, hit, defeat, block) over a cell: its
-- tiles play in order, drawn inverted so they show over a sprite.
function Explore:effect(name, x, y)
	local frames = Game.kits.effects and Game.kits.effects[name]
	if frames and #frames > 0 then
		local life = math.max(#frames * EFFECT_STEP, EFFECT_MIN)
		self.effects[#self.effects + 1] = { frames = frames, x = x, y = y, age = 0, life = life }
	end
end

function Explore:hitEnemy(enemy, index)
	enemy.hp = enemy.hp - 1
	audio.play("hit")
	self:effect(enemy.hp <= 0 and "defeat" or "hit", enemy.x, enemy.y)
	if enemy.hp <= 0 then
		table.remove(self.enemies, index)
		local bones = Game.kits.objects.remains
		if bones and #bones > 0 then
			self.remains[#self.remains + 1] = { x = enemy.x, y = enemy.y, tile = bones[math.random(#bones)] }
		end
		enemy.obj.x, enemy.obj.y = enemy.x, enemy.y
		rules.fire("defeat", enemy.obj, self.ctx)
	else
		enemy.flash = 12
		self:push(enemy, self.player.facing)
	end
end

function Explore:hurtPlayer(enemy)
	local p = self.player
	if not p:hurt() then
		return
	end
	audio.play("hurt")
	self:effect("hurt", p.x, p.y)
	-- knock the enemy away from the player
	for _, d in ipairs(grid.DIRS) do
		if enemy.x - p.x == d[1] and enemy.y - p.y == d[2] then
			self:push(enemy, d[3])
		end
	end
	-- a roguelike: at 0 hearts the run is over and a new world begins
	if p.hearts <= 0 then
		audio.play("faint")
		self:say(text.died, self.onEnd)
	end
end

-- Called by an enemy stepping into the player (enemy.lua).
function Explore:attack(enemy, dir)
	local p = self.player
	local fx, fy = p:front()
	if p.guard > 0 and fx == enemy.x and fy == enemy.y then
		audio.play("shield")
		self:effect("block", fx, fy)
		self:push(enemy, grid.OPP[dir])
		return
	end
	self:hurtPlayer(enemy)
end

function Explore:updateCombat()
	local p = self.player
	local fx, fy = p:front()
	if p.swing > 0 then
		local enemy, index = self:enemyAt(fx, fy)
		if enemy and not self.swingHits[enemy] then
			self.swingHits[enemy] = true
			self:hitEnemy(enemy, index)
		end
	elseif p.guard > 0 then
		local enemy = self:enemyAt(fx, fy)
		if enemy and not self.guardPushed[enemy] then
			self.guardPushed[enemy] = true
			self:push(enemy, p.facing)
		end
	end
end

-- ---------- frame ----------

function Explore:readInput()
	for _, bd in ipairs(BUTTON_DIRS) do
		if pd.buttonJustPressed(bd[1]) then
			self.held, self.heldFrames = bd, 0
			self:tryMove(bd[2])
			return
		end
	end
	if self.held then
		if pd.buttonIsPressed(self.held[1]) then
			self.heldFrames = self.heldFrames + 1
			if self.heldFrames >= REPEAT_DELAY and (self.heldFrames - REPEAT_DELAY) % REPEAT_EVERY == 0 then
				self:tryMove(self.held[2])
			end
		else
			self.held = nil
		end
	end
	if pd.buttonJustPressed(pd.kButtonA) then
		self:pressA()
	elseif pd.buttonJustPressed(pd.kButtonB) then
		self:pressB()
	end
end

function Explore:update()
	self.frame = self.frame + 1
	if self.toastFrames and self.toastFrames > 0 then
		self.toastFrames = self.toastFrames - 1
	end
	if self.bannerFrames and self.bannerFrames > 0 then
		self.bannerFrames = self.bannerFrames - 1
	end
	for i = #self.effects, 1, -1 do
		local e = self.effects[i]
		e.age = e.age + 1
		if e.age >= e.life then
			table.remove(self.effects, i)
		end
	end
	if self.dialogue then
		if self.dialogue:update() then
			local done = self.dialogue.onDone
			self.dialogue = nil
			if done then
				done()
			end
		end
		return
	end
	self:readInput()
	if self.dialogue then
		return
	end
	self.player:tick()
	self:updateCombat()
	for _, e in ipairs(self.enemies) do
		e:update(self)
		if self.dialogue then
			return
		end
	end
	for _, n in ipairs(self.npcs) do
		n:update()
	end
end

-- The room's tiles, drawn once into an image. Objects (chests, gates,
-- cell doors) change with their status, so they're drawn every frame.
function Explore:renderBackground()
	local area = self.area
	local image = gfx.image.new(400, 240, gfx.kColorBlack)
	gfx.pushContext(image)
	for y = 1, area.rows do
		for x = 1, area.cols do
			local tile = area.tiles[y][x]
			if tile then
				local px, py = toScreen(x, y)
				tiles.draw(config.TILE, tile, px, py)
			end
		end
	end
	gfx.popContext()
	return image
end

function Explore:draw()
	local kits = Game.kits
	if not self.background then
		self.background = self:renderBackground()
	end
	self.background:draw(0, 0)
	objects.draw(self.area, self.world, tiles, config.TILE, toScreen)
	for _, r in ipairs(self.remains) do
		local px, py = toScreen(r.x, r.y)
		tiles.draw(config.TILE, r.tile, px, py)
	end
	pickup.draw(self.area, tiles, kits, toScreen)
	for _, n in ipairs(self.npcs) do
		n:draw(tiles, toScreen)
	end
	for _, e in ipairs(self.enemies) do
		e:draw(tiles, toScreen)
	end
	self.player:draw(tiles, kits, toScreen)
	gfx.setImageDrawMode(gfx.kDrawModeXOR)
	for _, e in ipairs(self.effects) do
		local px, py = toScreen(e.x, e.y)
		tiles.draw(config.TILE, e.frames[math.min(e.age // EFFECT_STEP + 1, #e.frames)], px, py)
	end
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	Game.hud.draw(self.player, tiles, kits)
	if self.toastFrames and self.toastFrames > 0 then
		local w = gfx.getTextSize(self.toastText) + 16
		local x = 200 - w // 2
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(x, 20, w, 22)
		gfx.drawText(self.toastText, x + 8, 23)
	end
	if self.bannerFrames and self.bannerFrames > 0 then
		local w = gfx.getTextSize(self.bannerText) + 40
		local x = 200 - w // 2
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(x, 104, w, 32)
		gfx.setColor(gfx.kColorBlack)
		gfx.drawRect(x + 3, 107, w - 6, 26)
		gfx.drawText(self.bannerText, x + 20, 112)
	end
	if self.dialogue then
		self.dialogue:draw()
	end
end

Game.Explore = Explore
