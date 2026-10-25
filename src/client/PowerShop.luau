--!strict
-- Tela de poderes (GDD: "Telas do MVP"): lista os 12 poderes com faixa, preço e botão de comprar.
-- Treinar e equipar entram junto com o combate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bands = require(Shared.Config.Bands)
local Format = require(Shared.Format)
local Powers = require(Shared.Config.Powers)

local Hud = require(script.Parent.Hud)

local PowerShop = {}

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

type Row = { button: TextButton, status: TextLabel }

function PowerShop.create(onBuy: (powerId: string) -> ())
	local screen = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Hud")

	local toggle = Instance.new("TextButton")
	toggle.Name = "PowersButton"
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	toggle.Position = UDim2.new(1, -12, 0.5, 0)
	toggle.Size = UDim2.fromOffset(110, 48)
	toggle.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
	toggle.Font = Enum.Font.FredokaOne
	toggle.TextScaled = true
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Text = "Poderes"
	toggle.Parent = screen
	corner(toggle, 12)

	local panel = Instance.new("Frame")
	panel.Name = "PowerShop"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0.75, 0)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = screen
	corner(panel, 14)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(560, 520)
	sizeLimit.Parent = panel

	text(panel, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -80, 0, 36),
		Text = "Poderes",
	})

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(36, 36)
	close.BackgroundColor3 = Color3.fromRGB(200, 60, 80)
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Text = "X"
	close.Parent = panel
	corner(close, 8)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 52)
	list.Size = UDim2.new(1, -24, 1, -64)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local rows: { [string]: Row } = {}
	for index, power in Powers.list do
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(45, 38, 70)
		row.Parent = list
		corner(row, 10)

		text(row, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(0.6, -10, 0, 26),
			Text = power.name,
			TextColor3 = Powers.rarityColors[power.rarity],
		})
		text(row, {
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(0.6, -10, 0, 20),
			Text = `{power.rarity} · {power.model} · {Format.short(power.shotCost)} por disparo`,
			TextColor3 = Color3.fromRGB(190, 190, 210),
		})
		local status = text(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -150, 0, 16),
			Size = UDim2.fromOffset(110, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(190, 190, 210),
		})

		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -8, 0.5, 0)
		button.Size = UDim2.fromOffset(130, 40)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Parent = row
		corner(button, 10)
		button.Activated:Connect(function()
			onBuy(power.id)
		end)

		rows[power.id] = { button = button, status = status }
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local shop = {}

	function shop.render(state: Hud.State)
		for _, power in Powers.list do
			local row = rows[power.id]
			local owned = state.powers[power.id] ~= nil
			local bandOk = state.bandIndex >= power.band
			if owned then
				row.status.Text = "Na sua base"
				row.button.Text = "Comprado"
				row.button.BackgroundColor3 = Color3.fromRGB(70, 160, 90)
				row.button.AutoButtonColor = false
			elseif not bandOk then
				row.status.Text = "Faixa " .. Bands[power.band].name
				row.button.Text = Format.short(power.price)
				row.button.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
				row.button.AutoButtonColor = false
			else
				local canAfford = state.aura >= power.price
				row.status.Text = if canAfford then "Disponível" else "Falta aura"
				row.button.Text = Format.short(power.price)
				row.button.BackgroundColor3 = if canAfford
					then Color3.fromRGB(150, 90, 255)
					else Color3.fromRGB(90, 70, 130)
				row.button.AutoButtonColor = canAfford
			end
		end
	end

	return shop
end

return PowerShop
