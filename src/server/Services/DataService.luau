--!strict
-- Perfil do jogador no DataStore (GDD: "Dados").
-- Carrega com trava de sessão para dois servidores não editarem o mesmo perfil, salva a cada 2 minutos,
-- ao sair e quando o servidor fecha. Sem acesso ao DataStore (Studio sem API Services), usa memória.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_SECONDS = 120
local LOCK_EXPIRE_SECONDS = 30 * 60
local LOAD_ATTEMPTS = 5
local RETRY_DELAY = 2

export type Profile = {
	version: number,
	aura: number, -- aura carregada (pode ser gasta e perdida na arena)
	vaultAura: number, -- aura guardada no cofre do lote
	pendingAura: number, -- aura no coletor do gerador, ainda não coletada
	peakAura: number, -- pico desde a última derrota ou rebirth; define a faixa
	generatorLevel: number,
	rebirths: number,
	powers: { [string]: number }, -- id do poder -> nível
	equipped: { string },
	dances: { string },
	activeDance: string?,
	achievements: { [string]: boolean },
	minutesPlayed: number,
	lastLogout: number,
	lastPowerLostAt: number, -- os.time() do último poder roubado deste jogador
	-- Contadores das conquistas (ver Config/Dances)
	collected: number, -- aura total já coletada do gerador
	arenaKills: number, -- derrotas causadas na arena
	arenaWinStreak: number, -- rodadas de arena vencidas seguidas
}

local function newProfile(): Profile
	return {
		version = 1,
		aura = 0,
		vaultAura = 0,
		pendingAura = 0,
		peakAura = 0,
		generatorLevel = 1,
		rebirths = 0,
		powers = {},
		equipped = {},
		dances = {},
		activeDance = nil,
		achievements = {},
		minutesPlayed = 0,
		lastLogout = 0,
		lastPowerLostAt = 0,
		collected = 0,
		arenaKills = 0,
		arenaWinStreak = 0,
	}
end

-- Completa campos que faltam em perfis salvos por versões antigas.
local function reconcile(saved: any): Profile
	local profile = newProfile() :: any
	if type(saved) == "table" then
		for key, value in saved do
			profile[key] = value
		end
	end
	return profile
end

type Record = {
	profile: Profile,
	lock: { jobId: string, time: number }?,
}

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local loadedSignal = Instance.new("BindableEvent")
local sessionId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function tryGetStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		warn("[DataService] DataStore indisponível, usando memória:", result)
		return
	end
	-- No Studio sem "Enable Studio Access to API Services" o GetDataStore funciona, mas toda leitura falha.
	if RunService:IsStudio() then
		local probeOk, probeErr = pcall(function()
			result:GetAsync("studio_probe")
		end)
		if not probeOk then
			warn("[DataService] Studio sem acesso ao DataStore, usando memória:", probeErr)
			return
		end
	end
	store = result
end

local function loadProfile(player: Player): Profile?
	local ds = store
	if not ds then
		return newProfile()
	end

	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return ds:UpdateAsync(keyFor(player), function(old: Record?)
				local now = os.time()
				local lock = old and old.lock
				-- Outro servidor ainda segura o perfil: espera e tenta de novo, a menos que a trava tenha expirado
				-- ou esta seja a última tentativa (aí assumimos que o outro servidor caiu).
				if lock and lock.jobId ~= sessionId and now - lock.time < LOCK_EXPIRE_SECONDS then
					if attempt < LOAD_ATTEMPTS then
						lockedElsewhere = true
						return nil
					end
				end
				return {
					profile = reconcile(old and old.profile),
					lock = { jobId = sessionId, time = now },
				}
			end)
		end)

		if ok and result and not lockedElsewhere then
			return (result :: Record).profile
		end
		if not ok then
			warn(`[DataService] falha ao carregar {player.Name} (tentativa {attempt}):`, result)
		end
		task.wait(RETRY_DELAY * attempt)
		if not player.Parent then
			return nil
		end
	end
	return nil
end

local function saveProfile(player: Player, release: boolean)
	local ds = store
	local profile = profiles[player]
	if not ds or not profile then
		return
	end
	if release then
		profile.lastLogout = os.time()
	end

	local ok, err = pcall(function()
		ds:UpdateAsync(keyFor(player), function(old: Record?)
			local lock = old and old.lock
			if lock and lock.jobId ~= sessionId then
				-- Outro servidor tomou o perfil; não sobrescreve.
				return nil
			end
			return {
				profile = profile,
				lock = if release then nil else { jobId = sessionId, time = os.time() },
			}
		end)
	end)
	if not ok then
		warn(`[DataService] falha ao salvar {player.Name}:`, err)
	end
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

-- Espera o perfil carregar (ou o jogador sair). Retorna nil se o jogador saiu antes.
function DataService.waitFor(player: Player): Profile?
	while player.Parent and not profiles[player] do
		loadedSignal.Event:Wait()
	end
	return profiles[player]
end

-- Salva fora do ciclo de 2 minutos (GDD: após cada compra, roubo de poder e abate).
function DataService.saveNow(player: Player)
	task.spawn(saveProfile, player, false)
end

function DataService.onLoaded(callback: (Player, Profile) -> ())
	loadedSignal.Event:Connect(function(player: Player)
		local profile = profiles[player]
		if profile then
			callback(player, profile)
		end
	end)
end

local function onPlayerAdded(player: Player)
	local profile = loadProfile(player)
	if not player.Parent then
		return
	end
	if not profile then
		player:Kick("Não foi possível carregar seus dados. Tente entrar de novo em alguns minutos.")
		return
	end
	profiles[player] = profile
	loadedSignal:Fire(player)
end

local beforeRelease: { (Player, Profile) -> () } = {}

-- Roda antes do último save de quem está saindo (ex.: a arena conta a desconexão como derrota).
function DataService.beforeRelease(callback: (Player, Profile) -> ())
	table.insert(beforeRelease, callback)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		for _, callback in beforeRelease do
			local ok, err = pcall(function()
				callback(player, profile)
			end)
			if not ok then
				warn("[DataService] beforeRelease falhou:", err)
			end
		end
		saveProfile(player, true)
		profiles[player] = nil
	end
	loadedSignal:Fire(player)
end

function DataService.start()
	tryGetStore()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

return DataService
