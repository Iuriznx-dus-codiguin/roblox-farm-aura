--!strict
-- HUD do protótipo (GDD: "HUD sempre visível"): aura, faixa, aura por segundo, cofre e upgrade do gerador.
-- Fica no canto superior esquerdo e na parte de baixo, sem tapar o centro da tela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bands = require(Shared.Config.Bands)
local Format = require(Shared.Format)

export type State = {
	aura: number,
	vaultAura: number,
	pendingAura: number,
	peakAura: number,
	bandIndex: number,
	nextBandAura: number?,
	ratePerSecond: number,
	generatorLevel: number,
	upgradeCost: number?,
	powers: { [string]: number },
	hasShield: boolean,
	gateUntil: number,
	gateReadyAt: number,
}

local Hud = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, name: string, order: number, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, size)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextScaled = true
	l.Text = ""
	l.Parent = parent
	return l
end

local function clock(seconds: number): string
	local s = math.ceil(seconds)
	return string.format("%d:%02d", s // 60, s % 60)
end

function Hud.create(onUpgrade: () -> (), onCloseGate: () -> ())
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "Hud"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Stats"
	panel.Position = UDim2.fromOffset(12, 12)
	panel.Size = UDim2.fromOffset(240, 150)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	panel.BackgroundTransparency = 0.25
	panel.Parent = screen
	corner(panel, 12)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = panel

	local auraLabel = label(panel, "Aura", 1, 36)
	local bandLabel = label(panel, "Band", 2, 24)
	local progressLabel = label(panel, "Progress", 3, 18)
	local rateLabel = label(panel, "Rate", 4, 20)
	local vaultLabel = label(panel, "Vault", 5, 20)

	local upgrade = Instance.new("TextButton")
	upgrade.Name = "Upgrade"
	upgrade.AnchorPoint = Vector2.new(0.5, 1)
	upgrade.Position = UDim2.new(0.5, 0, 1, -16)
	upgrade.Size = UDim2.fromOffset(300, 56)
	upgrade.BackgroundColor3 = Color3.fromRGB(150, 90, 255)
	upgrade.Font = Enum.Font.FredokaOne
	upgrade.TextScaled = true
	upgrade.TextColor3 = Color3.new(1, 1, 1)
	upgrade.Text = "Melhorar gerador"
	upgrade.Parent = screen
	corner(upgrade, 14)
	upgrade.Activated:Connect(onUpgrade)

	local gate = Instance.new("TextButton")
	gate.Name = "Gate"
	gate.AnchorPoint = Vector2.new(0, 1)
	gate.Position = UDim2.new(0, 12, 1, -16)
	gate.Size = UDim2.fromOffset(170, 56)
	gate.BackgroundColor3 = Color3.fromRGB(220, 50, 70)
	gate.Font = Enum.Font.FredokaOne
	gate.TextScaled = true
	gate.TextColor3 = Color3.new(1, 1, 1)
	gate.Text = "Trancar lote"
	gate.Parent = screen
	corner(gate, 14)
	gate.Activated:Connect(onCloseGate)

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 12)
	toast.Size = UDim2.fromOffset(420, 40)
	toast.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	toast.BackgroundTransparency = 0.2
	toast.Font = Enum.Font.FredokaOne
	toast.TextScaled = true
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Visible = false
	toast.Parent = screen
	corner(toast, 10)

	local toastToken = 0

	local hud = {}

	function hud.render(state: State)
		local band = Bands[state.bandIndex]
		auraLabel.Text = "✨ " .. Format.short(state.aura)
		bandLabel.Text = "Faixa " .. band.name
		bandLabel.TextColor3 = band.color
		progressLabel.Text = if state.nextBandAura
			then `Pico {Format.short(state.peakAura)} / {Format.short(state.nextBandAura)}`
			else "Faixa máxima"
		rateLabel.Text = `+{Format.rate(state.ratePerSecond)}/s · gerador nv {state.generatorLevel}`
		vaultLabel.Text = "Cofre " .. Format.short(state.vaultAura)

		local now = workspace:GetServerTimeNow()
		if state.gateUntil > now then
			gate.Text = "Trancado " .. clock(state.gateUntil - now)
			gate.BackgroundTransparency = 0
		elseif state.gateReadyAt > now then
			gate.Text = "Recarga " .. clock(state.gateReadyAt - now)
			gate.BackgroundTransparency = 0.5
		else
			gate.Text = "Trancar lote"
			gate.BackgroundTransparency = 0
		end

		if state.upgradeCost then
			local canAfford = state.aura >= state.upgradeCost
			upgrade.Text = `Melhorar gerador ({Format.short(state.upgradeCost)})`
			upgrade.AutoButtonColor = canAfford
			upgrade.BackgroundTransparency = if canAfford then 0 else 0.5
		else
			upgrade.Text = "Gerador no máximo"
			upgrade.AutoButtonColor = false
			upgrade.BackgroundTransparency = 0.5
		end
	end

	function hud.toast(message: string)
		toastToken += 1
		local token = toastToken
		toast.Text = message
		toast.Visible = true
		task.delay(4, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end

	return hud
end

return Hud
