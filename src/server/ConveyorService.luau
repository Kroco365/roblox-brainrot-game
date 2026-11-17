--!nocheck
-- ConveyorService: the beating heart of the game. Brainrots step onto the
-- west end of the belt, walk east past the bases, and walk off the east end
-- if nobody buys them. Click one (or tap it) to buy it for your base, if you
-- can afford it and have a free slot. Rarer brainrots spawn less often, and
-- the Brainrot Rain event doubles the spawn rate and boosts Epic-or-better.

local ConveyorService = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))

local BASE_SPAWN_INTERVAL = 4
local DESPAWN_X = 96

local conveyorFolder = nil
local remotes = nil

function ConveyorService.setRemotes(r)
	remotes = r
end

-- Spawn one brainrot on the belt and register it.
function ConveyorService.spawnBrainrot()
	local entry = Catalog.pickRandomSpawn(GameState.events.spawnBoost)
	local mutationName, mutationMultiplier, mutationColor = Catalog.rollMutation()
	local model = CharacterFactory.buildBrainrot(entry, mutationName, mutationMultiplier, mutationColor)
	model.Parent = conveyorFolder
	model:PivotTo(CFrame.new(WorldBuilder.CONVEYOR_START_X, 1, WorldBuilder.CONVEYOR_Z))
	local record = {
		entry = entry,
		mutationName = mutationName,
		mutationMultiplier = mutationMultiplier,
		mutationColor = mutationColor,
		model = model,
		owner = nil,
		state = "conveyor",
		plotIndex = nil,
		slotIndex = nil,
		price = Catalog.priceFor(entry, mutationMultiplier),
	}
	GameState.registerBrainrot(model, record)
	-- Clicking the brainrot buys it (server-side ClickDetector event).
	local clicker = Instance.new("ClickDetector")
	clicker.MaxActivationDistance = 32
	clicker.Parent = model.PrimaryPart
	clicker.MouseClick:Connect(function(player)
		ConveyorService.tryBuy(player, model)
	end)
	return record
end

-- Try to buy a conveyor brainrot for a player. Every rule is checked here,
-- on the server, so a client can never buy what it cannot afford or hold.
function ConveyorService.tryBuy(player: Player, model: Model): boolean
	local record = GameState.recordOf(model)
	if record == nil or record.state ~= "conveyor" then
		return false
	end
	local data = GameState.players[player]
	if data == nil then
		return false
	end
	if #data.brainrots >= GameState.MAX_BRAINROTS_PER_PLAYER then
		ConveyorService.notify(player, "Your base is full! Rebirth or steal smarter.")
		return false
	end
	if data.cash < record.price then
		ConveyorService.notify(player, string.format("Need $%d for %s — you have $%d.", record.price, record.entry.name, math.floor(data.cash)))
		return false
	end
	local plotIndex = GameState.plotOf(player)
	if plotIndex == nil then
		return false
	end
	local slotIndex = BaseManager.freeSlot(plotIndex)
	if slotIndex == nil then
		return false
	end
	data.cash -= record.price
	record.owner = player
	table.insert(data.brainrots, record)
	local clicker = model.PrimaryPart:FindFirstChildOfClass("ClickDetector")
	if clicker then
		clicker:Destroy()
	end
	model.Parent = Workspace:WaitForChild("BrainrotWorld")
	BaseManager.placeOnBase(record, plotIndex, slotIndex)
	ConveyorService.notify(player, string.format("Bought %s for $%d! It earns $%d/s.", record.entry.name, record.price, Catalog.rateFor(record.entry, record.mutationMultiplier, data.multiplier)))
	return true
end

-- Bots buy through the same rules, minus the notifications.
function ConveyorService.tryBuyForBot(botName: string, model: Model): boolean
	local record = GameState.recordOf(model)
	if record == nil or record.state ~= "conveyor" then
		return false
	end
	local data = GameState.bots[botName]
	if data == nil then
		return false
	end
	if #data.brainrots >= GameState.MAX_BRAINROTS_PER_PLAYER then
		return false
	end
	if data.cash < record.price then
		return false
	end
	local slotIndex = BaseManager.freeSlot(data.plotIndex)
	if slotIndex == nil then
		return false
	end
	data.cash -= record.price
	record.owner = botName
	table.insert(data.brainrots, record)
	local clicker = model.PrimaryPart:FindFirstChildOfClass("ClickDetector")
	if clicker then
		clicker:Destroy()
	end
	model.Parent = Workspace:WaitForChild("BrainrotWorld")
	BaseManager.placeOnBase(record, data.plotIndex, slotIndex)
	return true
end

function ConveyorService.notify(player: Player, text: string)
	if remotes ~= nil then
		remotes.Notify:FireClient(player, text)
	end
end

-- Walk every conveyor brainrot east; despawn the ones that reach the end.
function ConveyorService.startWalkLoop()
	RunService.Heartbeat:Connect(function(dt)
		for model, record in pairs(GameState.brainrots) do
			if record.state == "conveyor" then
				local cf = model:GetPivot()
				local nextX = cf.Position.X + WorldBuilder.CONVEYOR_SPEED * dt
				model:PivotTo(CFrame.new(nextX, cf.Position.Y, cf.Position.Z))
				if nextX >= DESPAWN_X then
					GameState.unregisterBrainrot(model)
					model:Destroy()
				end
			end
		end
	end)
end

-- Spawn loop: a new brainrot every few seconds, faster during Brainrot Rain.
function ConveyorService.startSpawnLoop()
	task.spawn(function()
		while true do
			local interval = BASE_SPAWN_INTERVAL
			if GameState.events.activeEvent == "Brainrot Rain" then
				interval = 2
			end
			task.wait(interval)
			ConveyorService.spawnBrainrot()
		end
	end)
end

function ConveyorService.start()
	conveyorFolder = Instance.new("Folder")
	conveyorFolder.Name = "Conveyor"
	conveyorFolder.Parent = Workspace:WaitForChild("BrainrotWorld")
	GameState.conveyorFolder = conveyorFolder
	-- A few brainrots already walking when the first player arrives.
	for _ = 1, 3 do
		local record = ConveyorService.spawnBrainrot()
		local startX = WorldBuilder.CONVEYOR_START_X + math.random(10, 80)
		record.model:PivotTo(CFrame.new(startX, 1, WorldBuilder.CONVEYOR_Z))
	end
	ConveyorService.startWalkLoop()
	ConveyorService.startSpawnLoop()
end

return ConveyorService
