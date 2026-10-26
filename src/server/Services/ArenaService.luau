--!strict
-- Rodadas da arena (GDD: "Combate e arena"): fila pelo portal ou pelo botão, rodada de 5 min com até 8
-- jogadores, todos contra todos, sem renascer. Quem cai perde a aura carregada (menos o cofre), o vencedor
-- rouba a % do golpe final e os poderes saem do equipado. O dano em si fica no CombatService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Config.Arena)
local AuraMath = require(Shared.AuraMath)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local ArenaBuilder = require(script.Parent.Parent.ArenaBuilder)
local AuraService = require(script.Parent.AuraService)
local DataService = require(script.Parent.DataService)

type Profile = DataService.Profile

type Hit = { attacker: Player, stealPct: number, time: number }
type Fighter = {
	entryAura: number,
	kills: number,
	alive: boolean,
	lastHit: Hit?,
}
type Phase = "waiting" | "countdown" | "running"

local joinArena = Remotes.event("JoinArena")
local arenaState = Remotes.event("ArenaState")
local notify = Remotes.event("Notify")

local ArenaService = {}

local phase: Phase = "waiting"
local phaseEndsAt = 0
local queue: { Player } = {}
local fighters: { [Player]: Fighter } = {}
local roundToken = 0
local startedWith = 0

-- No Studio, o atributo TesteArenaSolo = true no Workspace deixa a rodada começar com 1 jogador.
local function minPlayers(): number
	if RunService:IsStudio() and workspace:GetAttribute("TesteArenaSolo") == true then
		return 1
	end
	return Arena.MinPlayers
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function aliveCount(): number
	local count = 0
	for _, fighter in fighters do
		if fighter.alive then
			count += 1
		end
	end
	return count
end

local function stateFor(player: Player)
	return {
		phase = phase,
		endsAt = phaseEndsAt,
		queued = table.find(queue, player) ~= nil,
		queueCount = #queue,
		minPlayers = minPlayers(),
		alive = aliveCount(),
		fighting = fighters[player] ~= nil and fighters[player].alive,
	}
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		arenaState:FireClient(player, stateFor(player))
	end
end

function ArenaService.isFighting(player: Player): boolean
	local fighter = fighters[player]
	return phase == "running" and fighter ~= nil and fighter.alive
end

-- Registra quem acertou por último e com qual % de roubo, para o golpe final e para a desconexão.
function ArenaService.recordHit(victim: Player, attacker: Player, stealPct: number)
	local fighter = fighters[victim]
	if fighter then
		fighter.lastHit = { attacker = attacker, stealPct = stealPct, time = os.clock() }
	end
end

local function spawnPoints(): { BasePart }
	local arena = workspace:FindFirstChild("Arena")
	local folder = arena and arena:FindFirstChild("Spawns")
	local list = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(list, child)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function sendHome(player: Player)
	-- Recarregar o personagem devolve a vida cheia e o PlotService o leva para o lote.
	if player.Parent then
		player:LoadCharacter()
	end
end

local endRound: () -> ()

local function defeat(victim: Player, leaving: boolean)
	local fighter = fighters[victim]
	if not fighter or not fighter.alive then
		return
	end
	fighter.alive = false

	local profile = DataService.get(victim)
	local hit = fighter.lastHit
	local killer: Player? = nil
	if hit and os.clock() - hit.time <= Arena.LastHitWindowSeconds and hit.attacker.Parent then
		killer = hit.attacker
	end
	local killerFighter = if killer then fighters[killer] else nil
	if killer and killerFighter then
		killerFighter.kills += 1
		local killerProfile = DataService.get(killer)
		if killerProfile then
			-- Conta para a conquista de 10 derrotas, que sai no próximo pushState.
			killerProfile.arenaKills += 1
			AuraService.pushState(killer)
		end
	end

	if profile then
		if AuraService.hasShield(profile) then
			-- Escudo de iniciante: volta ao lote sem perder nada, e quem derrubou não rouba nada.
			if not leaving then
				notify:FireClient(victim, "Você caiu, mas o escudo de iniciante protegeu sua aura.")
			end
		else
			local carried = profile.aura
			local stolen = if killer and hit then math.floor(carried * hit.stealPct) else 0
			profile.aura = 0
			-- A faixa reinicia para a aura que sobrou (só o cofre).
			profile.peakAura = profile.vaultAura
			table.clear(profile.equipped)
			if killer and stolen > 0 then
				AuraService.addAura(killer, stolen)
				DataService.saveNow(killer)
				notify:FireClient(
					killer,
					`Você derrotou {victim.DisplayName} e roubou {Format.short(stolen)} de aura!`
				)
			end
			if not leaving then
				local by = if killer then ` por {killer.DisplayName}` else ""
				notify:FireClient(victim, `Você foi derrotado{by} e perdeu {Format.short(carried)} de aura.`)
				AuraService.pushState(victim)
				DataService.saveNow(victim)
			end
		end
	end

	if not leaving then
		task.delay(Arena.ReturnDelaySeconds, sendHome, victim)
	end
	broadcast()

	-- Rodada com 1 jogador (teste no Studio) só acaba pelo tempo ou quando ele cai.
	local lastStanding = if startedWith >= 2 then aliveCount() <= 1 else aliveCount() == 0
	if phase == "running" and lastStanding then
		task.defer(endRound)
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Cair por dano, por queda ou por reset conta como derrota enquanto o jogador está lutando.
		humanoid.Died:Connect(function()
			if ArenaService.isFighting(player) then
				defeat(player, false)
			end
		end)
	end
