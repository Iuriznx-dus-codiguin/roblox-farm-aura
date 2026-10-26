--!strict
-- Efeitos dos poderes na arena, desenhados em cada cliente quando o servidor avisa um disparo (PowerFx).
-- São provisórios, feitos de peças neon na cor da raridade; a arte final vem do ForgeGUI.
-- Na Investida e no Impacto, o cliente de quem disparou também move o personagem, como na esquiva.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Config.Arena)
local Powers = require(Shared.Config.Powers)

export type Cast = {
	powerId: string,
	caster: Player,
	origin: Vector3,
	direction: Vector3,
	target: Vector3?, -- Impacto: ponto de queda
	victim: Player?, -- Dreno: alvo preso
}

local PowerFx = {}

local folder: Folder? = nil

local function fxFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local created = Instance.new("Folder")
	created.Name = "PowerFx"
	created.Parent = workspace
	folder = created
	return created
end

local function neon(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Parent = fxFolder()
	return p
end

local function fade(part: BasePart, seconds: number, goal: { [string]: any })
	goal.Transparency = 1
	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
	Debris:AddItem(part, seconds + 0.05)
end

local function rootOf(player: Player?): BasePart?
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Raio que ignora os efeitos e os personagens dados, para o efeito parar na parede (ou no primeiro alvo).
local function castRay(origin: Vector3, direction: Vector3, range: number, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	table.insert(ignore, fxFolder())
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, direction * range, params)
	return if result then (result.Position - origin).Magnitude else range
end

local function allCharacters(): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

-- Chama `step(elapsed)` a cada quadro por `duration` segundos e depois apaga `parts`.
local function during(duration: number, step: (elapsed: number) -> (), parts: { Instance })
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration then
			connection:Disconnect()
			for _, part in parts do
				part:Destroy()
			end
			return
		end
		step(elapsed)
	end)
end

local function projectile(cast: Cast, color: Color3)
	local config = Arena.Models["Projétil"]
	local ignore: { Instance } = {}
	if cast.caster.Character then
		table.insert(ignore, cast.caster.Character)
	end
	local distance = castRay(cast.origin, cast.direction, config.Range, ignore)
	local ball = neon(Vector3.one * 2.5, CFrame.new(cast.origin), color, Enum.PartType.Ball)
	during(distance / config.Speed, function(elapsed)
		ball.CFrame = CFrame.new(cast.origin + cast.direction * config.Speed * elapsed)
	end, { ball })
end

local function dash(cast: Cast, color: Color3)
	local config = Arena.Models["Investida"]
	local speed = config.Distance / config.Duration
	local mine = cast.caster == Players.LocalPlayer
	local lastGhost = -1
	during(config.Duration, function(elapsed)
		local root = rootOf(cast.caster)
		if not root then
			return
		end
		if mine then
			root.AssemblyLinearVelocity = cast.direction * speed
				+ Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
		if elapsed - lastGhost >= 0.05 then
			lastGhost = elapsed
			local ghost = neon(Vector3.new(2, 3, 1), root.CFrame, color)
			ghost.Transparency = 0.4
			fade(ghost, 0.3, {})
		end
	end, {})
end

local function area(cast: Cast, color: Color3)
	local radius = Arena.Models["Área"].Radius
	local sphere = neon(Vector3.one * 2, CFrame.new(cast.origin), color, Enum.PartType.Ball)
	sphere.Transparency = 0.3
	fade(sphere, 0.35, { Size = Vector3.one * radius * 2 })
end

local function beam(cast: Cast, color: Color3)
	local config = Arena.Models["Feixe"]
	local ray = neon(Vector3.new(1.5, 1.5, 1), CFrame.new(cast.origin), color)
	ray.Transparency = 0.2
	during(config.Duration, function()
		local root = rootOf(cast.caster)
		if not root then
			return
		end
		local origin = root.Position
		local length = castRay(origin, cast.direction, config.Range, allCharacters())
		ray.Size = Vector3.new(1.5, 1.5, length)
		ray.CFrame = CFrame.lookAt(origin, origin + cast.direction) * CFrame.new(0, 0, -length / 2)
	end, { ray })
end

local function impact(cast: Cast, color: Color3)
	local config = Arena.Models["Impacto"]
	local target = cast.target or cast.origin
	if cast.caster == Players.LocalPlayer then
		local root = rootOf(cast.caster)
		local character = cast.caster.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			-- Velocidade para chegar ao ponto de queda em AirTime segundos, num arco.
			local horizontal = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
				/ config.AirTime
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			root.AssemblyLinearVelocity = horizontal
				+ Vector3.new(0, workspace.Gravity * config.AirTime / 2, 0)
			during(config.AirTime, function()
				local current = rootOf(cast.caster)
				if current then
					current.AssemblyLinearVelocity = horizontal
						+ Vector3.new(0, current.AssemblyLinearVelocity.Y, 0)
				end
			end, {})
		end
	end
	task.delay(config.AirTime, function()
		local root = rootOf(cast.caster)
		local center = if root then root.Position - Vector3.new(0, 2.5, 0) else target
		-- Cilindro deitado no chão: o eixo X do cilindro aponta para cima.
		local ring = neon(
			Vector3.new(0.6, 2, 2),
			CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			Enum.PartType.Cylinder
		)
		ring.Transparency = 0.3
		fade(ring, 0.4, { Size = Vector3.new(0.6, config.Radius * 2, config.Radius * 2) })
	end)
end

local function drain(cast: Cast, color: Color3)
	local config = Arena.Models["Dreno"]
	local tether = neon(Vector3.new(0.6, 0.6, 1), CFrame.new(cast.origin), color)
	during(config.Duration, function()
		local from, to = rootOf(cast.caster), rootOf(cast.victim)
		if not from or not to then
			tether.Transparency = 1
			return
		end
		local length = (to.Position - from.Position).Magnitude
		tether.Transparency = if length > config.Range then 1 else 0.2
		tether.Size = Vector3.new(0.6, 0.6, length)
		tether.CFrame = CFrame.lookAt(from.Position, to.Position) * CFrame.new(0, 0, -length / 2)
	end, { tether })
end

local renderers: { [string]: (cast: Cast, color: Color3) -> () } = {
	["Projétil"] = projectile,
	["Investida"] = dash,
	["Área"] = area,
	["Feixe"] = beam,
	["Impacto"] = impact,
	["Dreno"] = drain,
}

function PowerFx.play(cast: Cast)
	local power = Powers.byId[cast.powerId]
	local render = if power then renderers[power.model] else nil
	if power and render then
		render(cast, Powers.rarityColors[power.rarity])
	end
end

return PowerFx
