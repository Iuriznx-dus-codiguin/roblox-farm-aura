--!strict
-- Os 6 modelos de comportamento dos poderes na arena (GDD: "Poderes"). Cada poder é uma linha de configuração
-- (Config/Powers) e usa um destes modelos. O cliente só pede o disparo com o slot e o ponto de mira; custo em
-- aura, recarga, quem é atingido e o dano são decididos aqui. Depois o servidor avisa todos os clientes
-- (PowerFx) para desenharem o efeito; na Investida e no Impacto, o cliente de quem disparou move o personagem.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Config.Arena)
local AuraMath = require(Shared.AuraMath)
local Format = require(Shared.Format)
local PowerMath = require(Shared.PowerMath)
local Powers = require(Shared.Config.Powers)
local Remotes = require(Shared.Remotes)

local ArenaService = require(script.Parent.ArenaService)
local AuraService = require(script.Parent.AuraService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)

local usePower = Remotes.event("UsePower")
local powerFx = Remotes.event("PowerFx")
local notify = Remotes.event("Notify")

-- Folga para a posição do personagem, que o cliente move, chegar ao servidor.
local LATENCY_MARGIN = 0.15

type Cast = {
	caster: Player,
	damage: number,
	stealPct: number,
	origin: Vector3,
	direction: Vector3, -- horizontal e unitária
	victim: Player?, -- só no Dreno
}

type Enemy = { player: Player, root: BasePart }

local PowerCombatService = {}

local readyAt: { [Player]: { [string]: number } } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Inimigos vivos na arena, com a posição atual.
local function enemiesOf(caster: Player): { Enemy }
	local list = {}
	for _, other in Players:GetPlayers() do
		local root = if other ~= caster and ArenaService.isFighting(other) then rootOf(other) else nil
		if root then
			table.insert(list, { player = other, root = root })
		end
	end
	return list
end

local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local lengthSquared = ab:Dot(ab)
	local t = if lengthSquared > 0 then math.clamp((point - a):Dot(ab) / lengthSquared, 0, 1) else 0
	return (point - (a + ab * t)).Magnitude
end

-- Até onde o golpe vai antes de bater numa parede. O raio ignora os personagens.
local function reach(origin: Vector3, direction: Vector3, range: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	local result = workspace:Raycast(origin, direction * range, params)
	return if result then (result.Position - origin).Magnitude else range
end

local function hit(cast: Cast, victim: Player, amount: number): boolean
	return CombatService.damage(cast.caster, victim, amount, cast.stealPct)
end

-- Dreno: cada acerto também passa 1% da aura carregada do alvo para quem disparou (nada com escudo).
local function drainAura(caster: Player, victim: Player)
	local profile = DataService.get(victim)
	if not profile or AuraService.hasShield(profile) then
		return
	end
	local amount = math.floor(profile.aura * Arena.DrainAuraPerHit)
	if amount <= 0 then
		return
	end
	profile.aura -= amount
	AuraService.pushState(victim)
	AuraService.addAura(caster, amount)
end

-- Inimigo mais perto do ponto de mira, dentro do alcance do Dreno.
local function drainTarget(caster: Player, origin: Vector3, aim: Vector3): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, enemy in enemiesOf(caster) do
		local fromAim = (enemy.root.Position - aim).Magnitude
		if
			(enemy.root.Position - origin).Magnitude <= Arena.Models["Dreno"].Range
			and fromAim < bestDistance
		then
			best = enemy.player
			bestDistance = fromAim
		end
	end
	return best
end

local models: { [string]: (cast: Cast) -> () } = {}

-- Voa reto e acerta o primeiro inimigo no caminho; para na parede.
models["Projétil"] = function(cast)
	local config = Arena.Models["Projétil"]
	local maxDistance = reach(cast.origin, cast.direction, config.Range)
	local travelled = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		local from = cast.origin + cast.direction * travelled
		travelled = math.min(travelled + config.Speed * dt, maxDistance)
		local to = cast.origin + cast.direction * travelled
		for _, enemy in enemiesOf(cast.caster) do
			if distanceToSegment(enemy.root.Position, from, to) <= config.Radius then
				connection:Disconnect()
				hit(cast, enemy.player, cast.damage)
				return
			end
		end
		if travelled >= maxDistance then
			connection:Disconnect()
		end
	end)
end

-- O cliente faz o avanço; aqui cada inimigo que fica perto de quem avança leva o golpe uma vez.
models["Investida"] = function(cast)
	local config = Arena.Models["Investida"]
	local alreadyHit: { [Player]: boolean } = {}
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local root = rootOf(cast.caster)
		if not root or elapsed > config.Duration + LATENCY_MARGIN then
			connection:Disconnect()
			return
		end
		for _, enemy in enemiesOf(cast.caster) do
			local close = (enemy.root.Position - root.Position).Magnitude <= config.HitRadius
			if close and not alreadyHit[enemy.player] then
				alreadyHit[enemy.player] = true
				hit(cast, enemy.player, cast.damage)
			end
		end
	end)
