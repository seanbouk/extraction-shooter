--!strict

--[[
	PickupView

	Client-side view that makes "Pickup"-tagged instances spin around the Y axis
	and destroys them when the local player walks within collection range.
	Supports both BasePart and Model instances.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local WeaponsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponsConfig"))

local SPIN_SPEED = math.rad(180) -- 180 deg/sec, full rotation every 2 seconds
local COLLECTION_RADIUS = 8 -- studs

local pickupSound: Sound = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("PickupSound") :: Sound

local view = AbstractView.new("PickupView", "Pickup")

type TrackedPickup = {
	instance: Instance,
	pivot: CFrame,
	getPosition: (Instance) -> Vector3,
}

local pickups: { TrackedPickup } = {}
local rootPart: BasePart? = nil

-- Track the local player's HumanoidRootPart
local player = Players.LocalPlayer

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
			getPosition = function(inst: Instance)
				return (inst :: BasePart).Position
			end,
		}
	elseif instance:IsA("Model") then
		entry = {
			instance = instance,
			pivot = instance:GetPivot() * randomYaw,
			getPosition = function(inst: Instance)
				return (inst :: Model):GetPivot().Position
			end,
		}
	else
		warn(`PickupView: {instance.Name} is not a BasePart or Model`)
		return
	end

	table.insert(pickups, entry)

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

		-- Collection distance check
		if currentRoot and currentRoot.Parent then
			local pickupPos = pickup.getPosition(pickup.instance)
			local distance = (currentRoot.Position - pickupPos).Magnitude
			if distance <= COLLECTION_RADIUS then
				-- Enter collected state: hide the pickup visually
				if pickup.instance:IsA("BasePart") then
					pickup.instance.Transparency = 1
				elseif pickup.instance:IsA("Model") then
					for _, desc in pickup.instance:GetDescendants() do
						if desc:IsA("BasePart") then
							desc.Transparency = 1
						end
					end
				end

				-- Play sound parented to the pickup, then let Debris clean up both
				local sound = pickupSound:Clone()
				sound.Parent = pickup.instance
				sound:Play()
				Debris:AddItem(pickup.instance, sound.TimeLength)

				-- Remove from tracking
				pickups[i] = pickups[#pickups]
				pickups[#pickups] = nil :: any
				continue
			end
		end

		i += 1
	end
end)

view:initialize(setupPickup)
