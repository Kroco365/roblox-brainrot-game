--!nocheck
-- BaseManager: who owns which plot, where brainrots sit on it, and the lock.
-- A base has 8 slots. Its lock wall stands at the entrance: locking it for
-- 60 seconds keeps thieves out (and starts a 180-second cooldown), so a
-- player who just bought a Mythic can guard it while they save for the next.

local BaseManager = {}

local GameState = require(script.Parent:WaitForChild("GameState"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))

local worldFolders = nil

function BaseManager.setWorldFolders(folders)
	worldFolders = folders
end

-- First empty slot index on a plot, or nil when the base is full.
function BaseManager.freeSlot(plotIndex: number): number?
	local base = GameState.bases[plotIndex]
	if base == nil then
		return nil
	end
	for i = 1, WorldBuilder.SLOTS_PER_BASE do
		if base.slots[i] == nil then
			return i
		end
	end
	return nil
end

-- Move a brainrot record onto a base slot and park its model there.
function BaseManager.placeOnBase(record, plotIndex: number, slotIndex: number)
	local base = GameState.bases[plotIndex]
	if base == nil then
		return false
	end
	base.slots[slotIndex] = record
	record.state = "base"
	record.plotIndex = plotIndex
	record.slotIndex = slotIndex
	local pos = WorldBuilder.slotPosition(plotIndex, slotIndex)
	record.model:PivotTo(CFrame.new(pos))
	return true
end

-- Take a brainrot off its base slot (stolen, sold back by rebirth, or dropped).
function BaseManager.removeFromBase(record)
	if record.plotIndex ~= nil and record.slotIndex ~= nil then
		local base = GameState.bases[record.plotIndex]
		if base ~= nil and base.slots[record.slotIndex] == record then
			base.slots[record.slotIndex] = nil
		end
	end
	record.plotIndex = nil
	record.slotIndex = nil
end

-- Refresh every name tag on a base after a rebirth changes its multiplier.
function BaseManager.refreshBaseTags(plotIndex: number, rebirthMultiplier: number)
	local base = GameState.bases[plotIndex]
	if base == nil then
		return
	end
	for _, record in pairs(base.slots) do
		CharacterFactory.refreshBrainrotTag(record.model, record.entry, record.mutationName, record.mutationMultiplier, record.mutationColor, rebirthMultiplier)
	end
end

-- Lock a base: wall up for 60 seconds, then a 180-second cooldown.
-- Returns true when the lock was applied, false when still cooling down.
function BaseManager.lockBase(plotIndex: number): boolean
	local base = GameState.bases[plotIndex]
	if base == nil then
		return false
	end
	local now = os.clock()
	if now < base.lockCooldownUntil then
		return false
	end
	if now < base.lockedUntil then
		return false
	end
	base.lockedUntil = now + GameState.LOCK_DURATION
	base.lockCooldownUntil = now + GameState.LOCK_COOLDOWN
	BaseManager.applyLockWall(plotIndex)
	return true
end

-- Show or hide a base's lock wall to match its lock state.
function BaseManager.applyLockWall(plotIndex: number)
	if worldFolders == nil then
		return
	end
	local folder = worldFolders.bases[plotIndex]
	if folder == nil then
		return
	end
	local wall = folder:FindFirstChild("LockWall")
	if wall == nil or not wall:IsA("BasePart") then
		return
	end
	if GameState.isBaseLocked(plotIndex) then
		wall.Transparency = 0.3
		wall.CanCollide = true
	else
		wall.Transparency = 1
		wall.CanCollide = false
	end
end

-- Re-check every lock wall (called on a timer; locks expire on their own).
function BaseManager.refreshAllLockWalls()
	for i = 1, #GameState.bases do
		BaseManager.applyLockWall(i)
	end
end

-- Is a world position inside a given plot's rectangle?
function BaseManager.positionInPlot(position: Vector3, plotIndex: number): boolean
	local plot = WorldBuilder.BASE_PLOTS[plotIndex]
	return math.abs(position.X - plot.center.X) <= 12 and math.abs(position.Z - plot.center.Z) <= 9
end

-- Which plot is a world position standing on, if any?
function BaseManager.plotAtPosition(position: Vector3): number?
	for i = 1, #WorldBuilder.BASE_PLOTS do
		if BaseManager.positionInPlot(position, i) then
			return i
		end
	end
	return nil
end

return BaseManager