end

-- Explosão ao redor de quem disparou.
models["Área"] = function(cast)
	local radius = Arena.Models["Área"].Radius
	for _, enemy in enemiesOf(cast.caster) do
		if (enemy.root.Position - cast.origin).Magnitude <= radius then
			hit(cast, enemy.player, cast.damage)
		end
	end
end

-- Raio contínuo na direção da mira, saindo de quem disparou; o dano se divide pelos ticks.
models["Feixe"] = function(cast)
	local config = Arena.Models["Feixe"]
	task.spawn(function()
		for _ = 1, config.Ticks do
			local root = rootOf(cast.caster)
			if not root or not ArenaService.isFighting(cast.caster) then
				return
			end
			local tip = root.Position + cast.direction * reach(root.Position, cast.direction, config.Range)
			for _, enemy in enemiesOf(cast.caster) do
				if distanceToSegment(enemy.root.Position, root.Position, tip) <= config.Width then
					hit(cast, enemy.player, cast.damage / config.Ticks)
				end
			end
			task.wait(config.Duration / config.Ticks)
		end
	end)
end

-- O cliente faz o salto até a mira; o dano em área sai de onde ele está ao cair.
models["Impacto"] = function(cast)
	local config = Arena.Models["Impacto"]
	task.delay(config.AirTime + LATENCY_MARGIN, function()
		local root = rootOf(cast.caster)
		if not root or not ArenaService.isFighting(cast.caster) then
			return
		end
		for _, enemy in enemiesOf(cast.caster) do
			if (enemy.root.Position - root.Position).Magnitude <= config.Radius then
				hit(cast, enemy.player, cast.damage)
			end
		end
	end)
end

-- Prende no alvo escolhido no disparo; a cada acerto tira dano e aura dele. Solta se ele sair do alcance.
models["Dreno"] = function(cast)
	local config = Arena.Models["Dreno"]
	local victim = cast.victim
	if not victim then
		return
	end
	task.spawn(function()
		for _ = 1, config.Hits do
			local root, victimRoot = rootOf(cast.caster), rootOf(victim)
			if not root or not victimRoot or not ArenaService.isFighting(cast.caster) then
				return
			end
			if (victimRoot.Position - root.Position).Magnitude > config.Range then
				return
			end
			if hit(cast, victim, cast.damage / config.Hits) then
				drainAura(cast.caster, victim)
			end
			task.wait(config.Duration / config.Hits)
		end
	end)
end

local function isSaneVector(v: Vector3): boolean
	-- NaN não é igual a si mesmo; o limite evita números absurdos vindos do cliente.
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 100_000
end

local function onUsePower(player: Player, slot: unknown, aimValue: unknown)
	if type(slot) ~= "number" or typeof(aimValue) ~= "Vector3" then
		return
	end
	local aim = aimValue :: Vector3
	if not isSaneVector(aim) then
		return
	end
	if not ArenaService.isFighting(player) then
		return
	end
	local profile = DataService.get(player)
	local root = rootOf(player)
	if not profile or not root then
		return
	end
	local powerId = profile.equipped[slot]
	local power = if powerId then Powers.byId[powerId] else nil
	local level = if powerId then profile.powers[powerId] else nil
	if not power or not level or not PowerMath.isUsable(power, AuraMath.getBand(profile.peakAura).index) then
		return
	end

	local timers: { [string]: number } = readyAt[player] or {}
	readyAt[player] = timers
	local now = os.clock()
	if now < (timers[power.id] or 0) then
		return
	end
	if profile.aura < power.shotCost then
		notify:FireClient(
			player,
			`Falta aura: {power.name} gasta {Format.short(power.shotCost)} por disparo.`
		)
		return
	end

	local origin = root.Position
	local flat = Vector3.new(aim.X - origin.X, 0, aim.Z - origin.Z)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local direction = if flat.Magnitude > 0.5 then flat.Unit else look.Unit

	local cast: Cast = {
		caster = player,
		damage = PowerMath.damage(power, level),
		stealPct = PowerMath.stealPct(power),
		origin = origin,
		direction = direction,
		victim = nil,
	}
	if power.model == "Dreno" then
		cast.victim = drainTarget(player, origin, aim)
		if not cast.victim then
			notify:FireClient(player, "Nenhum inimigo perto da mira.")
			return
		end
	end

	-- Impacto: o salto vai até a mira, limitado à distância máxima.
	local landing: Vector3? = nil
	if power.model == "Impacto" then
		local distance = math.min(flat.Magnitude, Arena.Models["Impacto"].MaxDistance)
		landing = origin + direction * distance
	end

	profile.aura -= power.shotCost
	timers[power.id] = now + power.cooldown
	AuraService.pushState(player)

	powerFx:FireAllClients({
		powerId = power.id,
		caster = player,
		origin = origin,
		direction = direction,
		target = landing,
		victim = cast.victim,
	})
	models[power.model](cast)
end

function PowerCombatService.start()
	usePower.OnServerEvent:Connect(onUsePower)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return PowerCombatService
