--!strict

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)

local CashMachineController = {}
CashMachineController.__index = CashMachineController
setmetatable(CashMachineController, AbstractController)

export type CashMachineController = typeof(setmetatable({}, CashMachineController)) & AbstractController.AbstractController

local ACTIONS = {
	Withdraw = function(inventory: any, amount: number, player: Player)
		inventory:addGold(amount)
		print(player.Name .. " withdrew " .. amount .. " gold. New balance: " .. inventory.gold)
	end,
	Deposit = function(inventory: any, amount: number, player: Player)
		inventory:addGold(-amount)
		print(player.Name .. " deposited " .. amount .. " gold. New balance: " .. inventory.gold)
	end,
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

		-- Validate and execute action
		local actionFunc = ACTIONS[action]
		if not actionFunc then
			warn("Invalid action received from " .. player.Name .. ": " .. tostring(action))
			return
		end

		actionFunc(InventoryModel.get(tostring(player.UserId)), amount, player)
	end)

	print("CashMachineController initialized")

	return self :: CashMachineController
end

return CashMachineController
