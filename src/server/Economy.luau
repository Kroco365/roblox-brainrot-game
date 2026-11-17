--!nocheck
-- Economy: cash, income and the per-second tick. Every second each player and
-- bot earns the sum of their base brainrots' rates, then the server syncs the
-- client HUD (cash, income, rebirths, lock timers, leaderboard).

local Economy = {}

local GameState = require(script.Parent:WaitForChild("GameState"))

local remotes = nil

function Economy.setRemotes(r)
	remotes = r
end

-- Create the Roblox leaderboard values for a player.
function Economy.setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = GameState.STARTING_CASH
	cash.Parent = stats
	local income = Instance.new("IntValue")
	income.Name = "Income"
	income.Value = 0
	income.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = stats
end

-- One income tick for a single owner (player data or bot data).
function Economy.tickOwner(data, dt: number)
	local income = GameState.incomePerSecond(data)
	data.cash += income * dt
	return income
end

-- Push one player's HUD state to their client.
function Economy.syncPlayer(player: Player)
	if remotes == nil then
		return
	end
	local data = GameState.players[player]
	if data == nil then
		return
	end
	local plotIndex = GameState.plotOf(player)
	local payload = {
		cash = math.floor(data.cash),
		income = math.floor(GameState.incomePerSecond(data)),
		rebirths = data.rebirths,
		multiplier = data.multiplier,
		slotsUsed = #data.brainrots,
		slotsMax = GameState.MAX_BRAINROTS_PER_PLAYER,
		lockSecondsLeft = plotIndex and GameState.lockSecondsLeft(plotIndex) or 0,
		lockCooldownLeft = plotIndex and GameState.lockCooldownLeft(plotIndex) or 0,
		plotIndex = plotIndex or 0,
		top = GameState.topPlayers(5),
	}
	remotes.StateSync:FireClient(player, payload)
end

-- The master 1-second loop: earn, then sync every player.
function Economy.startTickLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, data in pairs(GameState.players) do
				Economy.tickOwner(data, 1)
			end
			for _, data in pairs(GameState.bots) do
				Economy.tickOwner(data, 1)
			end
			for player, data in pairs(GameState.players) do
				local stats = player:FindFirstChild("leaderstats")
				if stats then
					local cash = stats:FindFirstChild("Cash")
					if cash and cash:IsA("IntValue") then
						cash.Value = math.floor(data.cash)
					end
					local income = stats:FindFirstChild("Income")
					if income and income:IsA("IntValue") then
						income.Value = math.floor(GameState.incomePerSecond(data))
					end
					local rebirths = stats:FindFirstChild("Rebirths")
					if rebirths and rebirths:IsA("IntValue") then
						rebirths.Value = data.rebirths
					end
				end
				Economy.syncPlayer(player)
			end
		end
	end)
end

return Economy
