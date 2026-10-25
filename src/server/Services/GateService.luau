--!strict
-- Portão do lote (GDD: "o dono fecha o lote por 60 segundos, com recarga de 3 minutos").
-- Com o portão fechado ninguém rouba, quem está dentro é posto para fora e quem encosta no laser é empurrado.
-- Os horários ficam em atributos (GateUntil no lote, GateReadyAt no jogador) para o HUD ler sem depender daqui.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)

local PlotService = require(script.Parent.PlotService)

local closeGate = Remotes.event("CloseGate")

local GateService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

function GateService.isClosed(plot: Model): boolean
	local closedUntil = plot:GetAttribute("GateUntil")
	return type(closedUntil) == "number" and closedUntil > now()
end

local function setWalls(plot: Model, closed: boolean)
	local gate = plot:FindFirstChild("Gate")
	if not gate then
		return
	end
	for _, wall in gate:GetChildren() do
		if wall:IsA("BasePart") then
			wall.Transparency = if closed then 0.35 else 1
			wall.CanTouch = closed
		end
	end
end

-- Leva o personagem para fora, na frente do lote (o lado virado para a praça).
local function pushOut(plot: Model, character: Model)
	local base = plot:FindFirstChild("Base") :: BasePart?
	if base then
		character:PivotTo(base.CFrame * CFrame.new(0, 4, -(base.Size.Z / 2 + 8)))
	end
end

local function isInside(plot: Model, position: Vector3): boolean
	local base = plot:FindFirstChild("Base") :: BasePart?
	if not base then
		return false
	end
	local localPos = base.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) <= base.Size.X / 2
		and math.abs(localPos.Z) <= base.Size.Z / 2
		and localPos.Y < 40
end

local function ejectIntruders(plot: Model, owner: Player)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if player ~= owner and character and root and isInside(plot, root.Position) then
			pushOut(plot, character)
		end
	end
end

local function onCloseGate(player: Player)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local readyAt = player:GetAttribute("GateReadyAt")
	if type(readyAt) == "number" and readyAt > now() then
		return
	end

	local closedUntil = now() + Economy.Gate.DurationSeconds
	plot:SetAttribute("GateUntil", closedUntil)
	player:SetAttribute("GateReadyAt", now() + Economy.Gate.CooldownSeconds)
	setWalls(plot, true)
	ejectIntruders(plot, player)

	task.delay(Economy.Gate.DurationSeconds, function()
		-- Só abre se ninguém fechou de novo nesse meio tempo (ex.: o lote mudou de dono).
		if plot:GetAttribute("GateUntil") == closedUntil then
			plot:SetAttribute("GateUntil", nil)
			setWalls(plot, false)
		end
	end)
end

local function bindLasers(plot: Model)
	local gate = plot:FindFirstChild("Gate")
	if not gate then
		return
	end
	for _, wall in gate:GetChildren() do
		if not wall:IsA("BasePart") then
			continue
		end
		wall.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if
				character
				and player
				and player ~= PlotService.getOwner(plot)
				and GateService.isClosed(plot)
			then
				pushOut(plot, character)
			end
		end)
	end
end

function GateService.start()
	for _, plot in PlotService.getPlots() do
		bindLasers(plot)
		-- Lote liberado abre o portão, para o próximo dono não herdar o fechamento.
		plot:GetAttributeChangedSignal("OwnerId"):Connect(function()
			plot:SetAttribute("GateUntil", nil)
			setWalls(plot, false)
		end)
	end
	closeGate.OnServerEvent:Connect(onCloseGate)
end

return GateService
