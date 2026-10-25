--!strict
-- Ponto de entrada do cliente: liga os remotes ao HUD e à tela de poderes.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Hud = require(script.Hud)
local PowerShop = require(script.PowerShop)

local player = Players.LocalPlayer
local upgradeGenerator = Remotes.event("UpgradeGenerator")
local buyPower = Remotes.event("BuyPower")

local hud = Hud.create(function()
	upgradeGenerator:FireServer()
end)
local shop = PowerShop.create(function(powerId)
	buyPower:FireServer(powerId)
end)

Remotes.event("StateChanged").OnClientEvent:Connect(function(state: Hud.State)
	hud.render(state)
	shop.render(state)
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
