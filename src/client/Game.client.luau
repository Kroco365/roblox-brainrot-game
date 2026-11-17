--!nocheck
-- Brainrot Bazaar: the client. Builds the whole ScreenGui in code (top bar
-- with cash and income, base buttons, the brainrot index, the leaderboard,
-- event banners and the steal prompt) and talks to the server only through
-- the Remotes. Buying is a click on the brainrot itself (ClickDetector);
-- stealing is E (or the Steal button) when the prompt shows a target near
-- you; slapping is F. All prices, locks and cooldowns are enforced server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local StealBrainrot = remotes:WaitForChild("StealBrainrot")
local SlapRemote = remotes:WaitForChild("Slap")
local LockBaseRemote = remotes:WaitForChild("LockBase")
local RebirthRemote = remotes:WaitForChild("Rebirth")
local StateSync = remotes:WaitForChild("StateSync")
local NotifyRemote = remotes:WaitForChild("Notify")
local EventAlert = remotes:WaitForChild("EventAlert")

-- The 8 base plot centres, matching WorldBuilder on the server.
local PLOT_CENTERS = {
	Vector3.new(-84, 0, -52), Vector3.new(-28, 0, -52), Vector3.new(28, 0, -52), Vector3.new(84, 0, -52),
	Vector3.new(-84, 0, 52), Vector3.new(-28, 0, 52), Vector3.new(28, 0, 52), Vector3.new(84, 0, 52),
}

local myPlotIndex = 0
local stealTarget = nil

-- ---------- GUI helpers ----------

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local function makeLabel(name: string, parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = Enum.Font.SourceSansBold
	label.TextStrokeTransparency = 0.3
	label.Parent = parent
	return label
end

local function makeButton(name: string, parent: Instance, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	button.BackgroundTransparency = 0.15
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 18
	button.Font = Enum.Font.SourceSansBold
	button.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.Parent = parent
	return button
end

local function makePanel(name: string, parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.AnchorPoint = anchor
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	panel.Parent = parent
	return panel
end

-- ---------- Top bar: cash, income, rebirths ----------

local topBar = makePanel("TopBar", gui, UDim2.fromOffset(360, 64), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
local cashLabel = makeLabel("Cash", topBar, "$100", UDim2.new(1, 0, 0.55, 0), UDim2.new(0, 0, 0, 2), 28, Color3.fromRGB(255, 220, 80))
cashLabel.TextXAlignment = Enum.TextXAlignment.Center
local incomeLabel = makeLabel("Income", topBar, "$0/s  •  Rebirths: 0  •  0/8 brainrots", UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0.55, 0), 15, Color3.fromRGB(220, 220, 220))
incomeLabel.TextXAlignment = Enum.TextXAlignment.Center

-- ---------- Leaderboard (top right) ----------

local board = makePanel("Leaderboard", gui, UDim2.fromOffset(230, 170), UDim2.new(1, -10, 0, 10), Vector2.new(1, 0))
local boardTitle = makeLabel("Title", board, "TOP EARNERS", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 4), 17, Color3.fromRGB(255, 220, 80))
boardTitle.TextXAlignment = Enum.TextXAlignment.Center
local boardRows = {}
for i = 1, 5 do
	local row = makeLabel("Row" .. i, board, "", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 28 + (i - 1) * 26), 15, Color3.fromRGB(235, 235, 235))
	row.TextXAlignment = Enum.TextXAlignment.Left
	boardRows[i] = row
end

-- ---------- Event banner and notifications (centre) ----------

local banner = makePanel("EventBanner", gui, UDim2.fromOffset(460, 72), UDim2.new(0.5, 0, 0, 86), Vector2.new(0.5, 0))
banner.Visible = false
local bannerTitle = makeLabel("BannerTitle", banner, "", UDim2.new(1, 0, 0.55, 0), UDim2.new(0, 0, 0, 4), 26, Color3.fromRGB(255, 220, 80))
bannerTitle.TextXAlignment = Enum.TextXAlignment.Center
local bannerDetail = makeLabel("BannerDetail", banner, "", UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0.55, 0), 16, Color3.fromRGB(235, 235, 235))
bannerDetail.TextXAlignment = Enum.TextXAlignment.Center

local notifyLabel = makeLabel("Notify", gui, "", UDim2.fromOffset(520, 30), UDim2.new(0.5, 0, 0, 168), 17, Color3.fromRGB(255, 255, 255))
notifyLabel.AnchorPoint = Vector2.new(0.5, 0)
notifyLabel.TextXAlignment = Enum.TextXAlignment.Center
notifyLabel.Visible = false

