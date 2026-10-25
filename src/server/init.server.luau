--!strict
-- Ponto de entrada do servidor. A ordem importa: dados e lotes antes da aura, aura antes dos poderes e da arena.

local Services = script.Services

local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local AuraService = require(Services.AuraService)
local GateService = require(Services.GateService)
local PowerService = require(Services.PowerService)
local ArenaService = require(Services.ArenaService)
local CombatService = require(Services.CombatService)

DataService.start()
PlotService.start()
AuraService.start()
GateService.start()
PowerService.start()
ArenaService.start()
CombatService.start()

print("[Farm Aura] servidor pronto")
