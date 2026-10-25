--!strict
-- Os 12 poderes do MVP (GDD: "Poderes do MVP"). O id é o número do poder no GDD.
-- "model" é o modelo de comportamento que o combate vai usar; aqui ele só aparece na loja.

export type Rarity = "Comum" | "Raro" | "Épico" | "Lendário"
export type Behavior = "Projétil" | "Investida" | "Área" | "Feixe" | "Impacto" | "Dreno"

export type Power = {
	id: string,
	name: string,
	rarity: Rarity,
	model: Behavior,
	band: number,
	shotCost: number,
	damage: number,
	cooldown: number,
	price: number,
}

local Powers: { Power } = {
	{
		id = "1",
		name = "Aura Punch",
		rarity = "Comum",
		model = "Investida",
		band = 1,
		shotCost = 15,
		damage = 10,
		cooldown = 4,
		price = 300,
	},
	{
		id = "2",
		name = "Spark Shot",
		rarity = "Comum",
		model = "Projétil",
		band = 1,
		shotCost = 15,
		damage = 10,
		cooldown = 4,
		price = 300,
	},
	{
		id = "3",
		name = "Pulse Wave",
		rarity = "Comum",
		model = "Área",
		band = 1,
		shotCost = 15,
		damage = 11,
		cooldown = 5,
		price = 500,
	},
	{
		id = "4",
		name = "Glow Kick",
		rarity = "Comum",
		model = "Impacto",
		band = 1,
		shotCost = 15,
		damage = 11,
		cooldown = 5,
		price = 500,
	},
	{
		id = "5",
		name = "Static Ray",
		rarity = "Comum",
		model = "Feixe",
		band = 1,
		shotCost = 15,
		damage = 12,
		cooldown = 6,
		price = 700,
	},
	{
		id = "12",
		name = "Sigma Dash",
		rarity = "Comum",
		model = "Investida",
		band = 2,
		shotCost = 20,
		damage = 14,
		cooldown = 5,
		price = 1_500,
	},
	{
		id = "14",
		name = "Void Orb",
		rarity = "Raro",
		model = "Projétil",
		band = 3,
		shotCost = 200,
		damage = 18,
		cooldown = 7,
		price = 15_000,
	},
	{
		id = "15",
		name = "Blaze Spin",
		rarity = "Raro",
		model = "Área",
		band = 3,
		shotCost = 200,
		damage = 19,
		cooldown = 8,
		price = 20_000,
	},
	{
		id = "21",
		name = "Phantom Strike",
		rarity = "Raro",
		model = "Investida",
		band = 4,
		shotCost = 2_000,
		damage = 22,
		cooldown = 8,
		price = 50_000,
	},
	{
		id = "23",
		name = "Dragon Breath",
		rarity = "Épico",
		model = "Feixe",
		band = 5,
		shotCost = 20_000,
		damage = 30,
		cooldown = 12,
		price = 1_500_000,
	},
	{
		id = "24",
		name = "Storm Breaker",
		rarity = "Épico",
		model = "Impacto",
		band = 5,
		shotCost = 20_000,
		damage = 30,
		cooldown = 12,
		price = 1_800_000,
	},
	{
		id = "28",
		name = "Aura Thief",
		rarity = "Lendário",
		model = "Dreno",
		band = 6,
		shotCost = 200_000,
		damage = 40,
		cooldown = 18,
		price = 15_000_000,
	},
}

local RarityColors: { [string]: Color3 } = {
	["Comum"] = Color3.fromRGB(200, 200, 200),
	["Raro"] = Color3.fromRGB(80, 160, 255),
	["Épico"] = Color3.fromRGB(180, 90, 255),
	["Lendário"] = Color3.fromRGB(255, 190, 40),
}

local byId: { [string]: Power } = {}
for _, power in Powers do
	byId[power.id] = power
end

return {
	list = Powers,
	byId = byId,
	rarityColors = RarityColors,
}