-- ---------- Bottom buttons ----------

local buttonRow = makePanel("ButtonRow", gui, UDim2.fromOffset(440, 52), UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1))
local indexButton = makeButton("IndexButton", buttonRow, "Index", UDim2.fromOffset(100, 40), UDim2.new(0, 6, 0, 6))
local lockButton = makeButton("LockButton", buttonRow, "Lock Base", UDim2.fromOffset(110, 40), UDim2.new(0, 112, 0, 6))
local rebirthButton = makeButton("RebirthButton", buttonRow, "Rebirth", UDim2.fromOffset(100, 40), UDim2.new(0, 228, 0, 6))
local slapButton = makeButton("SlapButton", buttonRow, "Slap (F)", UDim2.fromOffset(100, 40), UDim2.new(0, 334, 0, 6))

local stealHint = makeLabel("StealHint", gui, "", UDim2.fromOffset(420, 30), UDim2.new(0.5, 0, 1, -72), 18, Color3.fromRGB(255, 120, 120))
stealHint.AnchorPoint = Vector2.new(0.5, 0)
stealHint.TextXAlignment = Enum.TextXAlignment.Center
stealHint.Visible = false

-- ---------- Index panel: the whole cast, by rarity ----------

local indexFrame = makePanel("IndexFrame", gui, UDim2.fromOffset(320, 430), UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
indexFrame.Visible = false
local indexTitle = makeLabel("IndexTitle", indexFrame, "BRAINROT INDEX — 11 characters", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 4), 18, Color3.fromRGB(255, 220, 80))
indexTitle.TextXAlignment = Enum.TextXAlignment.Center
local indexList = Instance.new("ScrollingFrame")
indexList.Name = "IndexList"
indexList.Size = UDim2.new(1, -12, 1, -40)
indexList.Position = UDim2.new(0, 6, 0, 36)
indexList.BackgroundTransparency = 1
indexList.ScrollBarThickness = 6
indexList.CanvasSize = UDim2.new(0, 0, 0, 0)
indexList.Parent = indexFrame

local sorted = {}
for _, entry in ipairs(Catalog.BRAINROTS) do
	table.insert(sorted, entry)
end
local rarityRank = {}
for i, rarity in ipairs(Catalog.RARITY_ORDER) do
	rarityRank[rarity] = i
end
table.sort(sorted, function(a, b)
	if rarityRank[a.rarity] ~= rarityRank[b.rarity] then
		return rarityRank[a.rarity] < rarityRank[b.rarity]
	end
	return a.rate < b.rate
end)

