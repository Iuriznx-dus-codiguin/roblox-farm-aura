--!strict
-- Barra dos 3 poderes equipados (GDD: HUD com os 3 poderes e o custo em aura de cada disparo).
-- Na arena, 1, 2 e 3 (ou tocar no slot) disparam o poder na direção da mira: o mouse no PC e, no celular,
-- o inimigo mais próximo num raio de 40 studs. O servidor confere tudo; a recarga aqui é só visual.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Config.Arena)
local Format = require(Shared.Format)
local Powers = require(Shared.Config.Powers)

local Hud = require(script.Parent.Hud)

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local GAMEPAD = { Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonL1 }
local SLOT_SIZE = Vector2.new(104, 64)
local SLOT_GAP = 8

type Slot = {
	button: TextButton,
	name: TextLabel,
	cost: TextLabel,
	timer: TextLabel,
}

local PowerBar = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Ponto para onde o poder vai. Celular: trava no inimigo mais perto; PC: onde o mouse aponta.
local function aimPoint(player: Player): Vector3?
	local root = rootOf(player)
	local character = player.Character
	if not root or not character then
		return nil
	end
	local ahead = root.Position + root.CFrame.LookVector * 20

	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local best: Vector3? = nil
		local bestDistance = Arena.AutoAimRadius
		for _, other in Players:GetPlayers() do
			local otherRoot = if other ~= player then rootOf(other) else nil
			if otherRoot then
				local distance = (otherRoot.Position - root.Position).Magnitude
				if distance <= bestDistance then
					best = otherRoot.Position
					bestDistance = distance
				end
			end
		end
		return best or ahead
	end

	if UserInputService.MouseEnabled then
		local camera = workspace.CurrentCamera
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		return if result then result.Position else ray.Origin + ray.Direction * 500
	end

	return ahead
end

function PowerBar.create(onUse: (slot: number, aim: Vector3) -> ())
	local player = Players.LocalPlayer
	local screen = player:WaitForChild("PlayerGui"):WaitForChild("Hud")

	local bar = Instance.new("Frame")
	bar.Name = "PowerBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -84)
	bar.Size = UDim2.fromOffset(SLOT_SIZE.X * 3 + SLOT_GAP * 2, SLOT_SIZE.Y)
	bar.BackgroundTransparency = 1
	bar.Parent = screen

	local equipped: { string } = {}
	local aura = 0
	local fighting = false
	local readyAt: { [string]: number } = {}

	local function use(slot: number)
		local powerId = equipped[slot]
		if not fighting or not powerId or os.clock() < (readyAt[powerId] or 0) then
			return
		end
		local aim = aimPoint(player)
		if aim then
			onUse(slot, aim)
		end
	end

	local slots: { Slot } = {}
	for index = 1, 3 do
		local button = Instance.new("TextButton")
		button.Name = "Slot" .. index
		button.Position = UDim2.fromOffset((index - 1) * (SLOT_SIZE.X + SLOT_GAP), 0)
		button.Size = UDim2.fromOffset(SLOT_SIZE.X, SLOT_SIZE.Y)
		button.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
		button.BackgroundTransparency = 0.2
		button.Text = ""
		button.Parent = bar
		corner(button, 12)
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Rarity"
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = button

		text(button, {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(16, 16),
			Text = tostring(index),
			TextColor3 = Color3.fromRGB(190, 190, 210),
		})
		local name = text(button, {
			Position = UDim2.fromOffset(6, 18),
			Size = UDim2.new(1, -12, 0, 22),
		})
		local cost = text(button, {
			Position = UDim2.fromOffset(6, 42),
			Size = UDim2.new(1, -12, 0, 16),
			TextColor3 = Color3.fromRGB(190, 190, 210),
		})
		local timer = text(button, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0.35,
			BackgroundColor3 = Color3.new(0, 0, 0),
			Visible = false,
		})
		corner(timer, 12)

		button.Activated:Connect(function()
			use(index)
		end)
		slots[index] = { button = button, name = name, cost = cost, timer = timer }
	end

	local function refresh()
		for index, slot in slots do
			local power = Powers.byId[equipped[index] or ""]
			local stroke = slot.button:FindFirstChild("Rarity") :: UIStroke
			if not power then
				slot.name.Text = "Vazio"
				slot.name.TextColor3 = Color3.fromRGB(120, 120, 140)
				slot.cost.Text = "Equipe em Poderes"
				stroke.Color = Color3.fromRGB(70, 70, 90)
				slot.timer.Visible = false
				continue
			end
			slot.name.Text = power.name
			slot.name.TextColor3 = Powers.rarityColors[power.rarity]
			slot.cost.Text = `{Format.short(power.shotCost)} aura`
			slot.cost.TextColor3 = if aura >= power.shotCost
				then Color3.fromRGB(190, 190, 210)
				else Color3.fromRGB(255, 110, 110)
			stroke.Color = Powers.rarityColors[power.rarity]
			local remaining = (readyAt[power.id] or 0) - os.clock()
			slot.timer.Visible = remaining > 0
			slot.timer.Text = if remaining > 0 then string.format("%.0f", math.ceil(remaining)) else ""
		end
	end

	local function handleKey(_name: string, inputState: Enum.UserInputState, input: InputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local slot = table.find(KEYS, input.KeyCode) or table.find(GAMEPAD, input.KeyCode)
		if slot then
			use(slot)
		end
		return Enum.ContextActionResult.Sink
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			refresh()
		end
	end)

	local powerBar = {}

	function powerBar.render(state: Hud.State)
		equipped = state.equipped
		aura = state.aura
		refresh()
	end

	-- As teclas só valem dentro da arena; fora dela 1, 2 e 3 ficam livres.
	function powerBar.setFighting(value: boolean)
		if value == fighting then
			return
		end
		fighting = value
		if fighting then
			ContextActionService:BindAction(
				"FarmAuraPowers",
				handleKey,
				false,
				KEYS[1],
				KEYS[2],
				KEYS[3],
				table.unpack(GAMEPAD)
			)
		else
			ContextActionService:UnbindAction("FarmAuraPowers")
		end
	end

	-- O servidor aceitou um disparo deste jogador: começa a contar a recarga.
	function powerBar.onCast(powerId: string)
		local power = Powers.byId[powerId]
		if power then
			readyAt[powerId] = os.clock() + power.cooldown
			refresh()
		end
	end

	return powerBar
end

return PowerBar
