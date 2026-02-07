--!strict

--[[
	PickupView

	Client-side view that makes "Pickup"-tagged instances spin around the Y axis,
	scales them by Amount, and shows the weapon icon.
	Plays a collection sound when a pickup is destroyed (collected server-side).

	Collection is handled entirely server-side by PickupSpawnerService.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local WeaponsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponsConfig"))

local SPIN_SPEED = math.rad(180) -- 180 deg/sec, full rotation every 2 seconds
local BASE_PICKUP_AMOUNT = 5
local SOUND_RANGE = 20

local pickupSound: Sound = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("PickupSound") :: Sound

local view = AbstractView.new("PickupView", "Pickup")

type TrackedPickup = {
	instance: Instance,
	pivot: CFrame,
}

local pickups: { TrackedPickup } = {}

-- Track the local player's HumanoidRootPart for collection sound
local player = Players.LocalPlayer
local rootPart: BasePart? = nil

local function onCharacterAdded(character: Model)
	rootPart = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
end

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(function()
	rootPart = nil
end)

local function updatePickupIcon(instance: Instance, weaponName: string)
	local stats = WeaponsConfig.weapons[weaponName]
	local icon = if stats then stats.icon else ""
	for _, desc in instance:GetDescendants() do
		if desc:IsA("SurfaceGui") then
			for _, child in desc:GetChildren() do
				if child:IsA("TextLabel") then
					child.Text = icon
				end
			end
		end
	end
end

local function setupPickup(instance: Instance)
	local entry: TrackedPickup

	local randomYaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)

	if instance:IsA("BasePart") then
		entry = {
			instance = instance,
			pivot = instance.CFrame * randomYaw,
		}
	elseif instance:IsA("Model") then
		entry = {
			instance = instance,
			pivot = instance:GetPivot() * randomYaw,
		}
	else
		warn(`PickupView: {instance.Name} is not a BasePart or Model`)
		return
	end

	table.insert(pickups, entry)

	local amount = instance:GetAttribute("Amount")
	if typeof(amount) == "number" then
		local scale = math.sqrt(amount / BASE_PICKUP_AMOUNT)
		if instance:IsA("BasePart") then
			instance.Size = instance.Size * scale
		elseif instance:IsA("Model") then
			(instance :: Model):ScaleTo(scale)
		end
		for _, desc in instance:GetDescendants() do
			if desc:IsA("SurfaceGui") then
				desc.PixelsPerStud = desc.PixelsPerStud / scale
			end
		end
	end

	local weaponName = instance:GetAttribute("Weapon")
	if typeof(weaponName) == "string" then
		updatePickupIcon(instance, weaponName)
	end
	instance:GetAttributeChangedSignal("Weapon"):Connect(function()
		local newWeapon = instance:GetAttribute("Weapon")
		if typeof(newWeapon) == "string" then
			updatePickupIcon(instance, newWeapon)
		end
	end)
end

RunService.Heartbeat:Connect(function(dt: number)
	local angle = SPIN_SPEED * dt
	local currentRoot = rootPart

	local i = 1
	while i <= #pickups do
		local pickup = pickups[i]

		-- Remove destroyed instances via swap-remove
		if pickup.instance.Parent == nil then
			-- Play collection sound if local player is nearby
			if currentRoot and currentRoot.Parent then
				local lastPos = pickup.pivot.Position
				if (currentRoot.Position - lastPos).Magnitude <= SOUND_RANGE then
					local sound = pickupSound:Clone()
					sound.Parent = currentRoot
					sound:Play()
					Debris:AddItem(sound, sound.TimeLength + 0.1)
				end
			end

			pickups[i] = pickups[#pickups]
			pickups[#pickups] = nil :: any
			continue
		end

		-- Spin the pickup
		pickup.pivot = pickup.pivot * CFrame.Angles(0, angle, 0)
		if pickup.instance:IsA("BasePart") then
			pickup.instance.CFrame = pickup.pivot
		elseif pickup.instance:IsA("Model") then
			pickup.instance:PivotTo(pickup.pivot)
		end

		i += 1
	end
end)

view:initialize(setupPickup)
