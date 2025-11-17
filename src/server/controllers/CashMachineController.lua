--!strict

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.InventoryModel)

local CashMachineController = {}
CashMachineController.__index = CashMachineController
setmetatable(CashMachineController, AbstractController)

export type CashMachineController = typeof(setmetatable({}, CashMachineController)) & AbstractController.AbstractController

function CashMachineController.new(): CashMachineController
	local self = AbstractController.new("CashMachineController") :: any
	setmetatable(self, CashMachineController)

	-- Set up event listener
	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string, amount: number)
		-- Validate action
		if action ~= "Withdraw" and action ~= "Deposit" then
			warn("Invalid action received from " .. player.Name .. ": " .. tostring(action))
			return
		end

		-- Validate amount
		if type(amount) ~= "number" or amount <= 0 then
			warn("Invalid amount received from " .. player.Name .. ": " .. tostring(amount))
			return
		end

		-- Get inventory model
		local inventory = InventoryModel.get()

		-- Handle actions
		if action == "Withdraw" then
			inventory:addGold(amount)
			print(player.Name .. " withdrew " .. amount .. " gold. New balance: " .. inventory.gold)
		elseif action == "Deposit" then
			inventory:addGold(-amount)
			print(player.Name .. " deposited " .. amount .. " gold. New balance: " .. inventory.gold)
		end
	end)

	print("CashMachineController initialized")

	return self :: CashMachineController
end

return CashMachineController
