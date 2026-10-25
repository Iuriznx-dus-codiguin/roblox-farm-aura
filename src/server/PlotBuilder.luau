--!strict
-- Monta o mapa de protótipo: 12 lotes em círculo e a praça central. Os nomes das peças são o contrato com
-- PlotService, AuraService, PowerService e GateService.
--
-- O servidor chama build() quando o place não tem Workspace.Plots. Para o mapa aparecer no modo Edit (e poder
-- ser decorado e salvo no place), rode uma vez na Command Bar do Studio:
--   require(game.ServerScriptService.Server.PlotBuilder).build(workspace)

local PLOT_COUNT = 12
local RING_RADIUS = 190
local PLOT_SIZE = 80

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

local function billboard(parent: BasePart, name: string, offsetY: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = ""
	label.Parent = gui
	gui.Parent = parent
	return label
end

-- Monta um lote de protótipo. Os nomes das peças são o contrato com AuraService.
local function buildPlot(index: number): Model
	local angle = (index - 1) / PLOT_COUNT * math.pi * 2
	local center = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
	-- Frente do lote virada para a praça.
	local frame = CFrame.lookAt(center, Vector3.new(0, 0, 0))

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("OwnerId", 0)

	local base = part({
		Name = "Base",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = frame * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(70, 150, 70),
		Material = Enum.Material.Grass,
	})
	base.Parent = model
	model.PrimaryPart = base

	local generator = part({
		Name = "Generator",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 8, 8),
		CFrame = frame * CFrame.new(0, 4, 24) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 90, 255),
		Material = Enum.Material.Neon,
	})
	generator.Parent = model

	local collector = part({
		Name = "Collector",
		Size = Vector3.new(10, 0.4, 10),
		CFrame = frame * CFrame.new(0, 1.2, 14),
		Color = Color3.fromRGB(120, 230, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	collector.Parent = model
	billboard(collector, "PendingGui", 5)

	local vault = part({
		Name = "Vault",
		Size = Vector3.new(8, 0.4, 8),
		CFrame = frame * CFrame.new(28, 1.2, 26),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	vault.Parent = model
	billboard(vault, "VaultGui", 5)

	-- Centro da grade das caixas de poder (GDD: caixas no meio do lote). Só marca a posição.
	local boxArea = part({
		Name = "BoxArea",
		Size = Vector3.new(1, 1, 1),
		CFrame = frame * CFrame.new(0, 1, -8),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	boxArea.Parent = model

	local spawn = part({
		Name = "Spawn",
		Size = Vector3.new(6, 1, 6),
		CFrame = frame * CFrame.new(0, 1.1, -32),
		Transparency = 1,
		CanCollide = false,
	})
	spawn.Parent = model

	-- Paredes de laser do portão (GDD: o dono fecha o lote por 60 s). Ficam invisíveis até o portão fechar.
	local gate = Instance.new("Folder")
	gate.Name = "Gate"
	local half = PLOT_SIZE / 2
	local walls = {
		{ offset = Vector3.new(0, 6, -half), size = Vector3.new(PLOT_SIZE, 12, 1) },
		{ offset = Vector3.new(0, 6, half), size = Vector3.new(PLOT_SIZE, 12, 1) },
		{ offset = Vector3.new(-half, 6, 0), size = Vector3.new(1, 12, PLOT_SIZE) },
		{ offset = Vector3.new(half, 6, 0), size = Vector3.new(1, 12, PLOT_SIZE) },
	}
	for i, wall in walls do
		part({
			Name = "Laser" .. i,
			Size = wall.size,
			CFrame = frame * CFrame.new(wall.offset),
			Color = Color3.fromRGB(255, 40, 60),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		}).Parent =
			gate
	end
	gate.Parent = model

	local sign = part({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		CFrame = frame * CFrame.new(0, 14, -PLOT_SIZE / 2 + 2),
		Transparency = 1,
		CanCollide = false,
	})
	sign.Parent = model
	billboard(sign, "OwnerGui", 0).Text = "Lote livre"

	return model
end

local function buildPlaza(parent: Instance)
	local plaza = part({
		Name = "Plaza",
		Size = Vector3.new(120, 1, 120),
		CFrame = CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(180, 180, 190),
		Material = Enum.Material.Slate,
	})
	plaza.Parent = parent
end

local PlotBuilder = {}

-- Cria Workspace.Plots e a praça dentro de `parent` e devolve a pasta dos lotes.
function PlotBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	for i = 1, PLOT_COUNT do
		buildPlot(i).Parent = folder
	end
	folder.Parent = parent
	buildPlaza(parent)
	return folder
end

return PlotBuilder
