--!strict
-- Números de economia do GDD ("Economia"). Mudar aqui não exige mexer no código.

return {
	Generator = {
		BaseRate = 2, -- aura por segundo no nível 1
		RateGrowth = 1.4, -- cada nível gera 40% mais
		BaseCost = 50, -- custo para ir do nível 1 ao 2
		CostGrowth = 1.6, -- cada nível custa 60% mais
		MaxLevel = 30,
	},

	Offline = {
		RateFraction = 0.25, -- gera a 25% da taxa offline
		MaxSeconds = 2 * 60 * 60, -- por até 2 horas
	},

	Vault = {
		Fraction = 0.20, -- o cofre guarda 20% de cada coleta (50% com Cofre+)
		FractionWithPass = 0.50,
	},

	Rebirth = {
		BonusPerRebirth = 0.25, -- +25% de geração permanente por rebirth
	},

	Steal = {
		HoldSeconds = 0, -- tempo segurando "Roubar" (GDD: ponto de partida 0 s)
		MaxDistance = 10, -- studs até a caixa para o botão aparecer
		OwnerCooldownSeconds = 10 * 60, -- um dono só perde 1 poder a cada 10 minutos
		-- Em aberto no GDD: se a cópia roubada exige pagar o preço para usar. Por ora só exige a faixa.
		StolenCopyRequiresPayment = false,
	},

	Gate = {
		DurationSeconds = 60, -- o dono fecha o lote por 60 s
		CooldownSeconds = 180, -- recarga de 3 min, contada a partir do momento em que fechou
	},

	BeginnerShieldMinutes = 15, -- escudo de iniciante: não invade nem é invadido

	-- Tempo mínimo entre dois toques no mesmo ponto de coleta, para o Touched não disparar várias vezes.
	TouchCooldown = 0.5,
}
