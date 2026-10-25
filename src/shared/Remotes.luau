--!strict
-- Ponto único para os remotes. O servidor cria a pasta; o cliente espera por ela.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"StateChanged", -- servidor -> cliente: snapshot do perfil para o HUD
	"UpgradeGenerator", -- cliente -> servidor: pedido para subir o gerador
	"Notify", -- servidor -> cliente: mensagem curta (ex.: aura offline recebida)
	"BuyPower", -- cliente -> servidor: comprar o poder de id dado
	"CloseGate", -- cliente -> servidor: fechar o portão do próprio lote
	"JoinArena", -- cliente -> servidor: entrar ou sair da fila da arena
	"ArenaState", -- servidor -> cliente: fase da rodada, fila, vivos e se o jogador está lutando
	"Attack", -- cliente -> servidor: golpe do ataque básico
	"Dodge", -- cliente -> servidor: esquiva (o avanço é feito no cliente)
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