end

local function startRound()
	roundToken += 1
	local token = roundToken
	local points = spawnPoints()
	table.clear(fighters)

	local index = 0
	while #queue > 0 and index < Arena.MaxPlayers do
		local player = table.remove(queue, 1) :: Player
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local profile = DataService.get(player)
		if character and humanoid and humanoid.Health > 0 and profile then
			index += 1
			fighters[player] = { entryAura = profile.aura, kills = 0, alive = true, lastHit = nil }
			local band = AuraMath.getBand(profile.peakAura)
			humanoid.MaxHealth = Arena.BaseHealth + Arena.HealthPerBand * band.index
			humanoid.Health = humanoid.MaxHealth
			local point = points[((index - 1) % math.max(#points, 1)) + 1]
			if point then
				character:PivotTo(point.CFrame + Vector3.new(0, 3, 0))
			end
		end
	end

	if index < minPlayers() then
		-- Alguém saiu durante a contagem: devolve quem sobrou para a fila.
		for player in fighters do
			table.insert(queue, player)
			sendHome(player)
		end
		table.clear(fighters)
		phase = "waiting"
		broadcast()
		return
	end

	phase = "running"
	startedWith = index
	phaseEndsAt = now() + Arena.RoundSeconds
	broadcast()

	task.delay(Arena.RoundSeconds, function()
		if roundToken == token and phase == "running" then
			endRound()
		end
	end)
end

function endRound()
	if phase ~= "running" then
		return
	end
	phase = "waiting"
	roundToken += 1

	-- Vence quem sobra sozinho numa rodada que começou com 2 ou mais. Se o tempo acaba com mais de um vivo,
	-- ninguém vence. A sequência de vitórias (conquista Supreme Pose) zera para quem jogou e não venceu.
	local winner: Player? = nil
	if startedWith >= 2 and aliveCount() == 1 then
		for player, fighter in fighters do
			if fighter.alive then
				winner = player
			end
		end
	end

	-- Quem mais derrotou leva o bônus; empate divide o prêmio, cada um sobre a própria aura de entrada.
	local topKills = 0
	for _, fighter in fighters do
		topKills = math.max(topKills, fighter.kills)
	end
	for player, fighter in fighters do
		if topKills > 0 and fighter.kills == topKills then
			local bonus = math.floor(fighter.entryAura * Arena.TopKillerBonus)
			if bonus > 0 then
				AuraService.addAura(player, bonus)
				notify:FireClient(player, `Mais derrotas da rodada! Bônus de {Format.short(bonus)} de aura.`)
			end
		end
		local profile = DataService.get(player)
		if profile then
			profile.arenaWinStreak = if player == winner then profile.arenaWinStreak + 1 else 0
			if player == winner then
				notify:FireClient(
					player,
					`Você venceu a rodada! Vitórias seguidas: {profile.arenaWinStreak}.`
				)
			end
			AuraService.pushState(player)
		end
		if fighter.alive then
			sendHome(player)
			DataService.saveNow(player)
		end
	end
	table.clear(fighters)
	broadcast()
	ArenaService.checkQueue()
end

function ArenaService.checkQueue()
	if phase == "waiting" and #queue >= minPlayers() then
		phase = "countdown"
		phaseEndsAt = now() + Arena.CountdownSeconds
		roundToken += 1
		local token = roundToken
		broadcast()
		task.delay(Arena.CountdownSeconds, function()
			if roundToken == token and phase == "countdown" then
				startRound()
			end
		end)
	elseif phase == "countdown" and #queue < minPlayers() then
		phase = "waiting"
		roundToken += 1
		broadcast()
	else
		broadcast()
	end
end

local function removeFromQueue(player: Player)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end
end

local function onJoin(player: Player)
	if fighters[player] and fighters[player].alive then
		return
	end
	if table.find(queue, player) then
		removeFromQueue(player)
	else
		table.insert(queue, player)
		if phase == "running" then
			notify:FireClient(player, "Rodada em andamento. Você entra na próxima.")
		end
	end
	ArenaService.checkQueue()
end

local function bindPortal()
	local portal = workspace:FindFirstChild("ArenaPortal")
	if not portal or not portal:IsA("BasePart") then
		return
	end
	local lastTouch: { [Player]: number } = {}
	portal.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or table.find(queue, player) or fighters[player] then
			return
		end
		if os.clock() - (lastTouch[player] or 0) < 2 then
			return
		end
		lastTouch[player] = os.clock()
		onJoin(player)
	end)
end

function ArenaService.start()
	if not workspace:FindFirstChild("Arena") then
		ArenaBuilder.build(workspace)
	end
	bindPortal()

	joinArena.OnServerEvent:Connect(onJoin)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			watchCharacter(player, player.Character)
		end
		arenaState:FireClient(player, stateFor(player))
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Desconectar na arena conta como derrota, antes do último save do perfil.
	DataService.beforeRelease(function(player)
		if ArenaService.isFighting(player) then
			defeat(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- A ordem entre este evento e o save do DataService não é garantida; defeat() só roda uma vez.
		if ArenaService.isFighting(player) then
			defeat(player, true)
		end
		removeFromQueue(player)
		fighters[player] = nil
		ArenaService.checkQueue()
	end)
end

return ArenaService
