--!strict

--[[
	WeaponsFiringView

	Handles client-side weapon firing input. Detects mouse clicks and touch taps,
	raycasts to find the 3D target position, and fires the weapon intent to the server.
	Reads the currently selected weapon from the WeaponSelectedEvent (BindableEvent).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))
local WeaponsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponsConfig"))

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local blastSoundTemplate: Sound = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("BlastSound") :: Sound

local view = AbstractView.new("WeaponsFiringView", "WeaponsFiringView")

local selectedWeapon: string? = nil

-- Track selected weapon from WeaponSelectorView's event
local weaponSelectedEvent = view:getEvent("WeaponSelectedEvent")
if weaponSelectedEvent then
	weaponSelectedEvent.Event:Connect(function(weaponName: string)
		selectedWeapon = weaponName
	end)
end

local RAYCAST_DISTANCE = 1000

local function getTargetPosition(screenPosition: Vector2): Vector3?
	local character = localPlayer.Character
	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end

	-- input.Position is in screen space — ScreenPointToRay expects screen space
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(ray.Origin, ray.Direction * RAYCAST_DISTANCE, raycastParams)
	local hitPosition = if result then result.Position else ray.Origin + ray.Direction * RAYCAST_DISTANCE

	-- Project far from the player so server-side position drift can't flip the direction
	local direction = (hitPosition - rootPart.Position).Unit
	local farTarget = rootPart.Position + direction * RAYCAST_DISTANCE

	print(string.format(
		"[VIEW] screen=(%.0f,%.0f) rayOrigin=(%.1f,%.1f,%.1f) rayDir=(%.2f,%.2f,%.2f) hit=%s hitPos=(%.1f,%.1f,%.1f) playerPos=(%.1f,%.1f,%.1f) dir=(%.2f,%.2f,%.2f)",
		screenPosition.X, screenPosition.Y,
		ray.Origin.X, ray.Origin.Y, ray.Origin.Z,
		ray.Direction.X, ray.Direction.Y, ray.Direction.Z,
		if result then result.Instance.Name else "NONE",
		hitPosition.X, hitPosition.Y, hitPosition.Z,
		rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z,
		direction.X, direction.Y, direction.Z
	))

	return farTarget
end

local isHolding = false

local function playFireSound(weaponName: string)
	local character = localPlayer.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local weaponStats = WeaponsConfig.weapons[weaponName]
	if not weaponStats or not weaponStats.sound then
		return
	end
	local cfg = weaponStats.sound

	-- Create a small invisible anchored part at the player position for 3D sound
	local soundPart = Instance.new("Part")
	soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
	soundPart.Transparency = 1
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.CanTouch = false
	soundPart.CanQuery = false
	soundPart.CFrame = rootPart.CFrame
	soundPart.Parent = workspace

	-- Clone sound and apply weapon config
	local sound = blastSoundTemplate:Clone()
	sound.Volume = cfg.volume
	sound.PlaybackSpeed = cfg.playbackSpeed

	-- EQ is always added
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = cfg.eqLow
	eq.MidGain = cfg.eqMid
	eq.HighGain = cfg.eqHigh
	eq.Parent = sound

	-- Reverb (only if > 0)
	if cfg.reverb > 0 then
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = cfg.reverb * 3
		reverb.Density = cfg.reverb
		reverb.Diffusion = cfg.reverb
		reverb.Parent = sound
	end

	-- Echo (only if > 0)
	if cfg.echo > 0 then
		local echo = Instance.new("EchoSoundEffect")
		echo.Feedback = cfg.echo * 0.5
		echo.Delay = cfg.echo
		echo.Parent = sound
	end

	-- Chorus (only if > 0)
	if cfg.chorus > 0 then
		local chorus = Instance.new("ChorusSoundEffect")
		chorus.Mix = cfg.chorus
		chorus.Rate = 1 + cfg.chorus * 3
		chorus.Depth = cfg.chorus * 0.5
		chorus.Parent = sound
	end

	-- Distortion (only if > 0)
	if cfg.distortion > 0 then
		local distort = Instance.new("DistortionSoundEffect")
		distort.Level = cfg.distortion
		distort.Parent = sound
	end

	sound.Parent = soundPart
	sound:Play()

	-- Self-destruct after playback finishes
	Debris:AddItem(soundPart, sound.TimeLength / sound.PlaybackSpeed + 0.2)
end

local function fireWeapon(screenPos: Vector2)
	if not selectedWeapon then
		return
	end

	local targetPosition = getTargetPosition(screenPos)
	if not targetPosition then
		return
	end

	playFireSound(selectedWeapon)
	Network.Intent.Weapons:FireServer(Network.Actions.Weapons.Fire, selectedWeapon, targetPosition)
end

local function isFiringInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if not selectedWeapon then
		return
	end

	if not isFiringInput(input) then
		return
	end

	local screenPos = Vector2.new(input.Position.X, input.Position.Y)
	fireWeapon(screenPos)

	local weaponStats = WeaponsConfig.weapons[selectedWeapon]
	if weaponStats and weaponStats.auto > 0 then
		isHolding = true
		local heldWeapon = selectedWeapon
		task.spawn(function()
			while isHolding and selectedWeapon == heldWeapon do
				task.wait(weaponStats.auto)
				if not isHolding or selectedWeapon ~= heldWeapon then
					break
				end
				local currentPos = UserInputService:GetMouseLocation()
				fireWeapon(currentPos)
			end
		end)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
	if isFiringInput(input) then
		isHolding = false
	end
end)
