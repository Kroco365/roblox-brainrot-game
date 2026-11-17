--!nocheck
-- CharacterFactory: builds the visible bodies of brainrots and NPC rivals out
-- of plain Parts. No asset ids, no meshes: every character is a chunky little
-- statue with a coloured body, a face, its own accessory and a floating name
-- tag that reads its name, rarity and dollars-per-second at a glance.

local CharacterFactory = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotCatalog"))

local function makePart(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addFace(model: Model, head: Part)
	-- Two white eyes and a smile, stuck on the front (+Z) face of the head.
	local eyeL = makePart("EyeLeft", Vector3.new(0.5, 0.8, 0.3), Vector3.new(-0.7, 0.4, 1.6), Color3.fromRGB(255, 255, 255))
	eyeL.Parent = model
	local eyeR = makePart("EyeRight", Vector3.new(0.5, 0.8, 0.3), Vector3.new(0.7, 0.4, 1.6), Color3.fromRGB(255, 255, 255))
	eyeR.Parent = model
	local pupilL = makePart("PupilLeft", Vector3.new(0.25, 0.4, 0.1), Vector3.new(-0.7, 0.4, 1.8), Color3.fromRGB(20, 20, 20))
	pupilL.Parent = model
	local pupilR = makePart("PupilRight", Vector3.new(0.25, 0.4, 0.1), Vector3.new(0.7, 0.4, 1.8), Color3.fromRGB(20, 20, 20))
	pupilR.Parent = model
	local smile = makePart("Smile", Vector3.new(1.2, 0.3, 0.1), Vector3.new(0, -0.5, 1.6), Color3.fromRGB(20, 20, 20))
	smile.Parent = model
	head:GetPropertyChangedSignal("CFrame"):Connect(function() end)
end

-- The accessory each character wears, built from parts on top of its head.
local function addAccessory(model: Model, accessory: string, color: Color3)
	if accessory == "Cone" then
		local cone = makePart("AccessoryCone", Vector3.new(2, 2.5, 2), Vector3.new(0, 3.4, 0), Color3.fromRGB(255, 120, 0))
		cone.Shape = Enum.PartType.Ball
		cone.Parent = model
	elseif accessory == "Crown" then
		local crown = makePart("AccessoryCrown", Vector3.new(2.6, 0.8, 2.6), Vector3.new(0, 2.4, 0), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
		crown.Parent = model
	elseif accessory == "Headphones" then
		local band = makePart("AccessoryBand", Vector3.new(3.4, 0.5, 0.5), Vector3.new(0, 2.6, 0), Color3.fromRGB(40, 40, 50))
		band.Parent = model
		local cupL = makePart("AccessoryCupL", Vector3.new(0.6, 1.4, 1.4), Vector3.new(-1.7, 1.8, 0), Color3.fromRGB(40, 40, 50))
		cupL.Parent = model
		local cupR = makePart("AccessoryCupR", Vector3.new(0.6, 1.4, 1.4), Vector3.new(1.7, 1.8, 0), Color3.fromRGB(40, 40, 50))
		cupR.Parent = model
	elseif accessory == "Antenna" then
		local rod = makePart("AccessoryRod", Vector3.new(0.3, 2, 0.3), Vector3.new(0, 3, 0), Color3.fromRGB(150, 150, 160))
		rod.Parent = model
		local tip = makePart("AccessoryTip", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 4.2, 0), Color3.fromRGB(255, 80, 80), Enum.Material.Neon)
		tip.Shape = Enum.PartType.Ball
		tip.Parent = model
	elseif accessory == "TopHat" then
		local brim = makePart("AccessoryBrim", Vector3.new(3.4, 0.3, 3.4), Vector3.new(0, 2.3, 0), Color3.fromRGB(30, 30, 35))
		brim.Parent = model
		local top = makePart("AccessoryTop", Vector3.new(2, 1.8, 2), Vector3.new(0, 3.3, 0), Color3.fromRGB(30, 30, 35))
		top.Parent = model
	elseif accessory == "Spikes" then
		for _, dx in ipairs({ -1.2, 0, 1.2 }) do
			local spike = makePart("AccessorySpike", Vector3.new(0.4, 1.4, 0.4), Vector3.new(dx, 2.8, 0), Color3.fromRGB(20, 130, 50))
			spike.Parent = model
		end
	elseif accessory == "CaptainHat" then
		local hat = makePart("AccessoryCap", Vector3.new(3.6, 0.8, 3.6), Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 255, 255))
		hat.Parent = model
		local brim = makePart("AccessoryBrim", Vector3.new(3.8, 0.3, 1.2), Vector3.new(0, 2.1, 1.4), Color3.fromRGB(20, 20, 30))
		brim.Parent = model
	elseif accessory == "Foil" then
		local wrap = makePart("AccessoryFoil", Vector3.new(3.4, 1.2, 3.4), Vector3.new(0, 0.4, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		wrap.Parent = model
	elseif accessory == "Glow" then
		local glow = makePart("AccessoryGlow", Vector3.new(4, 4, 4), Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 230, 40), Enum.Material.Neon)
		glow.Transparency = 0.7
		glow.Parent = model
	elseif accessory == "Tie" then
		local tie = makePart("AccessoryTie", Vector3.new(0.6, 2, 0.3), Vector3.new(0, 0.2, 1.7), Color3.fromRGB(180, 40, 40))
		tie.Parent = model
	elseif accessory == "PaperStack" then
		local stack = makePart("AccessoryPaper", Vector3.new(2.4, 1, 2.4), Vector3.new(0, 2.6, 0), Color3.fromRGB(255, 255, 255))
		stack.Parent = model
	end
end

-- Floating name tag: name on top, rarity and $/s below, coloured by rarity.
local function addNameTag(model: Model, title: string, subtitle: string, rarityColor: Color3, mutationColor: Color3)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = primary
	gui.Size = UDim2.fromOffset(140, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = title
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.Parent = gui
	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Rate"
	subLabel.Position = UDim2.new(0, 0, 0.5, 0)
	subLabel.Size = UDim2.new(1, 0, 0.5, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = subtitle
	subLabel.TextColor3 = rarityColor
	subLabel.TextStrokeTransparency = 0.2
	subLabel.TextScaled = true
	subLabel.Font = Enum.Font.SourceSansBold
	subLabel.Parent = gui
	-- A thin mutation-coloured bar under the tag.
	local bar = Instance.new("Frame")
	bar.Name = "MutationBar"
	bar.Position = UDim2.new(0.15, 0, 1, 2)
	bar.Size = UDim2.new(0.7, 0, 0, 4)
	bar.BackgroundColor3 = mutationColor
	bar.BorderSizePixel = 0
	bar.Parent = gui
	gui.Parent = primary
end

-- Builds one brainrot's Model at the origin, facing +Z. Callers move it with
-- SetPrimaryPartCFrame / PivotTo to the conveyor or a base slot.
function CharacterFactory.buildBrainrot(entry, mutationName: string, mutationMultiplier: number, mutationColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = entry.name
	local body = makePart("Body", Vector3.new(3, 3, 3), Vector3.new(0, 1.5, 0), entry.color)
	model.PrimaryPart = body
	body.Parent = model
	local head = makePart("Head", Vector3.new(2.6, 2.2, 2.6), Vector3.new(0, 4, 0), entry.color)
	head.Parent = model
	addFace(model, head)
	addAccessory(model, entry.accessory, entry.color)
	-- Mutated brainrots wear a glowing ring at their feet.
	if mutationName ~= "Normal" then
		local ring = makePart("MutationRing", Vector3.new(4.4, 0.3, 4.4), Vector3.new(0, 0.2, 0), mutationColor, Enum.Material.Neon)
		ring.Parent = model
	end
	local rate = Catalog.rateFor(entry, mutationMultiplier, 1)
	local subtitle = string.format("%s  $%d/s", entry.rarity, rate)
	if mutationName ~= "Normal" then
		subtitle = mutationName .. " " .. subtitle
	end
	addNameTag(model, entry.name, subtitle, Catalog.RARITY_COLORS[entry.rarity], mutationColor)
	return model
end

-- Rebuilds a brainrot's name tag after its rate changes (rebirth multiplier).
function CharacterFactory.refreshBrainrotTag(model: Model, entry, mutationName: string, mutationMultiplier: number, mutationColor: Color3, rebirthMultiplier: number)
	local tag = model:FindFirstChild("Body") and model.Body:FindFirstChild("NameTag")
	if not tag then
		return
	end
	local rateLabel = tag:FindFirstChild("Rate")
	if rateLabel and rateLabel:IsA("TextLabel") then
		local rate = Catalog.rateFor(entry, mutationMultiplier, rebirthMultiplier)
		local subtitle = string.format("%s  $%d/s", entry.rarity, rate)
		if mutationName ~= "Normal" then
			subtitle = mutationName .. " " .. subtitle
		end
		rateLabel.Text = subtitle
	end
end

-- A simple blocky NPC rival rig with a Humanoid, so it can walk with MoveTo.
function CharacterFactory.buildNpcRig(displayName: string, shirtColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = displayName
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Position = Vector3.new(0, 3, 0)
	root.Color = Color3.fromRGB(200, 200, 200)
	root.Anchored = false
	root.CanCollide = true
	model.PrimaryPart = root
	root.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = Vector3.new(0, 3, 0)
	torso.Color = shirtColor
	torso.Anchored = false
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Position = Vector3.new(0, 5, 0)
	head.Color = Color3.fromRGB(255, 210, 150)
	head.Anchored = false
	head.Parent = model
	local legL = Instance.new("Part")
	legL.Name = "LeftLeg"
	legL.Size = Vector3.new(1, 2, 1)
	legL.Position = Vector3.new(-0.5, 1, 0)
	legL.Color = Color3.fromRGB(60, 60, 120)
	legL.Anchored = false
	legL.Parent = model
	local legR = Instance.new("Part")
	legR.Name = "RightLeg"
	legR.Size = Vector3.new(1, 2, 1)
	legR.Position = Vector3.new(0.5, 1, 0)
	legR.Color = Color3.fromRGB(60, 60, 120)
	legR.Anchored = false
	legR.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = displayName
	humanoid.WalkSpeed = 12
	humanoid.Parent = model
	-- Weld the rig together so it walks as one body.
	local function weld(a: BasePart, b: BasePart, offset: CFrame)
		local w = Instance.new("Weld")
		w.Part0 = a
		w.Part1 = b
		w.C0 = offset
		w.Parent = a
	end
	weld(root, torso, CFrame.new(0, 0, 0))
	weld(torso, head, CFrame.new(0, 2, 0))
	weld(torso, legL, CFrame.new(-0.5, -2, 0))
	weld(torso, legR, CFrame.new(0.5, -2, 0))
	-- Name tag above the bot, so players can tell it from a real player.
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(120, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = displayName .. " (BOT)"
	label.TextColor3 = Color3.fromRGB(255, 120, 120)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Parent = gui
	gui.Parent = head
	return model
end

return CharacterFactory
