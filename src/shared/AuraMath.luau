--!strict
-- Fórmulas puras da economia. Sem estado e sem serviços do Roblox, para poder rodar no cliente e no servidor.

local Bands = require(script.Parent.Config.Bands)
local Economy = require(script.Parent.Config.Economy)

local AuraMath = {}

function AuraMath.getBand(peakAura: number): Bands.Band
	local current = Bands[1]
	for _, band in Bands do
		if peakAura >= band.minAura then
			current = band
		end
	end
	return current
end

function AuraMath.getNextBand(peakAura: number): Bands.Band?
	local band = AuraMath.getBand(peakAura)
	return Bands[band.index + 1]
end

function AuraMath.generatorRate(level: number): number
	local g = Economy.Generator
	return g.BaseRate * g.RateGrowth ^ (level - 1)
end

-- Custo para subir do `level` atual para o próximo, ou nil no nível máximo.
function AuraMath.upgradeCost(level: number): number?
	local g = Economy.Generator
	if level >= g.MaxLevel then
		return nil
	end
	return math.round(g.BaseCost * g.CostGrowth ^ (level - 1))
end

-- Multiplicador somado (GDD: "Multiplicadores somam entre si").
function AuraMath.multiplier(rebirths: number, bonuses: { number }?): number
	local total = 1 + rebirths * Economy.Rebirth.BonusPerRebirth
	if bonuses then
		for _, bonus in bonuses do
			total += bonus
		end
	end
	return total
end

function AuraMath.ratePerSecond(level: number, rebirths: number, bonuses: { number }?): number
	return AuraMath.generatorRate(level) * AuraMath.multiplier(rebirths, bonuses)
end

function AuraMath.offlineGain(ratePerSecond: number, secondsAway: number): number
	local o = Economy.Offline
	local seconds = math.clamp(secondsAway, 0, o.MaxSeconds)
	return math.floor(ratePerSecond * o.RateFraction * seconds)
end

-- Divide uma coleta entre a aura carregada e o cofre.
function AuraMath.splitCollect(amount: number, hasVaultPass: boolean): (number, number)
	local fraction = if hasVaultPass then Economy.Vault.FractionWithPass else Economy.Vault.Fraction
	local toVault = math.floor(amount * fraction)
	return amount - toVault, toVault
end

return AuraMath
