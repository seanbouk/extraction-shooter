--!strict

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)

local BazaarController = {}
BazaarController.__index = BazaarController
setmetatable(BazaarController, AbstractController)

export type BazaarController = typeof(setmetatable({}, BazaarController)) & AbstractController.AbstractController

local function buyTreasure(inventory: any, player: Player)
	local TREASURE_COST = 200
	local TREASURE_AMOUNT = 1

	-- Attempt to spend gold
	if inventory:spendGold(TREASURE_COST) then
		inventory:addTreasure(TREASURE_AMOUNT)
		print(player.Name .. " bought " .. TREASURE_AMOUNT .. " treasure for " .. TREASURE_COST .. " gold. New balance: " .. inventory.gold .. " gold, " .. inventory.treasure .. " treasure")
	else
		warn(player.Name .. " attempted to buy treasure but didn't have enough gold. Current: " .. inventory.gold .. ", Required: " .. TREASURE_COST)
	end
end

local ACTIONS = {
	BuyTreasure = buyTreasure,
}

function BazaarController.new(): BazaarController
	local self = AbstractController.new("BazaarController") :: any
	setmetatable(self, BazaarController)

	-- Set up event listener
	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string)
		local inventory = InventoryModel.get(tostring(player.UserId))
		self:dispatchAction(ACTIONS, action, player, inventory, player)
	end)

	return self :: BazaarController
end

return BazaarController
