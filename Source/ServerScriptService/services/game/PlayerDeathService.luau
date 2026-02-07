--!strict

--[[
	PlayerDeathService

	Listens for player deaths and drops ammo pickups at the death location.
	Each ammo type the player held becomes a separate pickup instance.
	The player's ammo is then zeroed out so they respawn with nothing
	(except potato, which fires freely).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AmmoModel = require(ServerScriptService.models.user.AmmoModel)

local PlayerDeathService = {}

local PICKUP_TAG = "Pickup"
local AMMO_TYPES: { AmmoModel.AmmoType } = { "pistol", "shot", "laser", "auto", "canon" }
local DROP_RADIUS = 10
local RAY_UP_OFFSET = 10
local RAY_DOWN_LENGTH = 50

local pickupTemplate: Instance = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pickup")

local dropRayParams = RaycastParams.new()
dropRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getGroundPosition(origin: Vector3, excludeList: { Instance }): Vector3
	dropRayParams.FilterDescendantsInstances = excludeList
	local rayOrigin = origin + Vector3.new(0, RAY_UP_OFFSET, 0)
	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -RAY_DOWN_LENGTH, 0), dropRayParams)
	if result then
		return result.Position
	end
	return origin
end

local function onPlayerDied(player: Player, character: Model): ()
	local ammo = AmmoModel.get(tostring(player.UserId))
	if not ammo then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local center = if root then root.Position else character:GetPivot().Position

	-- Collect ammo types that need dropping
	type Drop = { weaponName: string, amount: number }
	local drops: { Drop } = {}
	for _, ammoType in AMMO_TYPES do
		local amount = ammo:getAmmo(ammoType)
		if amount > 0 then
			local weaponName = string.upper(string.sub(ammoType, 1, 1)) .. string.sub(ammoType, 2)
			table.insert(drops, { weaponName = weaponName, amount = amount })
		end
	end

	if #drops == 0 then
		return
	end

	-- Exclude the dead character from ground raycasts
	local excludeList: { Instance } = { character }

	-- Spread pickups in a ring, evenly spaced with a random rotation offset
	local angleStep = (2 * math.pi) / #drops
	local randomOffset = math.random() * 2 * math.pi

	for i, drop in drops do
		local angle = randomOffset + (i - 1) * angleStep
		local offsetX = math.cos(angle) * DROP_RADIUS
		local offsetZ = math.sin(angle) * DROP_RADIUS
		local rawPos = center + Vector3.new(offsetX, 0, offsetZ)
		local dropPosition = getGroundPosition(rawPos, excludeList)

		local pickup = pickupTemplate:Clone()
		pickup:SetAttribute("Weapon", drop.weaponName)
		pickup:SetAttribute("Amount", drop.amount)

		if pickup:IsA("Model") then
			pickup:PivotTo(CFrame.new(dropPosition))
		else
			(pickup :: BasePart).Position = dropPosition
		end

		CollectionService:AddTag(pickup, PICKUP_TAG)
		pickup.Parent = workspace
	end

	ammo:clearAllAmmo()
end

local function onCharacterAdded(player: Player, character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
	end

	humanoid.Died:Connect(function()
		onPlayerDied(player, character)
	end)
end

local function onPlayerAdded(player: Player): ()
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

function PlayerDeathService.init()
	print("[PlayerDeathService] Initializing...")

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
end

return PlayerDeathService
