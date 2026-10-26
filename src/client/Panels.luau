--!strict
-- Telas centrais (Poderes, Danças, Rebirth) e os botões do menu da direita que abrem cada uma.
-- Abrir uma tela fecha as outras, para não ficarem uma em cima da outra.

local Panels = {}

local registered: { GuiObject } = {}

local MENU_SPACING = 56

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function Panels.register(panel: GuiObject)
	table.insert(registered, panel)
end

function Panels.toggle(panel: GuiObject)
	local open = not panel.Visible
	for _, other in registered do
		other.Visible = false
	end
	panel.Visible = open
end

-- Botão do menu da direita. `index` 0 é o de Poderes, no meio da altura da tela; os outros descem.
function Panels.menuButton(screen: Instance, text: string, color: Color3, index: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = text .. "Button"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, index * MENU_SPACING)
	button.Size = UDim2.fromOffset(110, 48)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.Parent = screen
	corner(button, 12)
	return button
end

-- Janela central com título e botão de fechar. Devolve a janela e a área de conteúdo abaixo do título.
function Panels.window(screen: Instance, title: string, maxSize: Vector2): (Frame, Frame)
	local panel = Instance.new("Frame")
	panel.Name = title
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0.75, 0)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = screen
	corner(panel, 14)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = maxSize
	sizeLimit.Parent = panel

	local heading = Instance.new("TextLabel")
	heading.Position = UDim2.fromOffset(16, 8)
	heading.Size = UDim2.new(1, -80, 0, 36)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.FredokaOne
	heading.TextScaled = true
	heading.TextColor3 = Color3.new(1, 1, 1)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = title
	heading.Parent = panel

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
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(12, 52)
	content.Size = UDim2.new(1, -24, 1, -64)
	content.BackgroundTransparency = 1
	content.Parent = panel

	Panels.register(panel)
	return panel, content
end

return Panels
