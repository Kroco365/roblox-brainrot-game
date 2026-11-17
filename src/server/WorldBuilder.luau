--!nocheck
-- WorldBuilder: builds the whole 3D world of Brainrot Bazaar at server start.
-- One module owns every layout number, so the conveyor, the bases, the safe
-- hill and the decorations all agree on the same map. The world is built from
-- plain Parts (no asset ids), so it loads identically on any account.
--
-- Map plan (studs, X east, Z south, ground top at Y = 0):
--   * a conveyor belt runs east-west through the middle, Z = 0
--   * 8 player bases, 4 north (Z = -52) and 4 south (Z = +52)
--   * a tsunami-safe hill at the far east end, X = 104
--   * player spawn at the far west end, X = -104
--   * a plaza with two meme statues and lamps between the rows

local WorldBuilder = {}

-- Layout constants other modules read (bases, conveyor, hill, spawn).
WorldBuilder.CONVEYOR_START_X = -88
WorldBuilder.CONVEYOR_END_X = 88
WorldBuilder.CONVEYOR_Z = 0
WorldBuilder.CONVEYOR_SPEED = 6
WorldBuilder.SLOTS_PER_BASE = 8
WorldBuilder.HILL_CENTER = Vector3.new(104, 0, 0)
WorldBuilder.HILL_TOP_Y = 12
WorldBuilder.SPAWN_POSITION = Vector3.new(-104, 2, 0)

-- The 8 base plots, in order. Plot 1 is the first player's home.
WorldBuilder.BASE_PLOTS = {
	{ center = Vector3.new(-84, 0, -52), color = Color3.fromRGB(80, 160, 255) },
	{ center = Vector3.new(-28, 0, -52), color = Color3.fromRGB(255, 120, 120) },
	{ center = Vector3.new(28, 0, -52), color = Color3.fromRGB(120, 220, 120) },
	{ center = Vector3.new(84, 0, -52), color = Color3.fromRGB(255, 200, 80) },
	{ center = Vector3.new(-84, 0, 52), color = Color3.fromRGB(200, 120, 255) },
	{ center = Vector3.new(-28, 0, 52), color = Color3.fromRGB(80, 220, 220) },
	{ center = Vector3.new(28, 0, 52), color = Color3.fromRGB(255, 140, 200) },
	{ center = Vector3.new(84, 0, 52), color = Color3.fromRGB(160, 255, 140) },
}

local Workspace = game:GetService("Workspace")

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.CanCollide = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- World position of a base slot: 4 columns x 2 rows on the plot.
function WorldBuilder.slotPosition(plotIndex: number, slotIndex: number): Vector3
	local plot = WorldBuilder.BASE_PLOTS[plotIndex]
	local col = (slotIndex - 1) % 4
	local row = math.floor((slotIndex - 1) / 4)
	local x = plot.center.X - 7.5 + col * 5
	local z = plot.center.Z - 2.5 + row * 5
	return Vector3.new(x, 1, z)
end

-- A base's front edge (where its lock wall stands and thieves walk in).
function WorldBuilder.baseEntrance(plotIndex: number): Vector3
	local plot = WorldBuilder.BASE_PLOTS[plotIndex]
	local z = plot.center.Z
	if z < 0 then
		return Vector3.new(plot.center.X, 2, plot.center.Z + 9)
	else
		return Vector3.new(plot.center.X, 2, plot.center.Z - 9)
	end
end

