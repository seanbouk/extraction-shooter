--!strict

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.InventoryModel)

local BazaarController = {}
BazaarController.__index = BazaarController
setmetatable(BazaarController, AbstractController)

export type BazaarController = typeof(setmetatable({}, BazaarController)) & AbstractController.AbstractController

local ACTIONS = {
	BuyTreasure = function(inventory: any, player: Player)
		local TREASURE_COST = 200
		local TREASURE_AMOUNT = 1

		-- Attempt to spend gold
		if inventory:spendGold(TREASURE_COST) then
			inventory:addTreasure(TREASURE_AMOUNT)
			print(player.Name .. " bought " .. TREASURE_AMOUNT .. " treasure for " .. TREASURE_COST .. " gold. New balance: " .. inventory.gold .. " gold, " .. inventory.treasure .. " treasure")
		else
			warn(player.Name .. " attempted to buy treasure but didn't have enough gold. Current: " .. inventory.gold .. ", Required: " .. TREASURE_COST)
		end
	end,
}

function BazaarController.new(): BazaarController
	local self = AbstractController.new("BazaarController") :: any
	setmetatable(self, BazaarController)

	-- Set up event listener
	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string)
		-- Validate and execute action
		local actionFunc = ACTIONS[action]
		if not actionFunc then
			warn("Invalid action received from " .. player.Name .. ": " .. tostring(action))
			return
		end

		actionFunc(InventoryModel.get(tostring(player.UserId)), player)
	end)

	print("BazaarController initialized")

	return self :: BazaarController
end

return BazaarController
