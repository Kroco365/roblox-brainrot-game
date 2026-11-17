--!nocheck
-- RebirthService: the prestige ladder. A player with at least $10,000 and 5
-- brainrots can rebirth: their cash resets to $100 and their brainrots are
-- cleared, but every future brainrot earns +50% income per rebirth, forever.
-- The rebirth count shows on the leaderboard and in the HUD.

local RebirthService = {}

local GameState = require(script.Parent:WaitForChild("GameState"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))

RebirthService.CASH_REQUIRED = 10000
RebirthService.BRAINROTS_REQUIRED = 5
RebirthService.MULTIPLIER_PER_REBIRTH = 0.5

local remotes = nil

function RebirthService.setRemotes(r)
	remotes = r
end

function RebirthService.canRebirth(player: Player): (boolean, string)
	local data = GameState.players[player]
	if data == nil then
		return false, "No player data."
	end
	if data.cash < RebirthService.CASH_REQUIRED then
		return false, string.format("Rebirth needs $%d cash — you have $%d.", RebirthService.CASH_REQUIRED, math.floor(data.cash))
	end
	if #data.brainrots < RebirthService.BRAINROTS_REQUIRED then
		return false, string.format("Rebirth needs %d brainrots — you have %d.", RebirthService.BRAINROTS_REQUIRED, #data.brainrots)
	end
	return true, "Ready to rebirth!"
end

function RebirthService.tryRebirth(player: Player): boolean
	local ok, message = RebirthService.canRebirth(player)
	if not ok then
		RebirthService.notify(player, message)
		return false
	end
	local data = GameState.players[player]
	-- Clear every brainrot the player owns, model and all.
	for _, record in ipairs(data.brainrots) do
		BaseManager.removeFromBase(record)
		GameState.unregisterBrainrot(record.model)
		record.model:Destroy()
	end
	data.brainrots = {}
	data.cash = GameState.STARTING_CASH
	data.rebirths += 1
	data.multiplier = 1 + data.rebirths * RebirthService.MULTIPLIER_PER_REBIRTH
	RebirthService.notify(player, string.format("REBIRTH #%d! All brainrots now earn x%.1f income.", data.rebirths, data.multiplier))
	return true
end

function RebirthService.notify(player: Player, text: string)
	if remotes ~= nil then
		remotes.Notify:FireClient(player, text)
	end
end

return RebirthService
