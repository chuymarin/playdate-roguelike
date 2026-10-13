-- The main scene: walking around one area at a time.
--
-- Controls: d-pad moves one tile (hold to keep walking). Ⓐ opens the chest
-- or talks to the NPC in front of you, otherwise swings the sword (once you
-- have it). Ⓑ raises the shield (once you have it).
--
-- Walking off a doorway at the room's edge enters the next area; walking
-- onto a house door goes inside. Enemies come back each time you enter an
-- area; opened chests and picked-up items don't.

local gfx <const> = playdate.graphics
local pd <const> = playdate
local grid <const> = Game.grid
local config <const> = Game.config
local layout <const> = Game.layout
local pickup <const> = Game.pickup
local audio <const> = Game.audio
local tiles <const> = Game.tiles
local text <const> = Game.text

local Explore = {}
Explore.__index = Explore

local REPEAT_DELAY <const> = 8 -- frames held before walking repeats
local REPEAT_EVERY <const> = 5
local TOAST_FRAMES <const> = 60
local BUTTON_DIRS = {
	{ pd.kButtonUp, "N" },
	{ pd.kButtonRight, "E" },
	{ pd.kButtonDown, "S" },
	{ pd.kButtonLeft, "W" },
}

local function toScreen(x, y)
	return config.ORIGIN_X + (x - 1) * config.TILE, config.ORIGIN_Y + (y - 1) * config.TILE
end

