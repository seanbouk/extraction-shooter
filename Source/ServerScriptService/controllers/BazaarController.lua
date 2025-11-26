--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local IntentActions = require(ReplicatedStorage.IntentActions)

local BazaarController = {}
BazaarController.__index = BazaarController
setmetatable(BazaarController, AbstractController)

export type BazaarController = typeof(setmetatable({}, BazaarController)) & AbstractController.AbstractController

local function buyTreasure(inventory: any, player: Player)
	local TREASURE_COST = 200
	local TREASURE_AMOUNT = 1

	if inventory:spendGold(TREASURE_COST) then
		inventory:addTreasure(TREASURE_AMOUNT)
	else
		warn(player.Name .. " attempted to buy treasure but didn't have enough gold. Current: " .. inventory.gold .. ", Required: " .. TREASURE_COST)
	end
end

local ACTIONS = {
	[IntentActions.Bazaar.BuyTreasure] = buyTreasure,
}

function BazaarController:executeAction(player: Player, action: IntentActions.BazaarAction)
	local inventory = InventoryModel.get(tostring(player.UserId))
	self:dispatchAction(ACTIONS, action, player, inventory, player)
end

function BazaarController.new(): BazaarController
	local self = AbstractController.new("BazaarController") :: any
	setmetatable(self, BazaarController)

	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.BazaarAction)
		self:executeAction(player, action)
	end)

	return self :: BazaarController
end

return BazaarController
