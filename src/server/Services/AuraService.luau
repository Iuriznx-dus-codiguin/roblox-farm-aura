--!strict
-- Gerador, coletor, cofre e upgrade do gerador. Toda conta de aura acontece aqui, no servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AuraMath = require(Shared.AuraMath)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

type Profile = DataService.Profile

local stateChanged = Remotes.event("StateChanged")
local upgradeGenerator = Remotes.event("UpgradeGenerator")
local notify = Remotes.event("Notify")

local AuraService = {}

local lastTouch: { [Player]: { [string]: number } } = {}

-- Passes e danças ainda não existem; entram aqui quando forem feitos.
local function bonusesFor(_player: Player): { number }
	return {}
end

local function hasVaultPass(_player: Player): boolean
	return false
end

local function rateFor(player: Player, profile: Profile): number
	return AuraMath.ratePerSecond(profile.generatorLevel, profile.rebirths, bonusesFor(player))
end

local function updatePeak(profile: Profile)
	profile.peakAura = math.max(profile.peakAura, profile.aura + profile.vaultAura)
end

-- Escudo de iniciante (GDD: primeiros 15 min de jogo). No Studio, o atributo TesteSemEscudo = true no Workspace
-- desliga o escudo para dar para testar o roubo e a derrota na arena sem esperar. Fora do Studio é ignorado.
function AuraService.hasShield(profile: Profile): boolean
	if RunService:IsStudio() and workspace:GetAttribute("TesteSemEscudo") == true then
		return false
	end
	return AuraMath.hasBeginnerShield(profile.minutesPlayed)
end

-- Soma aura carregada vinda de fora do gerador (ex.: roubo na arena) e atualiza o pico da faixa.
function AuraService.addAura(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.aura += amount
	updatePeak(profile)
	AuraService.pushState(player)
end

local function setBillboard(plot: Model, partName: string, guiName: string, text: string)
	local holder = plot:FindFirstChild(partName)
	local gui = holder and holder:FindFirstChild(guiName)
	local label = gui and gui:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
end

local function refreshPlot(player: Player, profile: Profile)
	local plot = PlotService.getPlot(player)
	if plot then
		setBillboard(plot, "Collector", "PendingGui", "+" .. Format.short(profile.pendingAura))
		setBillboard(plot, "Vault", "VaultGui", "Cofre: " .. Format.short(profile.vaultAura))
	end
end

function AuraService.pushState(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local band = AuraMath.getBand(profile.peakAura)
	local nextBand = AuraMath.getNextBand(profile.peakAura)
	local plot = PlotService.getPlot(player)
	stateChanged:FireClient(player, {
		aura = profile.aura,
		vaultAura = profile.vaultAura,
		pendingAura = profile.pendingAura,
		peakAura = profile.peakAura,
		bandIndex = band.index,
		nextBandAura = if nextBand then nextBand.minAura else nil,
		ratePerSecond = rateFor(player, profile),
		generatorLevel = profile.generatorLevel,
		upgradeCost = AuraMath.upgradeCost(profile.generatorLevel),
		powers = profile.powers,
		equipped = profile.equipped,
		hasShield = AuraService.hasShield(profile),
		-- Horários do portão em workspace:GetServerTimeNow() (ver GateService).
		gateUntil = plot and plot:GetAttribute("GateUntil") or 0,
		gateReadyAt = player:GetAttribute("GateReadyAt") or 0,
	})
	refreshPlot(player, profile)
end

local function collect(player: Player, profile: Profile)
	local amount = math.floor(profile.pendingAura)
	if amount <= 0 then
		return
	end
	local carried, toVault = AuraMath.splitCollect(amount, hasVaultPass(player))
	profile.pendingAura -= amount
	profile.aura += carried
	profile.vaultAura += toVault
	updatePeak(profile)
	AuraService.pushState(player)
end

local function collectVault(player: Player, profile: Profile)
	if profile.vaultAura <= 0 then
		return
	end
	profile.aura += profile.vaultAura
	profile.vaultAura = 0
	AuraService.pushState(player)
end

local function onUpgrade(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local cost = AuraMath.upgradeCost(profile.generatorLevel)
	if not cost or profile.aura < cost then
		return
	end
	profile.aura -= cost
	profile.generatorLevel += 1
	AuraService.pushState(player)
	DataService.saveNow(player)
end

-- Toque do dono no coletor ou no cofre. Outros jogadores pisando não fazem nada.
local function bindPad(plot: Model, padName: string, handler: (Player, Profile) -> ())
	local pad = plot:FindFirstChild(padName) :: BasePart?
	if not pad then
		warn(`[AuraService] {plot.Name} sem {padName}`)
		return
	end
	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or PlotService.getPlot(player) ~= plot then
			return
		end
		local now = os.clock()
		local touches = lastTouch[player]
		if not touches then
			touches = {}
			lastTouch[player] = touches
		end
		if now - (touches[padName] or 0) < Economy.TouchCooldown then
			return
		end
		touches[padName] = now
		local profile = DataService.get(player)
		if profile then
			handler(player, profile)
		end
	end)
end

local function onProfileLoaded(player: Player, profile: Profile)
	if profile.lastLogout > 0 then
		local gain = AuraMath.offlineGain(rateFor(player, profile), os.time() - profile.lastLogout)
		if gain > 0 then
			profile.pendingAura += gain
			notify:FireClient(
				player,
				`Seu gerador juntou {Format.short(gain)} de aura enquanto você estava fora!`
			)
		end
	end
	AuraService.pushState(player)
end

function AuraService.start()
	for _, plot in PlotService.getPlots() do
		bindPad(plot, "Collector", collect)
		bindPad(plot, "Vault", collectVault)
	end

	upgradeGenerator.OnServerEvent:Connect(onUpgrade)
	DataService.onLoaded(onProfileLoaded)

	-- Teste no Studio: `jogador:SetAttribute("TesteDarAura", 2e6)` na Command Bar (contexto Server) dá aura
	-- pelo caminho real. O require da Command Bar cria outra cópia dos módulos, então chamar addAura por lá
	-- não chega ao perfil do jogo. Fora do Studio o atributo é ignorado.
	if RunService:IsStudio() then
		local function watchTestAura(player: Player)
			player:GetAttributeChangedSignal("TesteDarAura"):Connect(function()
				local amount = player:GetAttribute("TesteDarAura")
				if type(amount) == "number" and amount > 0 then
					player:SetAttribute("TesteDarAura", nil)
					AuraService.addAura(player, amount)
				end
			end)
		end
		Players.PlayerAdded:Connect(watchTestAura)
		for _, player in Players:GetPlayers() do
			watchTestAura(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTouch[player] = nil
	end)

	-- Geração: 1 tick por segundo direto no coletor do lote.
	task.spawn(function()
		local elapsedMinutes = 0
		while true do
			task.wait(1)
			elapsedMinutes += 1 / 60
			local addMinute = elapsedMinutes >= 1
			if addMinute then
				elapsedMinutes -= 1
			end
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile and PlotService.getPlot(player) then
					profile.pendingAura += rateFor(player, profile)
					if addMinute then
						profile.minutesPlayed += 1
					end
					AuraService.pushState(player)
				end
			end
		end
	end)
end

return AuraService
