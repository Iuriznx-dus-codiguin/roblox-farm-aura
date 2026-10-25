--!strict
-- Ponto de entrada do cliente: liga os remotes ao HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Hud = require(script.Hud)

local upgradeGenerator = Remotes.event("UpgradeGenerator")

local hud = Hud.create(function()
	upgradeGenerator:FireServer()
end)

Remotes.event("StateChanged").OnClientEvent:Connect(hud.render)
Remotes.event("Notify").OnClientEvent:Connect(hud.toast)
