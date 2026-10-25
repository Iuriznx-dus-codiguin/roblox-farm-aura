--!strict
-- Dano na arena, calculado só no servidor (GDD: "Combate e arena").
-- Ataque básico: combo de 4 golpes, 5 de dano cada, sem custo. Esquiva: invulnerável por 0,3 s, recarga 2 s.
-- Os poderes vão usar CombatService.damage() com a % de roubo da raridade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Config.Arena)
local Remotes = require(Shared.Remotes)

local ArenaService = require(script.Parent.ArenaService)

local attack = Remotes.event("Attack")
local dodge = Remotes.event("Dodge")

type CombatState = {
	lastAttack: number,
	combo: number,
	lastDodge: number,
	invulnerableUntil: number,
}

local CombatService = {}

local states: { [Player]: CombatState } = {}

local function stateOf(player: Player): CombatState
	local state = states[player]
	if not state then
		state = { lastAttack = 0, combo = 0, lastDodge = -math.huge, invulnerableUntil = 0 }
		states[player] = state
	end
	return state
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Pisca o alvo para o jogador ver que acertou. Fica no servidor para todos verem.
local function flash(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 1
	highlight.Parent = character
	task.delay(0.12, function()
		highlight:Destroy()
	end)
end

-- Aplica dano de `attacker` em `victim` se os dois estão lutando. Devolve true se acertou.
function CombatService.damage(attacker: Player, victim: Player, amount: number, stealPct: number): boolean
	if attacker == victim or not ArenaService.isFighting(attacker) or not ArenaService.isFighting(victim) then
		return false
	end
	if os.clock() < stateOf(victim).invulnerableUntil then
		return false
	end
	local humanoid = humanoidOf(victim)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	-- Registra antes do dano: se este golpe derrubar, o Died já encontra quem deu o golpe final.
	ArenaService.recordHit(victim, attacker, stealPct)
	humanoid:TakeDamage(amount)
	flash(victim)
	return true
end

-- Inimigo vivo mais próximo à frente do atacante, dentro do alcance.
function CombatService.targetInFront(attacker: Player, range: number): Player?
	local root = rootOf(attacker)
	if not root then
		return nil
	end
	local best: Player? = nil
	local bestDistance = range
	for _, other in Players:GetPlayers() do
		local otherRoot = if other ~= attacker and ArenaService.isFighting(other) then rootOf(other) else nil
		if otherRoot then
			local offset = otherRoot.Position - root.Position
			local distance = offset.Magnitude
			local facing = if distance > 0 then root.CFrame.LookVector:Dot(offset.Unit) else 1
			if distance <= bestDistance and facing > 0.3 then
				best = other
				bestDistance = distance
			end
		end
	end
	return best
end

local function onAttack(player: Player)
	if not ArenaService.isFighting(player) then
		return
	end
	local state = stateOf(player)
	local t = os.clock()
	if t - state.lastAttack < Arena.Basic.Cooldown then
		return
	end
	if t - state.lastAttack > Arena.Basic.ComboResetSeconds then
		state.combo = 0
	end
	state.lastAttack = t
	state.combo = state.combo % Arena.Basic.ComboHits + 1

	local target = CombatService.targetInFront(player, Arena.Basic.Range)
	if target then
		CombatService.damage(player, target, Arena.Basic.Damage, Arena.Steal.Basic)
	end
end

local function onDodge(player: Player)
	if not ArenaService.isFighting(player) then
		return
	end
	local state = stateOf(player)
	local t = os.clock()
	if t - state.lastDodge < Arena.Dodge.Cooldown then
		return
	end
	state.lastDodge = t
	state.invulnerableUntil = t + Arena.Dodge.InvulnerableSeconds
end

function CombatService.start()
	attack.OnServerEvent:Connect(onAttack)
	dodge.OnServerEvent:Connect(onDodge)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
