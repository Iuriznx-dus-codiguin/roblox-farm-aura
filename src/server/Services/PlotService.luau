--!strict
-- Lotes do servidor (GDD: "Servidor, base e invasão"): 12 lotes em círculo ao redor da praça central.
-- Se o place já tiver Workspace.Plots montado no Studio, usa esses; senão gera os lotes com o PlotBuilder.

local Players = game:GetService("Players")

local PlotBuilder = require(script.Parent.Parent.PlotBuilder)

local PlotService = {}

local plotsFolder: Folder
local owners: { [Player]: Model } = {}

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
		plotsFolder = PlotBuilder.build(workspace)
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
