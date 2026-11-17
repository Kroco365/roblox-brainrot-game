--!nocheck
-- Brainrot Bazaar: server entrypoint. Builds the world, claims the bases,
-- wires the RemoteEvents and starts every service: the conveyor, the
-- economy tick, stealing, events, rebirths and the NPC rivals.
-- The client only ever asks; every rule (price, slot, lock, cooldown, range)
-- is checked here, on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local GameState = require(script:WaitForChild("GameState"))
local Economy = require(script:WaitForChild("Economy"))
local BaseManager = require(script:WaitForChild("BaseManager"))
local ConveyorService = require(script:WaitForChild("ConveyorService"))
local StealService = require(script:WaitForChild("StealService"))
local EventService = require(script:WaitForChild("EventService"))
local RebirthService = require(script:WaitForChild("RebirthService"))
local NpcRivalService = require(script:WaitForChild("NpcRivalService"))

print("Brainrot Bazaar: building the world...")

-- 1. The 3D world: conveyor, 8 bases, hill, plaza, trees and lamps.
local worldFolders = WorldBuilder.build()
BaseManager.setWorldFolders(worldFolders)
GameState.initBases(#WorldBuilder.BASE_PLOTS)

-- 2. The RemoteEvents the client talks through (defined in default.project.json).
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local remotes = {
	StealBrainrot = remotesFolder:WaitForChild("StealBrainrot"),
	Slap = remotesFolder:WaitForChild("Slap"),
	LockBase = remotesFolder:WaitForChild("LockBase"),
	Rebirth = remotesFolder:WaitForChild("Rebirth"),
	StateSync = remotesFolder:WaitForChild("StateSync"),
	Notify = remotesFolder:WaitForChild("Notify"),
	EventAlert = remotesFolder:WaitForChild("EventAlert"),
}
Economy.setRemotes(remotes)
ConveyorService.setRemotes(remotes)
StealService.setRemotes(remotes)
EventService.setRemotes(remotes)
RebirthService.setRemotes(remotes)

-- 3. Remote handlers: every request is validated server-side.
remotes.StealBrainrot.OnServerEvent:Connect(function(player, model)
	if typeof(model) == "Instance" and model:IsA("Model") then
		StealService.trySteal(player, model)
	end
end)

remotes.Slap.OnServerEvent:Connect(function(player)
	StealService.trySlap(player)
end)

remotes.LockBase.OnServerEvent:Connect(function(player)
	local plotIndex = GameState.plotOf(player)
	if plotIndex == nil then
		return
	end
	if BaseManager.lockBase(plotIndex) then
		remotes.Notify:FireClient(player, "Base locked for 60 seconds! Nobody can steal from you now.")
	else
		local cooldown = GameState.lockCooldownLeft(plotIndex)
		if cooldown > 0 then
			remotes.Notify:FireClient(player, string.format("Lock is cooling down — %d seconds left.", cooldown))
		else
			remotes.Notify:FireClient(player, "Your base is already locked.")
		end
	end
end)

remotes.Rebirth.OnServerEvent:Connect(function(player)
	RebirthService.tryRebirth(player)
end)

-- 4. Players: fresh wallet, leaderboard values, a free base plot.
local function onPlayerAdded(player: Player)
	GameState.players[player] = GameState.newPlayerData()
	Economy.setupLeaderstats(player)
	local plotIndex = GameState.claimFreePlot(player)
	if plotIndex ~= nil then
		remotes.Notify:FireClient(player, string.format("Welcome to Brainrot Bazaar! Base %d is yours. Click a brainrot on the belt to buy it.", plotIndex))
	else
		remotes.Notify:FireClient(player, "Welcome to Brainrot Bazaar! All bases are taken — spectate and steal!")
	end
end

local function onPlayerRemoving(player: Player)
	-- Drop anything they were carrying, then clear their base.
	StealService.dropCarried(player)
	local data = GameState.players[player]
	if data ~= nil then
		for _, record in ipairs(data.brainrots) do
			BaseManager.removeFromBase(record)
			GameState.unregisterBrainrot(record.model)
			record.model:Destroy()
		end
	end
	local plotIndex = GameState.plotOf(player)
	if plotIndex ~= nil then
		GameState.bases[plotIndex].owner = nil
	end
	GameState.players[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- 5. Start every service.
ConveyorService.start()
Economy.startTickLoop()
StealService.startCarryLoop()
EventService.startLoop()
NpcRivalService.start()

-- Locks expire on their own clock; refresh the walls every few seconds.
task.spawn(function()
	while true do
		task.wait(5)
		BaseManager.refreshAllLockWalls()
	end
end)

print("Brainrot Bazaar: ready. First event in 45 seconds.")
