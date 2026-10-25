--!strict
-- Lotes do servidor (GDD: "Servidor, base e invasão"): 12 lotes em círculo ao redor da praça central.
-- Se o place já tiver Workspace.Plots montado no Studio, usa esses; senão gera lotes simples de protótipo.

local Players = game:GetService("Players")

local PLOT_COUNT = 12
local RING_RADIUS = 190
local PLOT_SIZE = 80

local PlotService = {}

local plotsFolder: Folder
local owners: { [Player]: Model } = {}

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

local function buildPlaza()
	local plaza = part({
		Name = "Plaza",
		Size = Vector3.new(120, 1, 120),
		CFrame = CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(180, 180, 190),
		Material = Enum.Material.Slate,
	})
	plaza.Parent = workspace
end

local function signLabel(plot: Model): TextLabel?
	local sign = plot:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("OwnerGui")
	return gui and gui:FindFirstChild("Label") :: TextLabel?
end

function PlotService.getPlots(): { Model }
	local list = {}
	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(list, child)
		end
	end
	return list
end

function PlotService.getPlot(player: Player): Model?
	return owners[player]
end

function PlotService.getOwner(plot: Model): Player?
	local ownerId = plot:GetAttribute("OwnerId")
	if type(ownerId) ~= "number" or ownerId == 0 then
		return nil
	end
	return Players:GetPlayerByUserId(ownerId)
end

function PlotService.assign(player: Player): Model?
	if owners[player] then
		return owners[player]
	end
	for _, plot in PlotService.getPlots() do
		if plot:GetAttribute("OwnerId") == 0 then
			plot:SetAttribute("OwnerId", player.UserId)
			owners[player] = plot
			local label = signLabel(plot)
			if label then
				label.Text = `Lote de {player.DisplayName}`
			end
			return plot
		end
	end
	warn("[PlotService] sem lote livre para", player.Name)
	return nil
end

function PlotService.release(player: Player)
	local plot = owners[player]
	if not plot then
		return
	end
	owners[player] = nil
	plot:SetAttribute("OwnerId", 0)
	-- Os poderes somem com o dono (GDD: lotes offline nunca são invadidos).
	local boxes = plot:FindFirstChild("PowerBoxes")
	if boxes then
		boxes:Destroy()
	end
	local label = signLabel(plot)
	if label then
		label.Text = "Lote livre"
	end
end

local function teleportHome(player: Player, character: Model)
	local plot = owners[player]
	local spawn = plot and plot:FindFirstChild("Spawn") :: BasePart?
	if not spawn then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

function PlotService.start()
	local existing = workspace:FindFirstChild("Plots")
	if existing and existing:IsA("Folder") then
		plotsFolder = existing
	else
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "Plots"
		for i = 1, PLOT_COUNT do
			buildPlot(i).Parent = plotsFolder
		end
		plotsFolder.Parent = workspace
		buildPlaza()
	end

	local function onPlayerAdded(player: Player)
		PlotService.assign(player)
		player.CharacterAdded:Connect(function(character)
			teleportHome(player, character)
		end)
		if player.Character then
			teleportHome(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(PlotService.release)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlotService
