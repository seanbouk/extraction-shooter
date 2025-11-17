--!strict

local Players = game:GetService("Players")

-- Initialize controllers
local CashMachineController = require(script.Parent.controllers.CashMachineController)

-- Initialize models
local InventoryModel = require(script.Parent.models.InventoryModel)

-- Create controller instance
CashMachineController.new()

-- Player lifecycle management: cleanup models when player leaves
Players.PlayerRemoving:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	InventoryModel.remove(ownerId)
	print("ControllerRunner: Cleaned up models for player " .. player.Name .. " (UserId: " .. ownerId .. ")")
end)

print("ControllerRunner: All controllers initialized")
