--!strict
-- Ponto de entrada do cliente: liga os remotes ao HUD, à tela e à barra de poderes e à arena.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Hud = require(script.Hud)
local PowerShop = require(script.PowerShop)
local ArenaHud = require(script.ArenaHud)
local PowerBar = require(script.PowerBar)
local PowerFx = require(script.PowerFx)

local player = Players.LocalPlayer
local upgradeGenerator = Remotes.event("UpgradeGenerator")
local buyPower = Remotes.event("BuyPower")
local closeGate = Remotes.event("CloseGate")

local hud = Hud.create(function()
	upgradeGenerator:FireServer()
end, function()
	closeGate:FireServer()
end)
local shop = PowerShop.create(function(powerId)
	buyPower:FireServer(powerId)
end, function(powerId)
	Remotes.event("EquipPower"):FireServer(powerId)
end, function(powerId)
	Remotes.event("TrainPower"):FireServer(powerId)
end)
local powerBar = PowerBar.create(function(slot, aim)
	Remotes.event("UsePower"):FireServer(slot, aim)
end)
local arenaHud = ArenaHud.create(function()
	Remotes.event("JoinArena"):FireServer()
end, function()
	Remotes.event("Attack"):FireServer()
end, function()
	Remotes.event("Dodge"):FireServer()
end)
Remotes.event("ArenaState").OnClientEvent:Connect(function(state: ArenaHud.ArenaState)
	arenaHud.render(state)
	powerBar.setFighting(state.fighting)
end)
Remotes.event("PowerFx").OnClientEvent:Connect(function(cast: PowerFx.Cast)
	PowerFx.play(cast)
	if cast.caster == player then
		powerBar.onCast(cast.powerId)
	end
end)

Remotes.event("StateChanged").OnClientEvent:Connect(function(state: Hud.State)
	hud.render(state)
	shop.render(state)
	powerBar.render(state)
end)
Remotes.event("Notify").OnClientEvent:Connect(hud.toast)

-- O dono não vê o botão "Roubar" nas próprias caixas. O servidor também recusa, isto é só visual.
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Name ~= "StealPrompt" then
		return
	end
	local plot = prompt:FindFirstAncestorWhichIsA("Model")
	if plot and plot:GetAttribute("OwnerId") == player.UserId then
		prompt.Enabled = false
	end
end)
