--!strict

--[[
	PickupSpawnerService

	Two responsibilities:

	1. Spawns pickups at "PickupSpawner"-tagged parts and respawns after cooldown.
	   Each spawner has attributes set in Studio:
	     Weapon   (string) – ammo type matching a key in WeaponsConfig
	     Ammo     (number) – amount of ammo the pickup grants
	     Cooldown (number) – seconds before respawning after collection

	2. Handles server-side collection of ALL "Pickup"-tagged instances (including
	   NPC death drops). When a player walks within range, awards ammo via
	   AmmoModel and destroys the pickup so it disappears for everyone.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AmmoModel = require(ServerScriptService.models.user.AmmoModel)

local PickupSpawnerService = {}

local SPAWNER_TAG = "PickupSpawner"
local PICKUP_TAG = "Pickup"
local COLLECTION_RADIUS = 8
local RESPAWN_CHECK_INTERVAL = 1

local pickupTemplate: Instance = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pickup")

type SpawnerState = {
	spawner: BasePart,
	pickup: Instance?,
	respawnAt: number?,
}

local spawnerStates: { SpawnerState } = {}
local spawnerByPickup: { [Instance]: SpawnerState } = {}

local isRunning = false

local function getPickupPosition(pickup: Instance): Vector3?
	if pickup:IsA("Model") then
		return pickup:GetPivot().Position
	elseif pickup:IsA("BasePart") then
		return pickup.Position
	end
	return nil
end

local function spawnPickup(state: SpawnerState): ()
	local spawner = state.spawner
	local weapon = spawner:GetAttribute("Weapon") :: string? or "Pistol"
	local ammo = spawner:GetAttribute("Ammo") :: number? or 1

	local pickup = pickupTemplate:Clone()
	pickup:SetAttribute("Weapon", weapon)
	pickup:SetAttribute("Amount", ammo)

	if pickup:IsA("Model") then
		pickup:PivotTo(CFrame.new(spawner.Position))
	else
		(pickup :: BasePart).Position = spawner.Position
	end

	CollectionService:AddTag(pickup, PICKUP_TAG)
	pickup.Parent = workspace

	state.pickup = pickup
	state.respawnAt = nil
	spawnerByPickup[pickup] = state
end

local function registerSpawner(spawner: BasePart): ()
	spawner.Transparency = 1

	local state: SpawnerState = {
		spawner = spawner,
		pickup = nil,
		respawnAt = nil,
	}
	table.insert(spawnerStates, state)
	spawnPickup(state)

	print(`[PickupSpawnerService] Registered spawner "{spawner.Name}" (Weapon={spawner:GetAttribute("Weapon")}, Ammo={spawner:GetAttribute("Ammo")}, Cooldown={spawner:GetAttribute("Cooldown")})`)
end

local function collectPickup(pickup: Instance, player: Player): ()
	local weaponName = pickup:GetAttribute("Weapon")
	local amount = pickup:GetAttribute("Amount")

	if typeof(weaponName) == "string" and typeof(amount) == "number" then
		local ammoType = string.lower(weaponName)
		local ammo = AmmoModel.get(tostring(player.UserId))
		if ammo then
			ammo:addAmmo(ammoType :: AmmoModel.AmmoType, amount)
			print(`[PickupSpawnerService] {player.Name} collected {amount} {ammoType} ammo`)
		end
	end

	-- If this was a spawner pickup, start cooldown
	local spawnerState = spawnerByPickup[pickup]
	if spawnerState then
		local cooldown = spawnerState.spawner:GetAttribute("Cooldown") :: number? or 10
		spawnerState.respawnAt = os.clock() + cooldown
		spawnerState.pickup = nil
		spawnerByPickup[pickup] = nil
	end

	pickup:Destroy()
end

-- Server-side collection: check all pickups for player proximity every frame
local function checkCollection(): ()
	local pickups = CollectionService:GetTagged(PICKUP_TAG)
	if #pickups == 0 then
		return
	end

	-- Build player position list once
	type PlayerPos = { player: Player, position: Vector3 }
	local playerPositions: { PlayerPos } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		table.insert(playerPositions, { player = player, position = root.Position })
	end
	if #playerPositions == 0 then
		return
	end

	for _, pickup in pickups do
		local pickupPos = getPickupPosition(pickup)
		if not pickupPos then
			continue
		end

		for _, pp in playerPositions do
			if (pp.position - pickupPos).Magnitude <= COLLECTION_RADIUS then
				collectPickup(pickup, pp.player)
				break -- one player collects
			end
		end
	end
end

-- Check spawner cooldowns for respawning
local function checkRespawns(): ()
	local now = os.clock()
	for _, state in spawnerStates do
		if state.spawner.Parent == nil then
			continue
		end
		if not state.pickup and state.respawnAt and now >= state.respawnAt then
			spawnPickup(state)
		end
	end
end

local function startRespawnLoop()
	if isRunning then
		return
	end
	isRunning = true

	task.spawn(function()
		while true do
			checkRespawns()
			task.wait(RESPAWN_CHECK_INTERVAL)
		end
	end)
end

function PickupSpawnerService.init()
	print("[PickupSpawnerService] Initializing...")

	for _, spawner in CollectionService:GetTagged(SPAWNER_TAG) do
		if spawner:IsA("BasePart") then
			registerSpawner(spawner)
		end
	end

	CollectionService:GetInstanceAddedSignal(SPAWNER_TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			registerSpawner(instance)
		end
	end)

	RunService.Heartbeat:Connect(checkCollection)
	startRespawnLoop()
end

return PickupSpawnerService
