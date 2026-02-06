--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local ProjectilesModel = require(script.Parent.Parent.models.serverEntities.ProjectilesModel)
local Network = require(ReplicatedStorage.Network)
local WeaponsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponsConfig"))

local WeaponsController = {}
WeaponsController.__index = WeaponsController
setmetatable(WeaponsController, AbstractController)

export type WeaponsController = typeof(setmetatable({}, WeaponsController)) & AbstractController.AbstractController

local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

local function generateProjectileId(): string
	local id = ""
	for _ = 1, 12 do
		local index = math.random(1, #CHARS)
		id = id .. string.sub(CHARS, index, index)
	end
	return id
end

local function fire(player: Player, weaponName: string, targetPosition: Vector3)
	-- Validate weapon name
	if typeof(weaponName) ~= "string" then
		warn(player.Name .. " sent invalid weapon name type")
		return
	end

	local weaponStats = WeaponsConfig.weapons[weaponName]
	if not weaponStats then
		warn(player.Name .. " sent unknown weapon: " .. tostring(weaponName))
		return
	end

	-- Validate target position
	if typeof(targetPosition) ~= "Vector3" then
		warn(player.Name .. " sent invalid target position type")
		return
	end

	-- Validate player character
	local character = player.Character
	if not character then
		warn(player.Name .. " has no character")
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		warn(player.Name .. " has no HumanoidRootPart")
		return
	end

	-- Target is projected 1000 studs from the client's player position,
	-- so small server-side position drift doesn't affect the direction
	local baseDirection = (targetPosition - rootPart.Position).Unit
	local origin = rootPart.Position + baseDirection * 2

	print(string.format(
		"[CTRL] %s fired %s | playerPos=(%.1f,%.1f,%.1f) target=(%.1f,%.1f,%.1f) dir=(%.2f,%.2f,%.2f) origin=(%.1f,%.1f,%.1f)",
		player.Name, weaponName,
		rootPart.Position.X, rootPart.Position.Y, rootPart.Position.Z,
		targetPosition.X, targetPosition.Y, targetPosition.Z,
		baseDirection.X, baseDirection.Y, baseDirection.Z,
		origin.X, origin.Y, origin.Z
	))

	-- Create projectiles
	for _ = 1, weaponStats.numberOfProjectiles do
		-- Apply noise (random angular offset within noise degrees)
		local noiseRad = math.rad(weaponStats.noise)
		local randomYaw = (math.random() * 2 - 1) * noiseRad
		local randomPitch = (math.random() * 2 - 1) * noiseRad
		local noisedDirection = (CFrame.new(Vector3.zero, baseDirection) * CFrame.Angles(randomPitch, randomYaw, 0)).LookVector

		local projectileId = generateProjectileId()
		local colour = weaponStats.colour

		ProjectilesModel.create(
			projectileId,
			weaponName,
			origin.X, origin.Y, origin.Z,
			noisedDirection.X, noisedDirection.Y, noisedDirection.Z,
			weaponStats.speed,
			weaponStats.diameter, weaponStats.length,
			colour.R, colour.G, colour.B,
			player
		)
	end
end

local ACTIONS = {
	[Network.Actions.Weapons.Fire] = fire,
}

function WeaponsController:executeAction(player: Player, action: Network.WeaponsAction, ...)
	self:dispatchAction(ACTIONS, action, player, player, ...)
end

function WeaponsController.new(): WeaponsController
	local self = AbstractController.new("WeaponsController") :: any
	setmetatable(self, WeaponsController)

	self.intentEvent.OnServerEvent:Connect(function(player: Player, action: Network.WeaponsAction, ...)
		self:executeAction(player, action, ...)
	end)

	return self :: WeaponsController
end

return WeaponsController
