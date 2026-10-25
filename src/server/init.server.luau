--!strict
-- Ponto de entrada do servidor. A ordem importa: dados e lotes antes da aura.

local Services = script.Services

local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local AuraService = require(Services.AuraService)

DataService.start()
PlotService.start()
AuraService.start()

print("[Farm Aura] servidor pronto")
