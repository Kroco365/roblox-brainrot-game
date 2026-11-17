--!nocheck
-- StealService: the genre's signature move. Walk into another player's base,
-- grab one of their brainrots and dash home with it. The owner can slap you
-- to make you drop it; a locked base cannot be stolen from at all; and a
-- brainrot you just placed gets a 5-second grace period before it can be
-- stolen again. Carried brainrots ride above the thief's head until they
-- reach home, get dropped, or get slapped loose.

local StealService = {}

local RunService = game:GetService("RunService")
local GameState = require(script.Parent:WaitForChild("GameState"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))

local SLAP_RANGE = 7
local SLAP_COOLDOWN = 2
local STEAL_RANGE = 10
local STEAL_GRACE = 5
local CARRY_HEIGHT = 4.5

local remotes = nil
-- [Player] = record currently carried by that player.
local carriedByPlayer = {}
-- [Player] = os.clock() of their last slap.
local lastSlapAt = {}
-- [botName] = record currently carried by that bot.
local carriedByBot = {}

function StealService.setRemotes(r)
	remotes = r
end

function StealService.carriedBy(player: Player)
	return carriedByPlayer[player]
end

function StealService.botCarried(botName: string)
	return carriedByBot[botName]
end

-- Nearest brainrot this player is allowed to steal right now, or nil.
-- Sent to the client each tick so it can show the steal prompt.
function StealService.nearestStealable(player: Player): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return nil
	end
	if carriedByPlayer[player] ~= nil then
		return nil
	end
	local best = nil
	local bestDist = STEAL_RANGE
	for model, record in pairs(GameState.brainrots) do
		if record.state == "base" and record.owner ~= player and record.owner ~= nil then
			if record.plotIndex ~= nil and not GameState.isBaseLocked(record.plotIndex) then
				if os.clock() - (record.placedAt or 0) >= STEAL_GRACE then
					local dist = (model:GetPivot().Position - root.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						best = model
					end
				end
			end
		end
	end
	return best
end

-- Steal a brainrot: lift it off its base and carry it above your head.
function StealService.trySteal(player: Player, model: Model): boolean
	local record = GameState.recordOf(model)
	if record == nil or record.state ~= "base" then
		return false
	end
	if record.owner == player or record.owner == nil then
		return false
	end
	if carriedByPlayer[player] ~= nil then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return false
	end
	if (model:GetPivot().Position - root.Position).Magnitude > STEAL_RANGE then
		return false
	end
	if record.plotIndex ~= nil and GameState.isBaseLocked(record.plotIndex) then
		StealService.notify(player, "That base is locked! Wait for the lock to end.")
		return false
	end
	if os.clock() - (record.placedAt or 0) < STEAL_GRACE then
		return false
	end
	local previousOwner = record.owner
	BaseManager.removeFromBase(record)
	-- Remove it from the previous owner's list.
	StealService.removeFromOwnerList(previousOwner, record)
	record.state = "carried"
	record.carrier = player
	record.previousOwner = previousOwner
	carriedByPlayer[player] = record
	StealService.notify(player, string.format("You stole %s! Run home!", record.entry.name))
	StealService.notifyOwner(previousOwner, string.format("%s is stealing your %s! Slap them!", player.DisplayName, record.entry.name))
	return true
end

function StealService.removeFromOwnerList(owner, record)
	local data = nil
	if typeof(owner) == "Instance" then
		data = GameState.players[owner]
	else
		data = GameState.bots[owner]
	end
	if data == nil then
		return
	end
	for i, owned in ipairs(data.brainrots) do
		if owned == record then
			table.remove(data.brainrots, i)
			return
		end
	end
end

-- Deliver a carried brainrot to the carrier's own base.
function StealService.deliverCarried(player: Player)
	local record = carriedByPlayer[player]
	if record == nil then
		return
	end
	local data = GameState.players[player]
	local plotIndex = GameState.plotOf(player)
	if data == nil or plotIndex == nil then
		StealService.dropCarried(player)
		return
	end
	if #data.brainrots >= GameState.MAX_BRAINROTS_PER_PLAYER then
		StealService.notify(player, "Your base is full — the stolen brainrot ran back home!")
		StealService.returnToOwner(record)
		carriedByPlayer[player] = nil
		return
	end
	local slotIndex = BaseManager.freeSlot(plotIndex)
	if slotIndex == nil then
		StealService.returnToOwner(record)
		carriedByPlayer[player] = nil
		return
	end
	record.owner = player
	record.carrier = nil
	record.placedAt = os.clock()
	table.insert(data.brainrots, record)
	BaseManager.placeOnBase(record, plotIndex, slotIndex)
	CharacterFactory.refreshBrainrotTag(record.model, record.entry, record.mutationName, record.mutationMultiplier, record.mutationColor, data.multiplier)
	carriedByPlayer[player] = nil
	StealService.notify(player, string.format("Stolen %s secured! It now earns for you.", record.entry.name))
end

-- Drop what you are carrying (slapped, or walked off the map): it runs home.
function StealService.dropCarried(player: Player)
	local record = carriedByPlayer[player]
	if record == nil then
		return
	end
	carriedByPlayer[player] = nil
	StealService.returnToOwner(record)
end

-- Send a brainrot back to its previous owner's base after a short delay.
function StealService.returnToOwner(record)
	record.state = "returning"
	record.carrier = nil
	local owner = record.previousOwner
	task.spawn(function()
		task.wait(2.5)
		if record.state ~= "returning" then
			return
		end
		local plotIndex = owner ~= nil and GameState.plotOf(owner) or nil
		if plotIndex == nil then
			GameState.unregisterBrainrot(record.model)
			record.model:Destroy()
			return
		end
		local slotIndex = BaseManager.freeSlot(plotIndex)
		if slotIndex == nil then
			GameState.unregisterBrainrot(record.model)
			record.model:Destroy()
			return
		end
		record.owner = owner
		record.placedAt = os.clock()
		local data = nil
		if typeof(owner) == "Instance" then
			data = GameState.players[owner]
		else
			data = GameState.bots[owner]
		end
		if data ~= nil then
			table.insert(data.brainrots, record)
			BaseManager.placeOnBase(record, plotIndex, slotIndex)
			CharacterFactory.refreshBrainrotTag(record.model, record.entry, record.mutationName, record.mutationMultiplier, record.mutationColor, data.multiplier)
		end
	end)
end

-- Slap: knock a nearby thief (player or bot) and make them drop their loot.
function StealService.trySlap(player: Player): boolean
	local now = os.clock()
	if now - (lastSlapAt[player] or 0) < SLAP_COOLDOWN then
		return false
	end
	lastSlapAt[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return false
	end
	-- Slap a player thief.
	for otherPlayer, record in pairs(carriedByPlayer) do
		if otherPlayer ~= player then
			local otherChar = otherPlayer.Character
			local otherRoot = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
			if otherRoot ~= nil and (otherRoot.Position - root.Position).Magnitude <= SLAP_RANGE then
				StealService.knockBack(otherRoot, root.Position)
				StealService.dropCarried(otherPlayer)
				StealService.notify(player, string.format("SLAP! %s dropped %s.", otherPlayer.DisplayName, record.entry.name))
				StealService.notify(otherPlayer, string.format("%s slapped you! You dropped %s.", player.DisplayName, record.entry.name))
				return true
			end
		end
	end
	-- Slap a bot thief.
	for botName, record in pairs(carriedByBot) do
		local botData = GameState.bots[botName]
		local botModel = botData and botData.model
		local botRoot = botModel and botModel:FindFirstChild("HumanoidRootPart")
		if botRoot ~= nil and (botRoot.Position - root.Position).Magnitude <= SLAP_RANGE then
			StealService.knockBack(botRoot, root.Position)
			carriedByBot[botName] = nil
			StealService.returnToOwner(record)
			StealService.notify(player, string.format("SLAP! %s dropped %s.", botName, record.entry.name))
			return true
		end
	end
	return false
end

function StealService.knockBack(root: BasePart, fromPosition: Vector3)
	local direction = (root.Position - fromPosition)
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, 1)
	end
	direction = direction.Unit
	root.CFrame = root.CFrame + direction * 6 + Vector3.new(0, 1, 0)
end

-- Bots steal through this: a bot picks a brainrot up and carries it home.
function StealService.botSteal(botName: string, model: Model): boolean
	local record = GameState.recordOf(model)
	if record == nil or record.state ~= "base" then
		return false
	end
	if record.owner == botName or record.owner == nil then
		return false
	end
	if carriedByBot[botName] ~= nil then
		return false
	end
	if record.plotIndex ~= nil and GameState.isBaseLocked(record.plotIndex) then
		return false
	end
	if os.clock() - (record.placedAt or 0) < STEAL_GRACE then
		return false
	end
	local previousOwner = record.owner
	BaseManager.removeFromBase(record)
	StealService.removeFromOwnerList(previousOwner, record)
	record.state = "carried"
	record.carrier = botName
	record.previousOwner = previousOwner
	carriedByBot[botName] = record
	StealService.notifyOwner(previousOwner, string.format("%s is stealing your %s! Slap them!", botName, record.entry.name))
	return true
end

-- Deliver a bot's stolen brainrot to its own base.
function StealService.botDeliver(botName: string)
	local record = carriedByBot[botName]
	if record == nil then
		return
	end
	local data = GameState.bots[botName]
	if data == nil then
		carriedByBot[botName] = nil
		StealService.returnToOwner(record)
		return
	end
	if #data.brainrots >= GameState.MAX_BRAINROTS_PER_PLAYER then
		carriedByBot[botName] = nil
		StealService.returnToOwner(record)
		return
	end
	local slotIndex = BaseManager.freeSlot(data.plotIndex)
	if slotIndex == nil then
		carriedByBot[botName] = nil
		StealService.returnToOwner(record)
		return
	end
	record.owner = botName
	record.carrier = nil
	record.placedAt = os.clock()
	table.insert(data.brainrots, record)
	BaseManager.placeOnBase(record, data.plotIndex, slotIndex)
	CharacterFactory.refreshBrainrotTag(record.model, record.entry, record.mutationName, record.mutationMultiplier, record.mutationColor, data.multiplier)
	carriedByBot[botName] = nil
end

function StealService.notify(player: Player, text: string)
	if remotes ~= nil then
		remotes.Notify:FireClient(player, text)
	end
end

function StealService.notifyOwner(owner, text: string)
	if typeof(owner) == "Instance" then
		StealService.notify(owner, text)
	end
end

-- Every frame: carried brainrots ride above their carrier's head, and a
-- player who steps into their own base with loot delivers it automatically.
function StealService.startCarryLoop()
	RunService.Heartbeat:Connect(function()
		for player, record in pairs(carriedByPlayer) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root == nil then
				StealService.dropCarried(player)
			else
				local headPos = root.Position + Vector3.new(0, CARRY_HEIGHT, 0)
				record.model:PivotTo(CFrame.new(headPos))
				local plotIndex = GameState.plotOf(player)
				if plotIndex ~= nil and BaseManager.positionInPlot(root.Position, plotIndex) then
					StealService.deliverCarried(player)
				end
			end
		end
		for botName, record in pairs(carriedByBot) do
			local botData = GameState.bots[botName]
			local botModel = botData and botData.model
			local botRoot = botModel and botModel:FindFirstChild("HumanoidRootPart")
			if botRoot == nil then
				carriedByBot[botName] = nil
				StealService.returnToOwner(record)
			else
				local headPos = botRoot.Position + Vector3.new(0, CARRY_HEIGHT, 0)
				record.model:PivotTo(CFrame.new(headPos))
				if BaseManager.positionInPlot(botRoot.Position, botData.plotIndex) then
					StealService.botDeliver(botName)
				end
			end
		end
	end)
end

return StealService
