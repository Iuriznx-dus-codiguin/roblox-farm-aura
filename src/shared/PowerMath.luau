--!strict
-- Fórmulas puras dos poderes (GDD: "Poderes"): quando dá para usar, dano com treino, custo do treino e roubo.
-- Sem estado e sem serviços do Roblox, para poder rodar no cliente, no servidor e nos testes.

local Arena = require(script.Parent.Config.Arena)
local Economy = require(script.Parent.Config.Economy)
local Powers = require(script.Parent.Config.Powers)

local PowerMath = {}

-- Usável quando a faixa do jogador (pelo pico de aura) alcança a faixa do poder.
function PowerMath.isUsable(power: Powers.Power, bandIndex: number): boolean
	return bandIndex >= power.band
end

-- Dano de um disparo no nível de treino dado, com uma casa decimal.
function PowerMath.damage(power: Powers.Power, level: number): number
	local bonus = 1 + Economy.Training.DamagePerLevel * (level - 1)
	return math.round(power.damage * bonus * 10) / 10
end

-- Custo para treinar do `level` atual para o próximo, ou nil no nível máximo.
function PowerMath.trainCost(power: Powers.Power, level: number): number?
	if level >= Economy.Training.MaxLevel then
		return nil
	end
	return power.price * level
end

-- % da aura carregada da vítima que o golpe final deste poder rouba.
function PowerMath.stealPct(power: Powers.Power): number
	return (Arena.Steal :: { [string]: number })[power.rarity]
end

return PowerMath
