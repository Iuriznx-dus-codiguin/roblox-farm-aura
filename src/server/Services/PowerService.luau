--!strict
-- Poderes na base (GDD: "Servidor, base e invasão" e "Poderes").
-- Cada poder desbloqueado vira uma caixa no meio do lote. Outros jogadores se aproximam e apertam "Roubar":
-- o dono perde o poder e o invasor ganha uma cópia no nível 1, guardada na base dele.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AuraMath = require(Shared.AuraMath)
local Economy = require(Shared.Config.Economy)
local Powers = require(Shared.Config.Powers)
local Remotes = require(Shared.Remotes)

local AuraService = require(script.Parent.AuraService)
local DataService = require(script.Parent.DataService)
local GateService = require(script.Parent.GateService)
local PlotService = require(script.Parent.PlotService)

type Profile = DataService.Profile

local buyPower = Remotes.event("BuyPower")
local notify = Remotes.event("Notify")

local GRID_COLUMNS = 4
local GRID_SPACING = 9
local BOX_SIZE = Vector3.new(5, 5, 5)

local PowerService = {}

local function boxesFolder(plot: Model): Folder
	local folder = plot:FindFirstChild("PowerBoxes")
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "PowerBoxes"
	created.Parent = plot
	return created
end

-- Ordem fixa das caixas: a mesma da tabela de poderes, para cada poder ter sempre o mesmo lugar.
local function slotFor(powerId: string): number
	for index, power in Powers.list do
		if power.id == powerId then
			return index
		end
	end
	return #Powers.list
end

local function slotCFrame(plot: Model, slot: number): CFrame?
	local area = plot:FindFirstChild("BoxArea") :: BasePart?
	if not area then
		return nil
	end
	local rows = math.ceil(#Powers.list / GRID_COLUMNS)
	local column = (slot - 1) % GRID_COLUMNS
	local row = (slot - 1) // GRID_COLUMNS
	local x = (column - (GRID_COLUMNS - 1) / 2) * GRID_SPACING
	local z = (row - (rows - 1) / 2) * GRID_SPACING
	return area.CFrame * CFrame.new(x, BOX_SIZE.Y / 2, z)
end

local function makeBox(plot: Model, power: Powers.Power): Part?
	local cframe = slotCFrame(plot, slotFor(power.id))
	if not cframe then
		return nil
	end
	local color = Powers.rarityColors[power.rarity]

	local box = Instance.new("Part")
	box.Name = power.id
	box.Anchored = true
	box.Size = BOX_SIZE
	box.CFrame = cframe
	box.Color = color
	box.Material = Enum.Material.Glass
	box.Transparency = 0.3
	box:SetAttribute("PowerId", power.id)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = power.name
	label.Parent = gui
	gui.Parent = box

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Roubar"
	prompt.ObjectText = power.name
	prompt.HoldDuration = Economy.Steal.HoldSeconds
	prompt.MaxActivationDistance = Economy.Steal.MaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = box

	box.Parent = boxesFolder(plot)
	return box
end

local function addBox(plot: Model, powerId: string)
	local power = Powers.byId[powerId]
	local folder = boxesFolder(plot)
	if not power or folder:FindFirstChild(powerId) then
		return
	end
	local box = makeBox(plot, power)
	if box then
		local prompt = box:FindFirstChild("StealPrompt") :: ProximityPrompt
		prompt.Triggered:Connect(function(thief)
			PowerService.trySteal(thief, plot, powerId)
		end)
	end
end

local function removeBox(plot: Model, powerId: string)
	local folder = plot:FindFirstChild("PowerBoxes")
	local box = folder and folder:FindFirstChild(powerId)
	if box then
		box:Destroy()
	end
end

local function renderAll(player: Player, profile: Profile)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	for powerId in profile.powers do
		addBox(plot, powerId)
	end
end

local function onBuy(player: Player, powerId: unknown)
	if type(powerId) ~= "string" then
		return
	end
	local power = Powers.byId[powerId]
	local profile = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not power or not profile or not plot then
		return
	end
	if profile.powers[powerId] then
		return
	end
	if AuraMath.getBand(profile.peakAura).index < power.band then
		notify:FireClient(player, `{power.name} precisa da faixa {power.band}.`)
		return
	end
	if profile.aura < power.price then
		return
	end
	profile.aura -= power.price
	profile.powers[powerId] = 1
	addBox(plot, powerId)
	AuraService.pushState(player)
	DataService.saveNow(player)
end

function PowerService.trySteal(thief: Player, plot: Model, powerId: string)
	local owner = PlotService.getOwner(plot)
	local power = Powers.byId[powerId]
	if not owner or owner == thief or not power then
		return
	end
	local thiefProfile = DataService.get(thief)
	local ownerProfile = DataService.get(owner)
	if not thiefProfile or not ownerProfile or not PlotService.getPlot(thief) then
		return
	end
	if not ownerProfile.powers[powerId] then
		return
	end

	-- Regras de segurança do GDD, na ordem em que o jogador entende o motivo.
	if GateService.isClosed(plot) then
		notify:FireClient(thief, `O lote de {owner.DisplayName} está trancado.`)
		return
	end
	if AuraService.hasShield(thiefProfile) then
		notify:FireClient(thief, "Você ainda está com escudo de iniciante e não pode roubar.")
		return
	end
	if AuraService.hasShield(ownerProfile) then
		notify:FireClient(thief, `{owner.DisplayName} está com escudo de iniciante.`)
		return
	end
	if os.time() - ownerProfile.lastPowerLostAt < Economy.Steal.OwnerCooldownSeconds then
		notify:FireClient(thief, `{owner.DisplayName} perdeu um poder há pouco. Tente mais tarde.`)
		return
	end
	if thiefProfile.powers[powerId] then
		notify:FireClient(thief, `Você já tem {power.name}.`)
		return
	end

	ownerProfile.powers[powerId] = nil
	local equippedIndex = table.find(ownerProfile.equipped, powerId)
	if equippedIndex then
		table.remove(ownerProfile.equipped, equippedIndex)
	end
	ownerProfile.lastPowerLostAt = os.time()
	removeBox(plot, powerId)

	thiefProfile.powers[powerId] = 1
	local thiefPlot = PlotService.getPlot(thief)
	if thiefPlot then
		addBox(thiefPlot, powerId)
	end

	notify:FireClient(thief, `Você roubou {power.name}!`)
	notify:FireClient(owner, `{thief.DisplayName} roubou seu {power.name}!`)
	AuraService.pushState(thief)
	AuraService.pushState(owner)
	DataService.saveNow(thief)
	DataService.saveNow(owner)
end

function PowerService.start()
	buyPower.OnServerEvent:Connect(onBuy)
	DataService.onLoaded(renderAll)
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			renderAll(player, profile)
		end
	end
end

return PowerService
