--!nocheck
-- GameState: the one place all server state lives. Every other server module
-- reads and writes through here, so cash, bases, brainrots, locks and events
-- can never disagree with each other.
--
-- A brainrot record: { entry, mutationName, mutationMultiplier, mutationColor,
--   model, owner (Player | string bot name | nil), state, plotIndex, slotIndex }
-- state is one of "conveyor" (walking the belt), "base" (earning on a plot),
-- "carried" (stolen, above a player's head) or "returning" (flying home).

local GameState = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))

GameState.STARTING_CASH = 100
GameState.MAX_BRAINROTS_PER_PLAYER = 8
GameState.LOCK_DURATION = 60
GameState.LOCK_COOLDOWN = 180

-- Players: [Player] = { cash, rebirths, multiplier, brainrots = { record } }
GameState.players = {}
-- Bots: [botName] = { cash, rebirths, multiplier, brainrots, plotIndex, model }
GameState.bots = {}
-- Bases: [plotIndex] = { owner (Player | botName | nil), lockedUntil, lockCooldownUntil, slots = { [slotIndex] = record } }
GameState.bases = {}
-- Every live brainrot model, keyed by the Model instance itself.
GameState.brainrots = {}
-- Event multipliers the economy reads: { income = 1, spawnBoost = 1, activeEvent = nil }
GameState.events = { income = 1, spawnBoost = 1, activeEvent = nil }
-- The folder the conveyor's walking brainrots live under.
GameState.conveyorFolder = nil

function GameState.initBases(plotCount: number)
	for i = 1, plotCount do
		GameState.bases[i] = {
			owner = nil,
			lockedUntil = 0,
			lockCooldownUntil = 0,
			slots = {},
		}
	end
end

function GameState.newPlayerData(): { cash: number, rebirths: number, multiplier: number, brainrots: {} }
	return { cash = GameState.STARTING_CASH, rebirths = 0, multiplier = 1, brainrots = {} }
end

function GameState.newBotData(plotIndex: number): { cash: number, rebirths: number, multiplier: number, brainrots: {}, plotIndex: number, model: Model? }
	return { cash = GameState.STARTING_CASH, rebirths = 0, multiplier = 1, brainrots = {}, plotIndex = plotIndex, model = nil }
end

-- First free plot, in order, for a joining player.
function GameState.claimFreePlot(owner): number?
	for i, base in ipairs(GameState.bases) do
		if base.owner == nil then
			base.owner = owner
			return i
		end
	end
	return nil
end

function GameState.plotOf(owner): number?
	for i, base in ipairs(GameState.bases) do
		if base.owner == owner then
			return i
		end
	end
	return nil
end

function GameState.isBaseLocked(plotIndex: number): boolean
	local base = GameState.bases[plotIndex]
	return base ~= nil and os.clock() < base.lockedUntil
end

function GameState.lockSecondsLeft(plotIndex: number): number
	local base = GameState.bases[plotIndex]
	if base == nil then
		return 0
	end
	return math.max(0, math.floor(base.lockedUntil - os.clock()))
end

function GameState.lockCooldownLeft(plotIndex: number): number
	local base = GameState.bases[plotIndex]
	if base == nil then
		return 0
	end
	return math.max(0, math.floor(base.lockCooldownUntil - os.clock()))
end

-- Dollars per second a player (or bot) earns right now.
function GameState.incomePerSecond(data): number
	local total = 0
	for _, record in ipairs(data.brainrots) do
		if record.state == "base" then
			total += Catalog.rateFor(record.entry, record.mutationMultiplier, data.multiplier)
		end
	end
	return total * GameState.events.income
end

-- The top earners, for the client leaderboard: { { name, cash } }.
function GameState.topPlayers(limit: number): { { name: string, cash: number } }
	local rows = {}
	for player, data in pairs(GameState.players) do
		table.insert(rows, { name = player.DisplayName, cash = math.floor(data.cash) })
	end
	for botName, data in pairs(GameState.bots) do
		table.insert(rows, { name = botName .. " (BOT)", cash = math.floor(data.cash) })
	end
	table.sort(rows, function(a, b)
		return a.cash > b.cash
	end)
	local top = {}
	for i = 1, math.min(limit, #rows) do
		top[i] = rows[i]
	end
	return top
end

-- Register a brainrot record under its model.
function GameState.registerBrainrot(model: Model, record)
	GameState.brainrots[model] = record
end

function GameState.unregisterBrainrot(model: Model)
	GameState.brainrots[model] = nil
end

function GameState.recordOf(model: Model)
	return GameState.brainrots[model]
end

return GameState
