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

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if not selectedWeapon then
		return
	end

	-- Use input.Position for both mouse and touch (both are screen-space coordinates)
	local screenPos: Vector2? = nil

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		screenPos = Vector2.new(input.Position.X, input.Position.Y)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		screenPos = Vector2.new(input.Position.X, input.Position.Y)
	end

	if not screenPos then
		return
	end

	local targetPosition = getTargetPosition(screenPos)
	if not targetPosition then
		return
	end

	Network.Intent.Weapons:FireServer(Network.Actions.Weapons.Fire, selectedWeapon, targetPosition)
end)
