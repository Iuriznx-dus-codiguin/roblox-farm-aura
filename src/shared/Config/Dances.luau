--!strict
-- Danças e conquistas (GDD: "Danças e conquistas"). Cada conquista libera uma dança, e só uma fica ativa.
-- Enquanto o personagem dança no próprio lote, a geração ganha o bônus da dança; andar para a dança.
-- As danças nunca são roubadas. As animações são danças padrão do Roblox (R15) até termos as nossas.

-- Campo do perfil que a conquista acompanha (ver AchievementService).
export type Stat = "collected" | "arenaKills" | "rebirths" | "peakAura" | "arenaWinStreak"

export type Achievement = {
	id: string,
	description: string,
	stat: Stat,
	goal: number,
}

export type Dance = {
	id: string,
	name: string,
	bonus: number, -- soma no multiplicador de geração enquanto dança
	animationId: string,
	achievement: Achievement,
}

local list: { Dance } = {
	{
		id = "AuraSway",
		name = "Aura Sway",
		bonus = 0.05,
		animationId = "rbxassetid://507771019",
		achievement = {
			id = "FirstCollect",
			description = "Primeira coleta de aura",
			stat = "collected",
			goal = 1,
		},
	},
	{
		id = "SigmaStomp",
		name = "Sigma Stomp",
		bonus = 0.10,
		animationId = "rbxassetid://507777268",
		achievement = {
			id = "ArenaKills",
			description = "Derrotar 10 jogadores na arena",
			stat = "arenaKills",
			goal = 10,
		},
	},
	{
		id = "GlowSpin",
		name = "Glow Spin",
		bonus = 0.15,
		animationId = "rbxassetid://507776043",
		achievement = { id = "FirstRebirth", description = "Primeiro rebirth", stat = "rebirths", goal = 1 },
	},
	{
		id = "EclipseFlow",
		name = "Eclipse Flow",
		bonus = 0.20,
		animationId = "rbxassetid://507776720",
		achievement = {
			id = "MillionAura",
			description = "Chegar a 1.000.000 de aura",
			stat = "peakAura",
			goal = 1_000_000,
		},
	},
	{
		id = "SupremePose",
		name = "Supreme Pose",
		bonus = 0.25,
		animationId = "rbxassetid://507777451",
		achievement = {
			id = "ArenaWinStreak",
			description = "Vencer 3 rodadas de arena seguidas",
			stat = "arenaWinStreak",
			goal = 3,
		},
	},
}

local byId: { [string]: Dance } = {}
for _, dance in list do
	byId[dance.id] = dance
end

return {
	list = list,
	byId = byId,
	stopDistance = 2, -- studs: andar mais que isso desde o começo da dança para a dança
}