function Explore.new(world, onWin)
	local self = setmetatable({
		world = world,
		onWin = onWin,
		player = Game.Player.new(Game.kits.characters.player[1]),
		frame = 0,
		held = nil,
		heldFrames = 0,
	}, Explore)
	local start = world:area("c" .. world.gen.start)
	if start.house then
		local home = world:area("h" .. world.gen.start)
		world.respawn = { id = home.id, x = home.entry[1], y = home.entry[2] }
	else
		local free = layout.byCenter(start, layout.freeCells(start, layout.anchors(start)))
		world.respawn = { id = start.id, x = free[1][1], y = free[1][2] }
	end
	self:enter(world.respawn.id, world.respawn.x, world.respawn.y, "N")
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
	self.enemies = {}
	for _, spawn in ipairs(area.enemySpawns) do
		self.enemies[#self.enemies + 1] = Game.Enemy.new(spawn)
	end
	self.npcs = {}
	for _, def in ipairs(area.npcs) do
		self.npcs[#self.npcs + 1] = Game.Npc.new(def)
	end
	self.background = nil
	if area.safe then
		p.hearts = p.maxHearts
		self.world.respawn = { id = area.id, x = area.respawn[1], y = area.respawn[2] }
		self:toast(text.camp)
	end
end

-- Leaving through the doorway in direction dir, into the neighbor cell.
function Explore:leave(dir)
	local area, p = self.area, self.player
	local k = self.world:neighbor(area.cell.k, dir)
	local x = dir == "E" and 1 or dir == "W" and area.cols or p.x
	local y = dir == "S" and 1 or dir == "N" and area.rows or p.y
	self:enter("c" .. k, x, y, dir)
end

-- ---------- what's where ----------

-- The closed lock at (x, y), if any: "door" (the dungeon entrance, opened
-- with the dungeon key) or "cell" (the NPC's cell, opened with the cell key).
function Explore:lockAt(x, y)
	local area, world = self.area, self.world
	local lock = area.lock
	if lock and not world.unlocked and lock.x == x and lock.y == y then
		return "door"
	end
	lock = area.cellLock
	if lock and not world.cellOpen and lock.x == x and lock.y == y then
		return "cell"
	end
	return nil
end

function Explore:enemyAt(x, y)
	for i, e in ipairs(self.enemies) do
		if e.x == x and e.y == y then
			return e, i
		end
	end
	return nil
end

function Explore:npcAt(x, y)
	for _, n in ipairs(self.npcs) do
		if n.x == x and n.y == y then
			return n
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
function Explore:canEnter(x, y, enemy)
	local area = self.area
	if x <= 1 or y <= 1 or x >= area.cols or y >= area.rows then
		return false
	end
	if area.solid[y][x] or self:portalAt(x, y) or pickup.chestAt(area, x, y) or self:npcAt(x, y) or self:lockAt(x, y) then
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
		if not area.interior and area.openings[dir] then
			audio.step(area.surface)
			self:leave(dir)
		end
		return
	end
	local lock = self:lockAt(tx, ty)
	if lock then
		self:tryUnlock(lock)
		return
	end
	if area.solid[ty][tx] or pickup.chestAt(area, tx, ty) or self:npcAt(tx, ty) then
		return
	end
	local enemy = self:enemyAt(tx, ty)
	if enemy then
		self:hurtPlayer(enemy)
		return
	end
	p.x, p.y = tx, ty
	audio.step(area.surface)

	local _, index = pickup.itemAt(area, tx, ty)
	if index then
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

function Explore:tryUnlock(lock)
	local p, world = self.player, self.world
	if lock == "door" and p:take("key") then
		world.unlocked = true
		self:toast(text.unlocked)
	elseif lock == "cell" and p:take("cellKey") then
		world.cellOpen = true
		self:toast(text.cellOpened)
	else
		audio.play("locked")
		self:say(lock == "door" and text.locked or text.cellLocked)
		return
	end
	self.background = nil
	audio.play("unlock")
end

function Explore:pressA()
	local p, area = self.player, self.area
	if p:busy() then
		return
	end
	local fx, fy = p:front()
	local chest = pickup.chestAt(area, fx, fy)
	if chest then
		pickup.open(area, chest)
		audio.play("chest")
		return
	end
	local lock = self:lockAt(fx, fy)
	if lock then
		self:tryUnlock(lock)
		return
	end
	local npc = self:npcAt(fx, fy)
	if npc then
		if npc.def.goal then
			self:say(npc.def.lines, function()
				audio.play("win")
				self:say(text.theEnd, self.onWin)
			end)
		else
			self:say(npc.def.lines)
		end
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

function Explore:hitEnemy(enemy, index)
	enemy.hp = enemy.hp - 1
	audio.play("hit")
	if enemy.hp <= 0 then
		table.remove(self.enemies, index)
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
	-- knock the enemy away from the player
	for _, d in ipairs(grid.DIRS) do
		if enemy.x - p.x == d[1] and enemy.y - p.y == d[2] then
			self:push(enemy, d[3])
		end
	end
	if p.hearts <= 0 then
		audio.play("faint")
		self:say(text.faint, function()
			p.hearts = p.maxHearts
			p.invulnerable = 0
			local rs = self.world.respawn
			self:enter(rs.id, rs.x, rs.y, "S")
		end)
	end
end

-- Called by an enemy stepping into the player (enemy.lua).
function Explore:attack(enemy, dir)
	local p = self.player
	local fx, fy = p:front()
	if p.guard > 0 and fx == enemy.x and fy == enemy.y then
		audio.play("shield")
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

-- The room's tiles, drawn once into an image (again after a lock opens).
function Explore:renderBackground()
	local area = self.area
	local image = gfx.image.new(400, 240, gfx.kColorBlack)
	gfx.pushContext(image)
	for y = 1, area.rows do
		for x = 1, area.cols do
			local tile = area.tiles[y][x]
			if area.lock and area.lock.x == x and area.lock.y == y then
				tile = self.world.unlocked and area.lock.openTile or area.lock.tile
			end
			if area.cellLock and area.cellLock.x == x and area.cellLock.y == y then
				tile = self.world.cellOpen and area.cellLock.openTile or area.cellLock.tile
			end
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
	pickup.draw(self.area, tiles, kits, toScreen)
	for _, n in ipairs(self.npcs) do
		n:draw(tiles, toScreen)
	end
	for _, e in ipairs(self.enemies) do
		e:draw(tiles, toScreen)
	end
	self.player:draw(tiles, kits, toScreen)
	Game.hud.draw(self.player, tiles, kits)
	if self.toastFrames and self.toastFrames > 0 then
		local w = gfx.getTextSize(self.toastText) + 16
		local x = 200 - w // 2
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(x, 20, w, 22)
		gfx.drawText(self.toastText, x + 8, 23)
	end
	if self.dialogue then
		self.dialogue:draw()
	end
end

Game.Explore = Explore
