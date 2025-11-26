--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local IntentActions = require(ReplicatedStorage.IntentActions)

local CashMachineController = {}
CashMachineController.__index = CashMachineController
setmetatable(CashMachineController, AbstractController)

export type CashMachineController = typeof(setmetatable({}, CashMachineController)) & AbstractController.AbstractController

local function withdraw(inventory: any, amount: number, player: Player)
	inventory:addGold(amount)
end

local function deposit(inventory: any, amount: number, player: Player)
	inventory:addGold(-amount)
end

local ACTIONS = {
	[IntentActions.CashMachine.Withdraw] = withdraw,
	[IntentActions.CashMachine.Deposit] = deposit,
}

function CashMachineController:executeAction(player: Player, action: IntentActions.CashMachineAction, amount: number)
	if amount <= 0 then
		warn("Invalid amount received from " .. player.Name .. ": " .. tostring(amount))
		return
	end

	local inventory = InventoryModel.get(tostring(player.UserId))

	self:dispatchAction(ACTIONS, action, player, inventory, amount, player)
end

function CashMachineController.new(): CashMachineController
	local self = AbstractController.new("CashMachineController") :: any
	setmetatable(self, CashMachineController)

	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.CashMachineAction, amount: number)
		self:executeAction(player, action, amount)
	end)

	return self :: CashMachineController
end

return CashMachineController
