--!nocheck
-- NpcRivalService: three bot rivals who play the game for real, so the loop
-- works with one player alone. Each bot owns a base, saves up, walks to the
-- conveyor to buy brainrots, and every so often tries to steal one of yours
-- — walk up and slap it to make it drop the loot. Bots earn income through
-- the same Economy tick as players, so a bot left alone gets rich.

local NpcRivalService = {}

local Workspace = game:GetService("Workspace")
local GameState = require(script.Parent:WaitForChild("GameState"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))
local StealService = require(script.Parent:WaitForChild("StealService"))

local BOT_DEFS = {
	{ name = "Noob Nigel", color = Color3.fromRGB(255, 170, 60), plot = 2 },
	{ name = "xX_Slayer_Xx", color = Color3.fromRGB(255, 60, 90), plot = 3 },
	{ name = "Guest1337", color = Color3.fromRGB(60, 200, 255), plot = 4 },
}

-- Walk a rig to a position and wait until it arrives (or gives up).
local function walkTo(model: Model, target: Vector3): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil then
		return false
	end
	humanoid:MoveTo(target)
	local arrived = false
	local connection
	connection = humanoid.MoveToFinished:Connect(function(reached)
		arrived = reached
	end)
	local waited = 0
	while not arrived and waited < 15 do
		task.wait(0.5)
		waited += 0.5
		if (root.Position - target).Magnitude < 4 then
			arrived = true
			break
		end
	end
	if connection then
		connection:Disconnect()
	end
	return arrived
end

-- The best conveyor brainrot this bot can afford right now.
local function bestAffordableBrainrot(botName: string): Model?
	local data = GameState.bots[botName]
	if data == nil then
		return nil
	end
	local best = nil
	local bestRate = 0
	for model, record in pairs(GameState.brainrots) do
		if record.state == "conveyor" and record.price <= data.cash and record.entry.rate > bestRate then
			bestRate = record.entry.rate
			best = model
		end
	end
	return best
end

-- A random brainrot on a real player's base that this bot could steal.
local function pickPlayerBrainrotToSteal(): Model?
	local candidates = {}
	for model, record in pairs(GameState.brainrots) do
		if record.state == "base" and typeof(record.owner) == "Instance" then
			if record.plotIndex ~= nil and not GameState.isBaseLocked(record.plotIndex) then
				table.insert(candidates, model)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

-- One bot's whole life: buy, go home, sometimes steal, get slapped, repeat.
local function botLife(botDef)
	local botName = botDef.name
	local data = GameState.bots[botName]
	local model = data.model
	local plot = WorldBuilder.BASE_PLOTS[botDef.plot]
	task.wait(math.random(2, 6))
	while model.Parent ~= nil do
		-- Go shopping on the conveyor.
		local beltPoint = Vector3.new(-40, 1, WorldBuilder.CONVEYOR_Z)
		walkTo(model, beltPoint)
		local target = bestAffordableBrainrot(botName)
		if target ~= nil then
			local pos = target:GetPivot().Position
			walkTo(model, Vector3.new(pos.X, 1, pos.Z + 6))
			ConveyorService.tryBuyForBot(botName, target)
		end
		-- Walk home.
		walkTo(model, Vector3.new(plot.center.X, 1, plot.center.Z))
		task.wait(math.random(4, 10))
		-- Sometimes, go steal from a real player.
		if math.random() < 0.4 then
			local victim = pickPlayerBrainrotToSteal()
			if victim ~= nil then
				local victimPos = victim:GetPivot().Position
				walkTo(model, Vector3.new(victimPos.X, 1, victimPos.Z + 3))
				if StealService.botSteal(botName, victim) then
					-- Dash home with the loot (or get slapped on the way).
					walkTo(model, Vector3.new(plot.center.X, 1, plot.center.Z))
					StealService.botDeliver(botName)
				end
			end
		end
		task.wait(math.random(3, 8))
	end
end

function NpcRivalService.start()
	local world = Workspace:WaitForChild("BrainrotWorld")
	for _, botDef in ipairs(BOT_DEFS) do
		local data = GameState.newBotData(botDef.plot)
		GameState.bots[botDef.name] = data
		GameState.bases[botDef.plot].owner = botDef.name
		local rig = CharacterFactory.buildNpcRig(botDef.name, botDef.color)
		local plot = WorldBuilder.BASE_PLOTS[botDef.plot]
		rig:PivotTo(CFrame.new(plot.center.X, 1, plot.center.Z))
		rig.Parent = world
		data.model = rig
		task.spawn(botLife, botDef)
	end
end

return NpcRivalService
