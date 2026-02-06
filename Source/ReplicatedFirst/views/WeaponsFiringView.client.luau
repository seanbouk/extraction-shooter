--!strict

--[[
	WeaponsFiringView

	Handles client-side weapon firing input. Detects mouse clicks and touch taps,
	raycasts to find the 3D target position, and fires the weapon intent to the server.
	Reads the currently selected weapon from the WeaponSelectedEvent (BindableEvent).
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

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

local function getTargetPosition(screenPosition: Vector2): Vector3
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Exclude the local player's character
	local character = localPlayer.Character
	if character then
		raycastParams.FilterDescendantsInstances = { character }
	end

	local result = workspace:Raycast(ray.Origin, ray.Direction * RAYCAST_DISTANCE, raycastParams)

	if result then
		return result.Position
	end

	-- Fallback: far point along ray
	return ray.Origin + ray.Direction * RAYCAST_DISTANCE
end

local function fireWeapon(screenPosition: Vector2)
	if not selectedWeapon then
		return
	end

	local targetPosition = getTargetPosition(screenPosition)

	Network.Intent.Weapons:FireServer(Network.Actions.Weapons.Fire, selectedWeapon, targetPosition)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mouseLocation = UserInputService:GetMouseLocation()
		fireWeapon(mouseLocation)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		fireWeapon(Vector2.new(input.Position.X, input.Position.Y))
	end
end)