local y = 0
for _, entry in ipairs(sorted) do
	local row = Instance.new("Frame")
	row.Name = entry.id
	row.Size = UDim2.new(1, -6, 0, 52)
	row.Position = UDim2.new(0, 3, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	row.BackgroundTransparency = 0.1
	row.BorderSizePixel = 0
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row
	row.Parent = indexList
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(10, 10)
	dot.Position = UDim2.new(0, 8, 0, 8)
	dot.BackgroundColor3 = Catalog.RARITY_COLORS[entry.rarity]
	dot.BorderSizePixel = 0
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = dot
	dot.Parent = row
	local nameLabel = makeLabel("EntryName", row, entry.name, UDim2.new(1, -26, 0, 20), UDim2.new(0, 24, 0, 4), 16, Color3.fromRGB(255, 255, 255))
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	local statLabel = makeLabel("EntryStats", row, string.format("%s  •  $%d/s  •  $%d", entry.rarity, entry.rate, entry.cost), UDim2.new(1, -26, 0, 16), UDim2.new(0, 24, 0, 24), 13, Catalog.RARITY_COLORS[entry.rarity])
	statLabel.TextXAlignment = Enum.TextXAlignment.Left
	local blurbLabel = makeLabel("EntryBlurb", row, entry.blurb, UDim2.new(1, -26, 0, 14), UDim2.new(0, 24, 0, 40), 11, Color3.fromRGB(180, 180, 180))
	blurbLabel.TextXAlignment = Enum.TextXAlignment.Left
	y += 56
end
indexList.CanvasSize = UDim2.new(0, 0, 0, y)

-- ---------- Wiring ----------

indexButton.MouseButton1Click:Connect(function()
	indexFrame.Visible = not indexFrame.Visible
end)

lockButton.MouseButton1Click:Connect(function()
	LockBaseRemote:FireServer()
end)

local rebirthArmedAt = 0
rebirthButton.MouseButton1Click:Connect(function()
	-- Two clicks to rebirth: the first arms it, the second confirms.
	if os.clock() - rebirthArmedAt < 3 then
		RebirthRemote:FireServer()
		rebirthButton.Text = "Rebirth"
		rebirthArmedAt = 0
	else
		rebirthArmedAt = os.clock()
		rebirthButton.Text = "Sure? ($10k + 5)"
		task.delay(3, function()
			rebirthButton.Text = "Rebirth"
		end)
	end
end)

slapButton.MouseButton1Click:Connect(function()
	SlapRemote:FireServer()
end)

local function doSteal()
	if stealTarget ~= nil then
		StealBrainrot:FireServer(stealTarget)
	end
end

local function doSlap()
	SlapRemote:FireServer()
end

ContextActionService:BindAction("StealBrainrot", function(_, state)
	if state == Enum.UserInputState.Begin then
		doSteal()
	end
end, false, Enum.KeyCode.E)

ContextActionService:BindAction("Slap", function(_, state)
	if state == Enum.UserInputState.Begin then
		doSlap()
	end
end, false, Enum.KeyCode.F)

-- ---------- Server sync ----------

local function showNotify(text: string)
	notifyLabel.Text = text
	notifyLabel.Visible = true
	task.delay(4, function()
		notifyLabel.Visible = false
	end)
end

local function showBanner(title: string, detail: string)
	bannerTitle.Text = title
	bannerDetail.Text = detail
	banner.Visible = true
	task.delay(6, function()
		banner.Visible = false
	end)
end

StateSync.OnClientEvent:Connect(function(payload)
	cashLabel.Text = string.format("$%d", payload.cash)
	incomeLabel.Text = string.format("$%d/s  •  Rebirths: %d (x%.1f)  •  %d/%d brainrots", payload.income, payload.rebirths, payload.multiplier, payload.slotsUsed, payload.slotsMax)
	myPlotIndex = payload.plotIndex or 0
	if payload.lockSecondsLeft > 0 then
		lockButton.Text = string.format("Locked (%ds)", payload.lockSecondsLeft)
	elseif payload.lockCooldownLeft > 0 then
		lockButton.Text = string.format("Lock (%ds)", payload.lockCooldownLeft)
	else
		lockButton.Text = "Lock Base"
	end
	for i, row in ipairs(boardRows) do
		local entry = payload.top[i]
		if entry ~= nil then
			row.Text = string.format("%d. %s — $%d", i, entry.name, entry.cash)
		else
			row.Text = ""
		end
	end
end)

NotifyRemote.OnClientEvent:Connect(showNotify)
EventAlert.OnClientEvent:Connect(showBanner)

-- ---------- Steal targeting: nearest brainrot on somebody else's base ----------
-- The server re-checks everything; this only decides what the prompt offers.

local function isOnConveyor(position: Vector3): boolean
	return math.abs(position.Z) < 6 and position.X > -92 and position.X < 92
end

local function isOnMyBase(position: Vector3): boolean
	if myPlotIndex == 0 then
		return false
	end
	local center = PLOT_CENTERS[myPlotIndex]
	return math.abs(position.X - center.X) <= 12 and math.abs(position.Z - center.Z) <= 9
end

local function findStealTarget(): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return nil
	end
	local world = workspace:FindFirstChild("BrainrotWorld")
	if world == nil then
		return nil
	end
	local best = nil
	local bestDist = 10
	for _, descendant in ipairs(world:GetDescendants()) do
		if descendant:IsA("Model") and descendant.PrimaryPart ~= nil and descendant:FindFirstChild("Body") ~= nil then
			local pos = descendant:GetPivot().Position
			if not isOnConveyor(pos) and not isOnMyBase(pos) then
				local dist = (pos - root.Position).Magnitude
				if dist < bestDist then
					bestDist = dist
					best = descendant
				end
			end
		end
	end
	return best
end

task.spawn(function()
	while true do
		task.wait(0.25)
		stealTarget = findStealTarget()
		if stealTarget ~= nil then
			stealHint.Text = string.format("Press E to steal %s!", stealTarget.Name)
			stealHint.Visible = true
		else
			stealHint.Visible = false
		end
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")
