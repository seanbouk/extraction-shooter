--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local ShrineModel = require(script.Parent.Parent.models.server.ShrineModel)
local IntentActions = require(ReplicatedStorage.IntentActions)

local ShrineController = {}
ShrineController.__index = ShrineController
setmetatable(ShrineController, AbstractController)

export type ShrineController = typeof(setmetatable({}, ShrineController)) & AbstractController.AbstractController

local DONATION_AMOUNT = 1

local function donate(inventory: any, shrine: any, player: Player)
	if inventory:spendTreasure(DONATION_AMOUNT) then
		shrine:donate(tostring(player.UserId), DONATION_AMOUNT)
	else
		warn(player.Name .. " attempted to donate to shrine but didn't have enough treasure")
	end
end

local ACTIONS = {
	[IntentActions.Shrine.Donate] = donate,
}

function ShrineController:executeAction(player: Player, action: IntentActions.ShrineAction)
	local inventory = InventoryModel.get(tostring(player.UserId))
	local shrine = ShrineModel.get("SERVER")

	self:dispatchAction(ACTIONS, action, player, inventory, shrine, player)
end

function ShrineController.new(): ShrineController
	local self = AbstractController.new("ShrineController") :: any
	setmetatable(self, ShrineController)

	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.ShrineAction)
		self:executeAction(player, action)
	end)

	return self :: ShrineController
end

return ShrineController
