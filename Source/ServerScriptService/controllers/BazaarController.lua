--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local Network = require(ReplicatedStorage.Network)

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
	[Network.Actions.Bazaar.BuyTreasure] = buyTreasure,
}

function BazaarController:executeAction(player: Player, action: Network.BazaarAction)
	local inventory = InventoryModel.get(tostring(player.UserId))
	self:dispatchAction(ACTIONS, action, player, inventory, player)
end

function BazaarController.new(): BazaarController
	local self = AbstractController.new("BazaarController") :: any
	setmetatable(self, BazaarController)

	self.intentEvent.OnServerEvent:Connect(function(player: Player, action: Network.BazaarAction)
		self:executeAction(player, action)
	end)

	return self :: BazaarController
end

return BazaarController
