--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local IntentActions = require(ReplicatedStorage.Shared.IntentActions)

local CashMachineController = {}
CashMachineController.__index = CashMachineController
setmetatable(CashMachineController, AbstractController)

export type CashMachineController = typeof(setmetatable({}, CashMachineController)) & AbstractController.AbstractController

local function withdraw(inventory: any, amount: number, player: Player)
	inventory:addGold(amount)
	print(player.Name .. " withdrew " .. amount .. " gold. New balance: " .. inventory.gold)
end

local function deposit(inventory: any, amount: number, player: Player)
	inventory:addGold(-amount)
	print(player.Name .. " deposited " .. amount .. " gold. New balance: " .. inventory.gold)
end

local ACTIONS = {
	[IntentActions.CashMachine.Withdraw] = withdraw,
	[IntentActions.CashMachine.Deposit] = deposit,
}

function CashMachineController.new(): CashMachineController
	local self = AbstractController.new("CashMachineController") :: any
	setmetatable(self, CashMachineController)

	-- Set up event listener
	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string, amount: number)
		-- Validate amount
		if amount <= 0 then
			warn("Invalid amount received from " .. player.Name .. ": " .. tostring(amount))
			return
		end

		-- Get model
		local inventory = InventoryModel.get(tostring(player.UserId))

		-- Dispatch action
		self:dispatchAction(ACTIONS, action, player, inventory, amount, player)
	end)

	return self :: CashMachineController
end

return CashMachineController
