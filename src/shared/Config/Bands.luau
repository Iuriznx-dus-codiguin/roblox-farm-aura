--!strict
-- Faixas de aura (GDD: "Loop principal e faixas de aura").
-- A faixa vem do pico de aura desde a última derrota ou rebirth, nunca da aura atual.

export type Band = {
	index: number,
	name: string,
	minAura: number,
	shotCost: number,
	color: Color3,
}

local Bands: { Band } = {
	{ index = 1, name = "Spark", minAura = 0, shotCost = 15, color = Color3.fromRGB(235, 235, 235) },
	{ index = 2, name = "Glow", minAura = 1_000, shotCost = 20, color = Color3.fromRGB(90, 160, 255) },
	{ index = 3, name = "Flame", minAura = 10_000, shotCost = 200, color = Color3.fromRGB(170, 90, 255) },
	{ index = 4, name = "Storm", minAura = 100_000, shotCost = 2_000, color = Color3.fromRGB(120, 220, 255) },
	{
		index = 5,
		name = "Eclipse",
		minAura = 1_000_000,
		shotCost = 20_000,
		color = Color3.fromRGB(60, 40, 90),
	},
	{
		index = 6,
		name = "Divine",
		minAura = 10_000_000,
		shotCost = 200_000,
		color = Color3.fromRGB(255, 210, 80),
	},
	{
		index = 7,
		name = "Sigma Supreme",
		minAura = 100_000_000,
		shotCost = 2_000_000,
		color = Color3.fromRGB(255, 120, 200),
	},
}

return Bands
