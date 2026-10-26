--!strict
-- Tela de poderes (GDD: "Telas do MVP"): lista os 12 poderes para comprar, treinar (níveis 1 a 5) e
-- equipar até 3 para a arena. O servidor confere cada pedido; aqui é só o que o jogador vê.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Config.Arena)
local Bands = require(Shared.Config.Bands)
local Format = require(Shared.Format)
local PowerMath = require(Shared.PowerMath)
local Powers = require(Shared.Config.Powers)

local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)

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

type Row = { main: TextButton, train: TextButton, info: TextLabel }

local function button(parent: Instance, offset: number): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -offset, 0.5, 0)
	b.Size = UDim2.fromOffset(120, 40)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	corner(b, 10)
	return b
end

local function paint(b: TextButton, color: Color3, enabled: boolean)
	b.BackgroundColor3 = color
	b.AutoButtonColor = enabled
end

local PURPLE = Color3.fromRGB(150, 90, 255)
local DIM = Color3.fromRGB(90, 70, 130)
local GREY = Color3.fromRGB(90, 90, 100)
local GREEN = Color3.fromRGB(70, 160, 90)
local ORANGE = Color3.fromRGB(230, 140, 40)

function PowerShop.create(
	onBuy: (powerId: string) -> (),
	onEquip: (powerId: string) -> (),
	onTrain: (powerId: string) -> ()
)
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
	local owned: { [string]: boolean } = {}
	for index, power in Powers.list do
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(45, 38, 70)
		row.Parent = list
		corner(row, 10)

		text(row, {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -280, 0, 26),
			Text = power.name,
			TextColor3 = Powers.rarityColors[power.rarity],
		})
		local info = text(row, {
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -280, 0, 20),
			TextColor3 = Color3.fromRGB(190, 190, 210),
		})

		-- Botão principal: compra o poder ou, depois de comprado, equipa e tira.
		local main = button(row, 8)
		local train = button(row, 136)
		rows[power.id] = { main = main, train = train, info = info }

		main.Activated:Connect(function()
			if owned[power.id] then
				onEquip(power.id)
			else
				onBuy(power.id)
			end
		end)
		train.Activated:Connect(function()
			onTrain(power.id)
		end)
	end

	Panels.register(panel)
	toggle.Activated:Connect(function()
		Panels.toggle(panel)
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local shop = {}

	function shop.render(state: Hud.State)
		for _, power in Powers.list do
			local row = rows[power.id]
			local level = state.powers[power.id]
			local usable = PowerMath.isUsable(power, state.bandIndex)
			local cost = `{Format.short(power.shotCost)} por disparo`
			owned[power.id] = level ~= nil

			if not level then
				row.train.Visible = false
				row.main.Text = Format.short(power.price)
				local canBuy = usable and state.aura >= power.price
				paint(row.main, if canBuy then PURPLE elseif usable then DIM else GREY, canBuy)
				row.info.Text = if usable
					then `{power.rarity} · {power.model} · {cost}`
					else `{power.rarity} · {power.model} · faixa {Bands[power.band].name}`
				continue
			end

			local damage = Format.rate(PowerMath.damage(power, level))
			row.info.Text = if usable
				then `Nv {level} · dano {damage} · {cost}`
				else `Nv {level} · volta na faixa {Bands[power.band].name}`

			if table.find(state.equipped, power.id) then
				row.main.Text = "Equipado"
				paint(row.main, GREEN, true)
			elseif usable then
				row.main.Text = "Equipar"
				paint(row.main, PURPLE, #state.equipped < Arena.MaxEquipped)
			else
				row.main.Text = "Bloqueado"
				paint(row.main, GREY, false)
			end

			local trainCost = PowerMath.trainCost(power, level)
			row.train.Visible = true
			row.train.Text = if trainCost then `Treinar {Format.short(trainCost)}` else "Nv máx"
			local canTrain = trainCost ~= nil and state.aura >= trainCost
			paint(row.train, if canTrain then ORANGE elseif trainCost then DIM else GREY, canTrain)
		end
	end

	return shop
end

return PowerShop
