--!strict
-- Tela Danças (GDD: "Danças e conquistas"): as 5 danças, a conquista que libera cada uma e o progresso.
-- O botão Dançar fica embaixo à esquerda: a dança só dá bônus no próprio lote e andar para a dança.
-- A animação toca neste cliente e o Roblox replica para os outros jogadores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dances = require(Shared.Config.Dances)
local Format = require(Shared.Format)

local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)

local PINK = Color3.fromRGB(255, 90, 170)
local PURPLE = Color3.fromRGB(150, 90, 255)
local GREY = Color3.fromRGB(90, 90, 100)
local GREEN = Color3.fromRGB(70, 160, 90)
local RED = Color3.fromRGB(200, 60, 80)

type Row = { info: TextLabel, button: TextButton }

local DancePanel = {}

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
	l.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function percent(bonus: number): string
	return `+{math.round(bonus * 100)}%`
end

function DancePanel.create(onSelect: (danceId: string) -> (), onDance: (wants: boolean) -> ())
	local player = Players.LocalPlayer
	local screen = player:WaitForChild("PlayerGui"):WaitForChild("Hud")

	local toggle = Panels.menuButton(screen, "Danças", PINK, 1)
	local panel, content = Panels.window(screen, "Danças", Vector2.new(560, 460))
	toggle.Activated:Connect(function()
		Panels.toggle(panel)
	end)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = content

	local rows: { [string]: Row } = {}
	for index, dance in Dances.list do
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(45, 38, 70)
		row.Parent = content
		corner(row, 10)

		text(row, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -150, 0, 26),
			Text = `{dance.name} · geração {percent(dance.bonus)}`,
			TextColor3 = PINK,
		})
		local info = text(row, {
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -150, 0, 20),
			TextColor3 = Color3.fromRGB(190, 190, 210),
		})

		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -8, 0.5, 0)
		button.Size = UDim2.fromOffset(120, 40)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Parent = row
		corner(button, 10)
		button.Activated:Connect(function()
			onSelect(dance.id)
		end)

		rows[dance.id] = { info = info, button = button }
	end

	-- Botão Dançar / Parar, acima do botão do portão.
	local danceButton = Instance.new("TextButton")
	danceButton.Name = "DanceButton"
	danceButton.AnchorPoint = Vector2.new(0, 1)
	danceButton.Position = UDim2.new(0, 12, 1, -80)
	danceButton.Size = UDim2.fromOffset(170, 48)
	danceButton.Font = Enum.Font.FredokaOne
	danceButton.TextScaled = true
	danceButton.TextColor3 = Color3.new(1, 1, 1)
	danceButton.Parent = screen
	corner(danceButton, 14)

	local dancing: string? = nil
	local hasDance = false
	local track: AnimationTrack? = nil
	local playingId: string? = nil

	local function stopTrack()
		local current = track
		if current then
			current:Stop(0.2)
			task.delay(0.3, function()
				current:Destroy()
			end)
		end
		track = nil
		playingId = nil
	end

	local function play(danceId: string)
		if playingId == danceId then
			return
		end
		stopTrack()
		local dance = Dances.byId[danceId]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not dance or not animator then
			return
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = dance.animationId
		local loaded = animator:LoadAnimation(animation)
		loaded.Looped = true
		loaded.Priority = Enum.AnimationPriority.Action
		loaded:Play(0.2)
		track = loaded
		playingId = danceId
	end

	player.CharacterAdded:Connect(function()
		track = nil
		playingId = nil
	end)

	-- Andar para a dança na hora; o servidor também para quando o personagem sai do lugar.
	RunService.Heartbeat:Connect(function()
		if not dancing then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
			dancing = nil
			stopTrack()
			onDance(false)
		end
	end)

	danceButton.Activated:Connect(function()
		if hasDance then
			onDance(dancing == nil)
		end
	end)

	local dancePanel = {}

	function dancePanel.render(state: Hud.State)
		dancing = state.dancing
		hasDance = state.activeDance ~= nil
		if dancing then
			play(dancing)
		else
			stopTrack()
		end

		local active = if state.activeDance then Dances.byId[state.activeDance] else nil
		if dancing and active then
			danceButton.Text = `Parar {active.name}`
			danceButton.BackgroundColor3 = RED
		elseif active then
			danceButton.Text = `Dançar {percent(active.bonus)}`
			danceButton.BackgroundColor3 = PINK
		else
			danceButton.Text = "Sem dança"
			danceButton.BackgroundColor3 = GREY
		end

		for _, dance in Dances.list do
			local row = rows[dance.id]
			local achievement = dance.achievement
			local unlocked = table.find(state.dances, dance.id) ~= nil
			if unlocked then
				row.info.Text = `Liberada: {achievement.description}`
			else
				local value = math.min(state.stats[achievement.stat] or 0, achievement.goal)
				row.info.Text =
					`{achievement.description} ({Format.short(value)}/{Format.short(achievement.goal)})`
			end
			if not unlocked then
				row.button.Text = "Bloqueada"
				row.button.BackgroundColor3 = GREY
				row.button.AutoButtonColor = false
			elseif state.activeDance == dance.id then
				row.button.Text = "Ativa"
				row.button.BackgroundColor3 = GREEN
				row.button.AutoButtonColor = false
			else
				row.button.Text = "Usar"
				row.button.BackgroundColor3 = PURPLE
				row.button.AutoButtonColor = true
			end
		end
	end

	return dancePanel
end

return DancePanel
