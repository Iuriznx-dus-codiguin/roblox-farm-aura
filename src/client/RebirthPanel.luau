--!strict
-- Tela Rebirth (GDD: "Rebirth"): quanto custa, o que zera, o que fica e o bônus de geração depois.
-- O botão pede confirmação com um segundo toque, porque o rebirth zera a aura. O servidor confere tudo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Format)

local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)

local TEAL = Color3.fromRGB(40, 190, 170)
local GREY = Color3.fromRGB(90, 90, 100)
local ORANGE = Color3.fromRGB(230, 140, 40)
local CONFIRM_SECONDS = 3

local RebirthPanel = {}

local function line(parent: Instance, order: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, 26)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local function bonusText(rebirths: number): string
	return `+{math.round(rebirths * Economy.Rebirth.BonusPerRebirth * 100)}%`
end

function RebirthPanel.create(onRebirth: () -> ())
	local screen = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud")

	local toggle = Panels.menuButton(screen, "Rebirth", TEAL, 2)
	local panel, content = Panels.window(screen, "Rebirth", Vector2.new(480, 340))
	toggle.Activated:Connect(function()
		Panels.toggle(panel)
	end)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = content

	local soft = Color3.fromRGB(190, 190, 210)
	local current = line(content, 1, Color3.new(1, 1, 1))
	local cost = line(content, 2, Color3.new(1, 1, 1))
	local resets = line(content, 3, soft)
	resets.Text = "Zera: aura, cofre, coletor e faixa"
	local keeps = line(content, 4, soft)
	keeps.Text = "Fica: nível do gerador, poderes na base e danças"
	local after = line(content, 5, TEAL)

	local confirm = Instance.new("TextButton")
	confirm.LayoutOrder = 6
	confirm.Size = UDim2.new(1, 0, 0, 48)
	confirm.Font = Enum.Font.FredokaOne
	confirm.TextScaled = true
	confirm.TextColor3 = Color3.new(1, 1, 1)
	confirm.Parent = content
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = confirm

	local canRebirth = false
	local armedUntil = 0

	local function paintButton()
		if not canRebirth then
			confirm.Text = "Falta aura"
			confirm.BackgroundColor3 = GREY
		elseif os.clock() < armedUntil then
			confirm.Text = "Toque de novo para confirmar"
			confirm.BackgroundColor3 = ORANGE
		else
			confirm.Text = "Fazer rebirth"
			confirm.BackgroundColor3 = TEAL
		end
	end

	confirm.Activated:Connect(function()
		if not canRebirth then
			return
		end
		if os.clock() < armedUntil then
			armedUntil = 0
			onRebirth()
		else
			armedUntil = os.clock() + CONFIRM_SECONDS
			task.delay(CONFIRM_SECONDS, paintButton)
		end
		paintButton()
	end)

	local rebirthPanel = {}

	function rebirthPanel.render(state: Hud.State)
		current.Text = `Rebirths feitos: {state.rebirths} · geração {bonusText(state.rebirths)}`
		cost.Text = `Precisa de {Format.short(state.rebirthCost)} de aura carregada (você tem {Format.short(
			state.aura
		)})`
		after.Text = `Depois do próximo: geração {bonusText(state.rebirths + 1)} para sempre`
		canRebirth = state.aura >= state.rebirthCost
		paintButton()
	end

	return rebirthPanel
end

return RebirthPanel
