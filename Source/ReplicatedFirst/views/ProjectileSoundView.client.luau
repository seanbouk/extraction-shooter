--!strict

--[[
	ProjectileSoundView

	Observes replicated projectile state and plays weapon firing sounds
	for projectiles not originating from the local player (NPC and other
	player shots). Local player shots are handled by WeaponsFiringView.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Network"))
local WeaponsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponsConfig"))

local localPlayer = Players.LocalPlayer

local blastSoundTemplate: Sound = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BlastSound") :: Sound

-- Track previously seen projectile IDs to detect new ones
local knownProjectileIds: { [string]: boolean } = {}

-- Skip sounds on the first observation (existing projectiles when client joins)
local isFirstObservation = true

-- Projectiles originating within this radius of the local player are skipped
-- (already handled by WeaponsFiringView). Projectile origin is ~2 studs from
-- the player's HumanoidRootPart, so 5 studs gives comfortable margin.
local LOCAL_PLAYER_RADIUS = 5

local function getLocalPlayerPosition(): Vector3?
	local character = localPlayer.Character
	if not character then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end
	return rootPart.Position
end

local function playSoundAtPosition(weaponName: string, position: Vector3)
	local weaponStats = WeaponsConfig.weapons[weaponName]
	if not weaponStats or not weaponStats.sound then
		return
	end
	local cfg = weaponStats.sound

	local soundPart = Instance.new("Part")
	soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
	soundPart.Transparency = 1
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.CanTouch = false
	soundPart.CanQuery = false
	soundPart.CFrame = CFrame.new(position)
	soundPart.Parent = workspace

	local sound = blastSoundTemplate:Clone()
	sound.Volume = cfg.volume
	sound.PlaybackSpeed = cfg.playbackSpeed

	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = cfg.eqLow
	eq.MidGain = cfg.eqMid
	eq.HighGain = cfg.eqHigh
	eq.Parent = sound

	if cfg.reverb > 0 then
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = cfg.reverb * 3
		reverb.Density = cfg.reverb
		reverb.Diffusion = cfg.reverb
		reverb.Parent = sound
	end

	if cfg.echo > 0 then
		local echo = Instance.new("EchoSoundEffect")
		echo.Feedback = cfg.echo * 0.5
		echo.Delay = cfg.echo
		echo.Parent = sound
	end

	if cfg.chorus > 0 then
		local chorus = Instance.new("ChorusSoundEffect")
		chorus.Mix = cfg.chorus
		chorus.Rate = 1 + cfg.chorus * 3
		chorus.Depth = cfg.chorus * 0.5
		chorus.Parent = sound
	end

	if cfg.distortion > 0 then
		local distort = Instance.new("DistortionSoundEffect")
		distort.Level = cfg.distortion
		distort.Parent = sound
	end

	sound.Parent = soundPart
	sound:Play()

	Debris:AddItem(soundPart, sound.TimeLength / sound.PlaybackSpeed + 0.2)
end

Network.State.Projectiles:Observe(function(data)
	if not data or typeof(data) ~= "table" then
		knownProjectileIds = {}
		return
	end

	-- Skip the first observation to avoid playing sounds for pre-existing projectiles
	if isFirstObservation then
		isFirstObservation = false
		for entityId in data do
			knownProjectileIds[entityId] = true
		end
		return
	end

	local localPos = getLocalPlayerPosition()

	-- Deduplicate multi-projectile weapons (e.g. shotgun): one sound per burst
	local playedThisBatch: { [string]: boolean } = {}

	for entityId, projectile in data do
		if knownProjectileIds[entityId] then
			continue
		end
		knownProjectileIds[entityId] = true

		local origin = Vector3.new(projectile.originX, projectile.originY, projectile.originZ)

		-- Skip projectiles near the local player (handled by WeaponsFiringView)
		if localPos and (origin - localPos).Magnitude < LOCAL_PLAYER_RADIUS then
			continue
		end

		-- One sound per weapon per burst position
		local weaponName = projectile.weaponName
		local batchKey = weaponName
			.. "_" .. tostring(math.floor(origin.X))
			.. "_" .. tostring(math.floor(origin.Y))
			.. "_" .. tostring(math.floor(origin.Z))
		if playedThisBatch[batchKey] then
			continue
		end
		playedThisBatch[batchKey] = true

		playSoundAtPosition(weaponName, origin)
	end

	-- Clean up IDs for projectiles no longer in state
	for entityId in knownProjectileIds do
		if not data[entityId] then
			knownProjectileIds[entityId] = nil
		end
	end
end)
