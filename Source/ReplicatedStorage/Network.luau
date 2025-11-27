--!strict

--[[
	Network - Central networking module using Bolt

	This module provides:
	- Auto-registration of Bolt ReliableEvents for controller intents
	- Auto-registration of Bolt RemoteProperties for model state
	- Type-safe action constants and state types
	- Single source of truth for all networking (replaces IntentActions + StateEvents)

	Usage in Controllers:
		local Network = require(ReplicatedStorage.Network)
		self.intentEvent = Network.registerIntent("CashMachine")

	Usage in Models:
		local Network = require(ReplicatedStorage.Network)
		self._stateProperty = Network.registerState("Inventory", defaultState)

	Usage in Views:
		local Network = require(ReplicatedStorage.Network)
		local cashMachineIntent = Network.Intent.CashMachine
		cashMachineIntent:FireServer(Network.Actions.CashMachine.Withdraw, amount)

		local inventoryState = Network.State.Inventory
		inventoryState:Observe(function(data) ... end)
]]

local Bolt = require(script.Parent.Bolt)

-- Network module definition
local Network = {
	Intent = {},  -- Bolt.ReliableEvent instances (auto-populated by controllers)
	State = {},   -- Bolt.RemoteProperty instances (eagerly created below)
}

-- Action Constants (replaces IntentActions.lua)
Network.Actions = {
	CashMachine = {
		Withdraw = "Withdraw",
		Deposit = "Deposit",
	},
	Bazaar = {
		BuyTreasure = "BuyTreasure",
	},
	Shrine = {
		Donate = "Donate",
	},
}

-- Action Type Exports
export type CashMachineAction = "Withdraw" | "Deposit"
export type BazaarAction = "BuyTreasure"
export type ShrineAction = "Donate"

-- State Type Exports (replaces StateEvents.lua)
export type InventoryState = {
	ownerId: string,
	gold: number,
	treasure: number,
}

export type ShrineState = {
	ownerId: string,
	treasure: number,
	userId: string,
}

-- Eager Intent Registration: Create ReliableEvents immediately at module load
-- This ensures views can access Network.Intent.* before controllers initialize
Network.Intent.CashMachine = Bolt.ReliableEvent("CashMachineIntent")
Network.Intent.Bazaar = Bolt.ReliableEvent("BazaarIntent")
Network.Intent.Shrine = Bolt.ReliableEvent("ShrineIntent")
Network.Intent.SlashCommand = Bolt.ReliableEvent("SlashCommandIntent")

-- Eager State Registration: Create RemoteProperties immediately at module load
-- This ensures views can access Network.State.* before models initialize
Network.State.Inventory = Bolt.RemoteProperty("InventoryState", {
	ownerId = "",
	gold = 0,
	treasure = 0,
})

Network.State.Shrine = Bolt.RemoteProperty("ShrineState", {
	ownerId = "",
	treasure = 0,
	userId = "",
})

Network.State.SlashCommand = Bolt.RemoteProperty("SlashCommandState", {
	message = "",
})

-- Auto-registration Functions

--[[
	Get a Bolt ReliableEvent for controller intents

	Note: Intents are eagerly created at module load, this just returns the existing one

	@param controllerName - Name of the controller (e.g., "CashMachine")
	@return Bolt.ReliableEvent for this controller
]]
function Network.registerIntent(controllerName: string): any
	if Network.Intent[controllerName] then
		return Network.Intent[controllerName]
	end

	error(`[Network] Unknown controller intent: {controllerName}. Add it to Network.Intent at module load.`)
end

--[[
	Get a Bolt RemoteProperty for model state synchronization

	Note: Properties are eagerly created at module load, this just returns the existing one

	@param modelName - Name of the model (e.g., "Inventory")
	@param defaultState - Unused (kept for API compatibility)
	@return Bolt.RemoteProperty for this model
]]
function Network.registerState(modelName: string, defaultState: any): any
	if Network.State[modelName] then
		return Network.State[modelName]
	end

	error(`[Network] Unknown model state: {modelName}. Add it to Network.State at module load.`)
end

return Network
