--!strict
-- Dançar no próprio lote (GDD: "Danças e conquistas"): enquanto o personagem dança, a geração ganha o bônus
-- da dança ativa; andar, sair do lote, entrar na arena ou renascer para a dança. O servidor marca o
-- atributo Dancing no jogador (o AuraService lê o bônus dele) e o cliente toca a animação.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local Remotes = require(Shared.Remotes)

local ArenaService = require(script.Parent.ArenaService)
local AuraService = require(script.Parent.AuraService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local selectDance = Remotes.event("SelectDance")
local danceRemote = Remotes.event("Dance")
local notify = Remotes.event("Notify")

local CHECK_SECONDS = 0.25

local DanceService = {}

-- Onde o personagem estava quando começou a dançar.
local startedAt: { [Player]: Vector3 } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- O ponto está em cima da base do lote do jogador?
local function onOwnPlot(player: Player, position: Vector3): boolean
	local plot = PlotService.getPlot(player)
	local base = plot and plot:FindFirstChild("Base") :: BasePart?
	if not base then
		return false
	end
	local offset = base.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) <= base.Size.X / 2 and math.abs(offset.Z) <= base.Size.Z / 2
end

function DanceService.stop(player: Player)
	startedAt[player] = nil
	if player:GetAttribute("Dancing") ~= nil then
		player:SetAttribute("Dancing", nil)
		AuraService.pushState(player)
	end
end

local function start(player: Player)
	local profile = DataService.get(player)
	local root = rootOf(player)
	local danceId = profile and profile.activeDance
	if not profile or not root or not danceId or not table.find(profile.dances, danceId) then
		return
	end
	if ArenaService.isFighting(player) or not onOwnPlot(player, root.Position) then
		notify:FireClient(player, "Dance no seu lote para a geração subir.")
		return
	end
	startedAt[player] = root.Position
	player:SetAttribute("Dancing", danceId)
	AuraService.pushState(player)
end

local function onSelect(player: Player, value: unknown)
	if type(value) ~= "string" then
		return
	end
	local danceId = value :: string
	local profile = DataService.get(player)
	if not profile or not table.find(profile.dances, danceId) then
		return
	end
	profile.activeDance = danceId
	-- Trocar de dança no meio já troca a animação e o bônus.
	if player:GetAttribute("Dancing") ~= nil then
		player:SetAttribute("Dancing", danceId)
	end
	AuraService.pushState(player)
end

local function onDance(player: Player, wants: unknown)
	if wants == true then
		start(player)
	else
		DanceService.stop(player)
	end
end

function DanceService.start()
	selectDance.OnServerEvent:Connect(onSelect)
	danceRemote.OnServerEvent:Connect(onDance)
	Players.PlayerRemoving:Connect(function(player)
		startedAt[player] = nil
	end)

	-- Andar, ser teleportado ou renascer tira o personagem do lugar e para a dança.
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			for player, origin in startedAt do
				local root = rootOf(player)
				if not root or (root.Position - origin).Magnitude > Dances.stopDistance then
					DanceService.stop(player)
				end
			end
		end
	end)
end

return DanceService
