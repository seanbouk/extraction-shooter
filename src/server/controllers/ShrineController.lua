--!strict

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local ShrineModel = require(script.Parent.Parent.models.server.ShrineModel)

local ShrineController = {}
ShrineController.__index = ShrineController
setmetatable(ShrineController, AbstractController)

export type ShrineController = typeof(setmetatable({}, ShrineController)) & AbstractController.AbstractController

local DONATION_AMOUNT = 1

local ACTIONS = {
	Donate = function(inventory: any, shrine: any, player: Player)
		-- Attempt to spend treasure
		if inventory:spendTreasure(DONATION_AMOUNT) then
			shrine:donate(tostring(player.UserId), DONATION_AMOUNT)
			print(player.Name .. " donated " .. DONATION_AMOUNT .. " treasure to the shrine")
		else
			warn(player.Name .. " attempted to donate to shrine but didn't have enough treasure")
		end
	end,
}

function ShrineController.new(): ShrineController
	local self = AbstractController.new("ShrineController") :: any
	setmetatable(self, ShrineController)

	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string)
		-- Validate action
		local actionFunc = ACTIONS[action]
		if not actionFunc then
			warn("Invalid action received from " .. player.Name .. ": " .. tostring(action))
			return
		end

		-- Get models
		local inventory = InventoryModel.get(tostring(player.UserId))
		local shrine = ShrineModel.get("SERVER") -- Server-scoped model

		actionFunc(inventory, shrine, player)
	end)

	print("ShrineController initialized")

	return self :: ShrineController
end

return ShrineController