local function buildConveyor(parent: Folder)
	local belt = makePart("ConveyorBelt", Vector3.new(180, 1, 8), Vector3.new(0, 0.5, WorldBuilder.CONVEYOR_Z), Color3.fromRGB(60, 60, 70), Enum.Material.Neon)
	belt.Parent = parent
	-- Chevrons on the belt, so the walk direction reads at a glance.
	for i = 0, 17 do
		local stripe = makePart("BeltStripe", Vector3.new(2, 0.2, 6), Vector3.new(-85 + i * 10, 1.1, WorldBuilder.CONVEYOR_Z), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
		stripe.CanCollide = false
		stripe.Parent = parent
	end
	-- Rails on both sides of the belt.
	for _, z in ipairs({ -5, 5 }) do
		local rail = makePart("ConveyorRail", Vector3.new(180, 1, 1), Vector3.new(0, 1.5, WorldBuilder.CONVEYOR_Z + z), Color3.fromRGB(200, 200, 210))
		rail.Parent = parent
	end
	-- A start arch where brainrots step onto the belt, and an end arch where
	-- un-bought ones walk off and despawn.
	for _, x in ipairs({ WorldBuilder.CONVEYOR_START_X, WorldBuilder.CONVEYOR_END_X }) do
		local postA = makePart("ArchPost", Vector3.new(1, 8, 1), Vector3.new(x, 4, -4), Color3.fromRGB(255, 120, 120))
		postA.Parent = parent
		local postB = makePart("ArchPost", Vector3.new(1, 8, 1), Vector3.new(x, 4, 4), Color3.fromRGB(255, 120, 120))
		postB.Parent = parent
		local beam = makePart("ArchBeam", Vector3.new(1, 1, 9), Vector3.new(x, 8.5, 0), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
		beam.Parent = parent
	end
end

-- One base plot: coloured pad, 8 slot markers, a lock wall at the entrance
-- (invisible until the owner locks the base) and a corner flag.
local function buildBasePlot(parent: Folder, plotIndex: number, plot): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Base" .. plotIndex
	folder.Parent = parent

	local pad = makePart("Pad", Vector3.new(24, 2, 18), Vector3.new(plot.center.X, 0, plot.center.Z), plot.color, Enum.Material.Grass)
	pad.Parent = folder
	local trim = makePart("Trim", Vector3.new(24.5, 0.4, 18.5), Vector3.new(plot.center.X, 1.1, plot.center.Z), Color3.fromRGB(255, 255, 255))
	trim.CanCollide = false
	trim.Parent = folder
	for slot = 1, WorldBuilder.SLOTS_PER_BASE do
		local pos = WorldBuilder.slotPosition(plotIndex, slot)
		local marker = makePart("Slot" .. slot, Vector3.new(4, 0.3, 4), Vector3.new(pos.X, 1.15, pos.Z), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		marker.CanCollide = false
		marker.Transparency = 0.6
		marker.Parent = folder
	end
	local entrance = WorldBuilder.baseEntrance(plotIndex)
	local wall = makePart("LockWall", Vector3.new(24, 8, 1), entrance, Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
	wall.CanCollide = false
	wall.Transparency = 1
	wall.Parent = folder
	local flagPole = makePart("FlagPole", Vector3.new(0.6, 10, 0.6), Vector3.new(plot.center.X - 11, 6, plot.center.Z - 8), Color3.fromRGB(230, 230, 230))
	flagPole.Parent = folder
	local flag = makePart("Flag", Vector3.new(4, 2.5, 0.2), Vector3.new(plot.center.X - 9, 10, plot.center.Z - 8), plot.color, Enum.Material.Neon)
	flag.Parent = folder
	return folder
end

local function buildTree(parent: Folder, position: Vector3)
	local trunk = makePart("TreeTrunk", Vector3.new(2, 6, 2), position + Vector3.new(0, 3, 0), Color3.fromRGB(120, 70, 30))
	trunk.Parent = parent
	local leaves = makePart("TreeLeaves", Vector3.new(7, 7, 7), position + Vector3.new(0, 9, 0), Color3.fromRGB(40, 170, 70), Enum.Material.Grass)
	leaves.Shape = Enum.PartType.Ball
	leaves.Parent = parent
end

local function buildStatue(parent: Folder, position: Vector3, bodyColor: Color3, name: string)
	-- A giant of the genre: a blocky brainrot hero on a plinth, for the plaza.
	local plinth = makePart(name .. "Plinth", Vector3.new(10, 2, 10), position + Vector3.new(0, 1, 0), Color3.fromRGB(180, 180, 190))
	plinth.Parent = parent
	local body = makePart(name .. "Body", Vector3.new(6, 7, 4), position + Vector3.new(0, 5.5, 0), bodyColor)
	body.Parent = parent
	local head = makePart(name .. "Head", Vector3.new(4, 4, 4), position + Vector3.new(0, 11, 0), bodyColor)
	head.Parent = parent
	local eyeA = makePart(name .. "EyeA", Vector3.new(0.8, 1.2, 0.5), position + Vector3.new(-1, 11.5, 2.1), Color3.fromRGB(255, 255, 255))
	eyeA.Parent = parent
	local eyeB = makePart(name .. "EyeB", Vector3.new(0.8, 1.2, 0.5), position + Vector3.new(1, 11.5, 2.1), Color3.fromRGB(255, 255, 255))
	eyeB.Parent = parent
end

-- Builds the world and returns the folders other modules need:
--   bases: per-plot folders (each holds its Pad and LockWall)
--   hill: the tsunami-safe platform's top part
--   tsunamiWall: created later by EventService, parented here
function WorldBuilder.build(): { bases: { Folder }, hillTop: Part }
	local world = Instance.new("Folder")
	world.Name = "BrainrotWorld"
	world.Parent = Workspace

	local ground = makePart("Ground", Vector3.new(256, 2, 256), Vector3.new(0, -1, 0), Color3.fromRGB(90, 180, 90), Enum.Material.Grass)
	ground.Parent = world

	buildConveyor(world)

	local bases = {}
	for i, plot in ipairs(WorldBuilder.BASE_PLOTS) do
		bases[i] = buildBasePlot(world, i, plot)
	end

	-- Tsunami-safe hill at the far east end: high ground, with steps.
	local hillBase = makePart("HillBase", Vector3.new(24, 12, 24), Vector3.new(104, 6, 0), Color3.fromRGB(140, 110, 70))
	hillBase.Parent = world
	local hillTop = makePart("HillTop", Vector3.new(20, 1, 20), Vector3.new(104, 12.5, 0), Color3.fromRGB(120, 200, 90), Enum.Material.Grass)
	hillTop.Parent = world
	local sign = makePart("HillSign", Vector3.new(6, 3, 0.5), Vector3.new(104, 15, 10), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
	sign.Parent = world

	-- Plaza statues between the base rows: DJ Pickle and Captain Croissant.
	buildStatue(world, Vector3.new(-40, 0, -18), Color3.fromRGB(80, 200, 60), "Pickle")
	buildStatue(world, Vector3.new(40, 0, 18), Color3.fromRGB(230, 180, 60), "Croissant")

	-- Trees and lamps around the edges, kept clear of bases and belt.
	for _, pos in ipairs({
		Vector3.new(-110, 0, -30), Vector3.new(-110, 0, 30),
		Vector3.new(110, 0, -30), Vector3.new(110, 0, 30),
		Vector3.new(-60, 0, -80), Vector3.new(60, 0, 80),
		Vector3.new(0, 0, -80), Vector3.new(0, 0, 80),
	}) do
		buildTree(world, pos)
	end
	for _, x in ipairs({ -60, -20, 20, 60 }) do
		for _, z in ipairs({ -9, 9 }) do
			local pole = makePart("LampPole", Vector3.new(0.6, 7, 0.6), Vector3.new(x, 3.5, z), Color3.fromRGB(80, 80, 90))
			pole.Parent = world
			local lamp = makePart("Lamp", Vector3.new(2, 1, 2), Vector3.new(x, 7.5, z), Color3.fromRGB(255, 240, 150), Enum.Material.Neon)
			lamp.Parent = world
		end
	end

	-- Spawn pad at the far west end, next to the conveyor start.
	local spawnPad = makePart("SpawnPad", Vector3.new(16, 1, 16), Vector3.new(-104, 0.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	spawnPad.CanCollide = false
	spawnPad.Parent = world

	return { bases = bases, hillTop = hillTop }
end

return WorldBuilder
