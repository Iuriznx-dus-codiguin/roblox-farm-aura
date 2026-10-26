--!strict
-- Números da arena e do combate (GDD: "Combate e arena").

return {
	MaxPlayers = 8,
	MinPlayers = 2, -- a rodada começa com 2 jogadores ou mais
	CountdownSeconds = 10, -- espera na fila antes de teleportar, para dar tempo de outros entrarem
	RoundSeconds = 5 * 60,
	ReturnDelaySeconds = 2, -- tempo entre cair e voltar ao lote

	-- Vida: 100 + 10 por faixa de aura (Spark = faixa 1 = 110).
	BaseHealth = 100,
	HealthPerBand = 10,

	Basic = {
		Damage = 5, -- cada golpe do combo de 4
		ComboHits = 4,
		ComboResetSeconds = 1, -- sem bater por esse tempo, o combo volta ao golpe 1
		Cooldown = 0.35, -- entre golpes
		Range = 8, -- studs à frente do atacante
	},

	Dodge = {
		InvulnerableSeconds = 0.3,
		Cooldown = 2,
		DashSpeed = 70, -- velocidade do avanço no cliente
		DashSeconds = 0.2, -- duração do avanço (70 x 0,2 = 14 studs)
	},

	-- % da aura carregada da vítima que o vencedor rouba, pelo golpe final.
	Steal = {
		Basic = 0.10,
		["Comum"] = 0.25,
		["Raro"] = 0.30,
		["Épico"] = 0.40,
		["Lendário"] = 0.50,
	},

	-- Desconectar conta como derrota; quem acertou nos últimos 10 s recebe o roubo.
	LastHitWindowSeconds = 10,

	-- Fim da rodada: quem mais derrotou leva 10% da aura com que entrou.
	TopKillerBonus = 0.10,

	-- Poderes na arena (GDD: "Poderes"). Dano, custo por disparo e recarga vêm de cada poder (Config/Powers).
	MaxEquipped = 3,
	AutoAimRadius = 40, -- mira automática, só no celular: o inimigo mais próximo nesse raio
	DrainAuraPerHit = 0.01, -- Dreno (lendários): cada acerto também rouba 1% da aura carregada do alvo

	-- Números de cada modelo de comportamento (studs e segundos).
	Models = {
		["Projétil"] = { Speed = 90, Range = 80, Radius = 3 }, -- voa reto e acerta o primeiro alvo
		["Investida"] = { Distance = 28, Duration = 0.3, HitRadius = 5 }, -- avança e acerta quem está no caminho
		["Área"] = { Radius = 14 }, -- explosão ao redor do jogador
		["Feixe"] = { Duration = 1.5, Ticks = 6, Range = 45, Width = 3 }, -- o dano do poder se divide pelos ticks
		["Impacto"] = { MaxDistance = 30, AirTime = 0.6, Radius = 12 }, -- salta até a mira e causa dano ao cair
		["Dreno"] = { Range = 35, Duration = 2, Hits = 4 }, -- prende no alvo; o dano se divide pelos acertos
	},
}
