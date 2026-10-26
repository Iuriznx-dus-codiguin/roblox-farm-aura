--!strict
-- Rebirth (GDD: "Rebirth"): o primeiro pede 1.000.000 de aura e cada um seguinte pede o triplo.
-- Zera a aura (carregada, cofre e coletor) e o pico da faixa; mantém o nível do gerador, os poderes
-- guardados na base (que voltam a ser usáveis conforme a faixa sobe) e as danças; dá +25% de geração.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AuraMath = require(Shared.AuraMath)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local ArenaService = require(script.Parent.ArenaService)
local AuraService = require(script.Parent.AuraService)
local DataService = require(script.Parent.DataService)

local rebirthRemote = Remotes.event("Rebirth")
local notify = Remotes.event("Notify")

local RebirthService = {}

local function onRebirth(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if ArenaService.isFighting(player) then
		notify:FireClient(player, "Faça o rebirth fora da arena.")
		return
	end
	local cost = AuraMath.rebirthCost(profile.rebirths)
	if profile.aura < cost then
		notify:FireClient(player, `O rebirth pede {Format.short(cost)} de aura carregada.`)
		return
	end

	profile.aura = 0
	profile.vaultAura = 0
	profile.pendingAura = 0
	profile.peakAura = 0
	-- Os poderes saem do equipado, mas continuam nas caixas da base (GDD: "Poderes e faixas").
	table.clear(profile.equipped)
	profile.rebirths += 1

	local bonus = math.round(profile.rebirths * Economy.Rebirth.BonusPerRebirth * 100)
	notify:FireClient(player, `Rebirth {profile.rebirths}! Sua geração agora tem +{bonus}% para sempre.`)
	AuraService.pushState(player)
	DataService.saveNow(player)
end

function RebirthService.start()
	rebirthRemote.OnServerEvent:Connect(onRebirth)
end

return RebirthService
