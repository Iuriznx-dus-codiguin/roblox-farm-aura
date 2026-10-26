--!strict
-- Conquistas (GDD: "Danças e conquistas"). Cada conquista libera uma dança, que fica no perfil para sempre.
-- check() compara os contadores do perfil com as metas de Config/Dances. O AuraService chama check() em todo
-- pushState, então basta mudar o contador e mandar o estado para a conquista sair.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local notify = Remotes.event("Notify")

local AchievementService = {}

function AchievementService.check(player: Player, profile: DataService.Profile)
	local unlocked = false
	for _, dance in Dances.list do
		local achievement = dance.achievement
		local value = (profile :: any)[achievement.stat] or 0
		if not profile.achievements[achievement.id] and value >= achievement.goal then
			profile.achievements[achievement.id] = true
			if not table.find(profile.dances, dance.id) then
				table.insert(profile.dances, dance.id)
			end
			-- A primeira dança liberada já fica ativa; depois o jogador escolhe na tela Danças.
			profile.activeDance = profile.activeDance or dance.id
			notify:FireClient(player, `Conquista: {achievement.description}! Dança {dance.name} liberada.`)
			unlocked = true
		end
	end
	if unlocked then
		DataService.saveNow(player)
	end
end

return AchievementService
