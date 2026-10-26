--!strict
-- Botão da arena (GDD: HUD sempre visível) e controles de combate enquanto o jogador está lutando:
-- clique/toque ataca, Q (ou o botão na tela) esquiva.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Config.Arena)

local Push = require(script.Parent.Push)

export type ArenaState = {
	phase: "waiting" | "countdown" | "running",
	endsAt: number,
	queued: boolean,
	queueCount: number,
	minPlayers: number,
	alive: number,
	fighting: boolean,
}

local ArenaHud = {}

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function ArenaHud.create(onJoin: () -> (), onAttack: () -> (), onDodge: () -> ())
	local player = Players.LocalPlayer
	local screen = player:WaitForChild("PlayerGui"):WaitForChild("Hud")

	local button = Instance.new("TextButton")
	button.Name = "ArenaButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -12, 1, -16)
	button.Size = UDim2.fromOffset(150, 56)
	button.BackgroundColor3 = Color3.fromRGB(170, 60, 255)
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "Arena"
	button.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = button
	button.Activated:Connect(onJoin)

	local status = Instance.new("TextLabel")
	status.Name = "ArenaStatus"
	status.AnchorPoint = Vector2.new(1, 1)
	status.Position = UDim2.new(1, -12, 1, -78)
	status.Size = UDim2.fromOffset(220, 26)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.FredokaOne
	status.TextScaled = true
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextStrokeTransparency = 0.4
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Text = ""
	status.Parent = screen

	local current: ArenaState? = nil
	local controlsBound = false
	local lastDodge = -math.huge

	local function dash()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			return
		end
		local direction = humanoid.MoveDirection
		if direction.Magnitude < 0.1 then
			direction = root.CFrame.LookVector
		end
		local flat = Vector3.new(direction.X, 0, direction.Z).Unit
		Push.horizontal(root, flat * Arena.Dodge.DashSpeed, Arena.Dodge.DashSeconds)
	end

	local function handleAttack(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			onAttack()
		end
		return Enum.ContextActionResult.Pass
	end

	local function handleDodge(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin and os.clock() - lastDodge >= Arena.Dodge.Cooldown then
			lastDodge = os.clock()
			dash()
			onDodge()
		end
		return Enum.ContextActionResult.Sink
	end

	local function setControls(enabled: boolean)
		if enabled == controlsBound then
			return
		end
		controlsBound = enabled
		if enabled then
			ContextActionService:BindAction(
				"FarmAuraAttack",
				handleAttack,
				true,
				Enum.UserInputType.MouseButton1,
				Enum.KeyCode.ButtonR2
			)
			ContextActionService:BindAction(
				"FarmAuraDodge",
				handleDodge,
				true,
				Enum.KeyCode.Q,
				Enum.KeyCode.ButtonB
			)
			ContextActionService:SetTitle("FarmAuraAttack", "Atacar")
			ContextActionService:SetTitle("FarmAuraDodge", "Esquivar")
		else
			ContextActionService:UnbindAction("FarmAuraAttack")
			ContextActionService:UnbindAction("FarmAuraDodge")
		end
	end

	local function refresh()
		local state = current
		if not state then
			return
		end
		local remaining = state.endsAt - workspace:GetServerTimeNow()
		if state.fighting then
			status.Text = `Arena {clock(remaining)} · {state.alive} vivos`
			button.Visible = false
		elseif state.queued then
			button.Visible = true
			button.Text = "Sair da fila"
			if state.phase == "countdown" then
				status.Text = `Começa em {clock(remaining)}`
			elseif state.phase == "running" then
				status.Text = `Na fila · rodada acaba em {clock(remaining)}`
			else
				status.Text = `Na fila ({state.queueCount}/{state.minPlayers})`
			end
		else
			button.Visible = true
			button.Text = "Arena"
			status.Text = if state.phase == "running" then `Rodada rolando · {state.alive} vivos` else ""
		end
		setControls(state.fighting)
	end

	task.spawn(function()
		while true do
			task.wait(0.5)
			refresh()
		end
	end)

	local hud = {}

	function hud.render(state: ArenaState)
		current = state
		refresh()
	end

	return hud
end

return ArenaHud
