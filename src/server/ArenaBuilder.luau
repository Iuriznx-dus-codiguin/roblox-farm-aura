--!strict
-- Monta a arena de protótipo (longe dos lotes, no mesmo servidor) e o portal na praça.
-- Os nomes das peças são o contrato com ArenaService.
--
-- O servidor chama build() quando o place não tem Workspace.Arena. Para ver no modo Edit, rode na Command Bar:
--   require(game.ServerScriptService.Server.ArenaBuilder).build(workspace)

local ARENA_CENTER = Vector3.new(0, 0, 1000)
local ARENA_SIZE = 140
local WALL_HEIGHT = 24
local SPAWN_RADIUS = 45
local SPAWN_COUNT = 8

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function buildArena(parent: Instance)
	local arena = Instance.new("Model")
	arena.Name = "Arena"

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(ARENA_SIZE, 2, ARENA_SIZE),
		CFrame = CFrame.new(ARENA_CENTER + Vector3.new(0, -1, 0)),
		Color = Color3.fromRGB(205, 180, 120),
		Material = Enum.Material.Sandstone,
	})
	floor.Parent = arena
	arena.PrimaryPart = floor

	local half = ARENA_SIZE / 2
	local walls = {
		{ Vector3.new(0, WALL_HEIGHT / 2, -half), Vector3.new(ARENA_SIZE, WALL_HEIGHT, 4) },
		{ Vector3.new(0, WALL_HEIGHT / 2, half), Vector3.new(ARENA_SIZE, WALL_HEIGHT, 4) },
		{ Vector3.new(-half, WALL_HEIGHT / 2, 0), Vector3.new(4, WALL_HEIGHT, ARENA_SIZE) },
		{ Vector3.new(half, WALL_HEIGHT / 2, 0), Vector3.new(4, WALL_HEIGHT, ARENA_SIZE) },
	}
	for i, wall in walls do
		part({
			Name = "Wall" .. i,
			Size = wall[2],
			CFrame = CFrame.new(ARENA_CENTER + wall[1]),
			Color = Color3.fromRGB(90, 85, 110),
			Material = Enum.Material.Rock,
		}).Parent =
			arena
	end

	-- Pontos de nascimento em círculo, virados para o centro.
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i = 1, SPAWN_COUNT do
		local angle = (i - 1) / SPAWN_COUNT * math.pi * 2
		local position = ARENA_CENTER
			+ Vector3.new(math.cos(angle) * SPAWN_RADIUS, 3, math.sin(angle) * SPAWN_RADIUS)
		part({
			Name = "Spawn" .. i,
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.lookAt(position, ARENA_CENTER + Vector3.new(0, 3, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		}).Parent =
			spawns
	end
	spawns.Parent = arena

	arena.Parent = parent
end

local function buildPortal(parent: Instance)
	local portal = part({
		Name = "ArenaPortal",
		Size = Vector3.new(12, 14, 1),
		CFrame = CFrame.new(0, 8, -35),
		Color = Color3.fromRGB(170, 60, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
	})

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 50)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "ARENA"
	label.Parent = gui
	gui.Parent = portal

	portal.Parent = parent
end

local ArenaBuilder = {}

-- Cria Workspace.Arena e Workspace.ArenaPortal dentro de `parent`.
function ArenaBuilder.build(parent: Instance)
	buildArena(parent)
	buildPortal(parent)
end

return ArenaBuilder
