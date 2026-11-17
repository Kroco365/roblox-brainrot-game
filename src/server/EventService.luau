--!nocheck
-- EventService: the threat that forces the dash home. Every couple of minutes
-- a random event fires, announced on every player's screen:
--   * Tsunami Wave: a wall of water sweeps the map west to east. Anyone caught
--     on low ground is knocked back to spawn and drops what they carry.
--     The hill and your own locked base are the only safe ground.
--   * Brainrot Rain: 30 seconds of double spawns with boosted Epic-or-better.
--   * Golden Hour: 60 seconds of double income for every brainrot.
-- triggerEvent(name) is the hook TOUR.json calls, so reviewers can fire one.

local EventService = {}

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameState = require(script.Parent:WaitForChild("GameState"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))
local StealService = require(script.Parent:WaitForChild("StealService"))

local EVENT_INTERVAL = 150
local EVENT_NAMES = { "Tsunami Wave", "Brainrot Rain", "Golden Hour" }

local remotes = nil

function EventService.setRemotes(r)
	remotes = r
end

function EventService.announce(title: string, detail: string)
	if remotes ~= nil then
		remotes.EventAlert:FireAllClients(title, detail)
	end
end

-- Fire one event by name. Returns false for an unknown name.
function EventService.triggerEvent(name: string): boolean
	if name == "Tsunami Wave" then
		EventService.startTsunami()
		return true
	elseif name == "Brainrot Rain" then
		EventService.startBrainrotRain()
		return true
	elseif name == "Golden Hour" then
		EventService.startGoldenHour()
		return true
	end
	return false
end

-- A wall of water sweeps the map. Players below the hill's top get knocked
-- to spawn and drop whatever they are carrying.
function EventService.startTsunami()
	if GameState.events.activeEvent ~= nil then
		return
	end
	GameState.events.activeEvent = "Tsunami Wave"
	EventService.announce("TSUNAMI INCOMING!", "Get to the hill or your base — the wave is coming!")
	task.spawn(function()
		task.wait(15)
		local world = Workspace:WaitForChild("BrainrotWorld")
		local wall = Instance.new("Part")
		wall.Name = "TsunamiWall"
		wall.Size = Vector3.new(8, 40, 260)
		wall.Position = Vector3.new(-130, 18, 0)
		wall.Color = Color3.fromRGB(40, 120, 255)
		wall.Material = Enum.Material.Neon
		wall.Transparency = 0.35
		wall.Anchored = true
		wall.CanCollide = false
		wall.Parent = world
		EventService.announce("TSUNAMI!", "RUN! Get to high ground!")
		local startClock = os.clock()
		local hitPlayers = {}
		while os.clock() - startClock < 22 do
			local dt = RunService.Heartbeat:Wait()
			wall.Position += Vector3.new(12 * dt, 0, 0)
			local wallX = wall.Position.X
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root ~= nil and hitPlayers[player] == nil then
					local pos = root.Position
					local onHighGround = pos.Y > WorldBuilder.HILL_TOP_Y - 2
					local inOwnBase = false
					local plotIndex = GameState.plotOf(player)
					if plotIndex ~= nil and BaseManager.positionInPlot(pos, plotIndex) then
						inOwnBase = true
					end
					if math.abs(pos.X - wallX) <= 6 and not onHighGround and not inOwnBase then
						hitPlayers[player] = true
						StealService.dropCarried(player)
						character:PivotTo(CFrame.new(WorldBuilder.SPAWN_POSITION))
						EventService.notify(player, "The tsunami swept you back to spawn!")
					end
				end
			end
			if wall.Position.X > 140 then
				break
			end
		end
		wall:Destroy()
		GameState.events.activeEvent = nil
		EventService.announce("The wave has passed.", "The bazaar is safe... for now.")
	end)
end

function EventService.startBrainrotRain()
	if GameState.events.activeEvent ~= nil then
		return
	end
	GameState.events.activeEvent = "Brainrot Rain"
	GameState.events.spawnBoost = 3
	EventService.announce("BRAINROT RAIN!", "Double spawns, boosted rares for 30 seconds!")
	task.spawn(function()
		task.wait(30)
		GameState.events.spawnBoost = 1
		GameState.events.activeEvent = nil
		EventService.announce("The rain has stopped.", "Back to normal spawns.")
	end)
end

function EventService.startGoldenHour()
	if GameState.events.activeEvent ~= nil then
		return
	end
	GameState.events.activeEvent = "Golden Hour"
	GameState.events.income = 2
	EventService.announce("GOLDEN HOUR!", "Double income for 60 seconds!")
	task.spawn(function()
		task.wait(60)
		GameState.events.income = 1
		GameState.events.activeEvent = nil
		EventService.announce("Golden Hour is over.", "Income is back to normal.")
	end)
end

function EventService.notify(player: Player, text: string)
	if remotes ~= nil then
		remotes.Notify:FireClient(player, text)
	end
end

-- The event clock: a random event every EVENT_INTERVAL seconds.
function EventService.startLoop()
	task.spawn(function()
		task.wait(45)
		while true do
			local name = EVENT_NAMES[math.random(1, #EVENT_NAMES)]
			EventService.triggerEvent(name)
			task.wait(EVENT_INTERVAL)
		end
	end)
end

return EventService
