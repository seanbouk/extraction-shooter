--!strict

--[[
	Network - Central networking module using Bolt

	This module provides:
	- Auto-generation of Bolt ReliableEvents for controller intents
	- Auto-generation of Bolt RemoteProperties for model state
	- Type-safe action constants and state types
	- Single source of truth for all networking (replaces IntentActions + StateEvents)

	To add new controllers or models, simply add them to NetworkConfig below.

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

-- Network Configuration: Single source of truth for all controllers and state
local NetworkConfig = {
	Controllers = {
		CashMachine = { "Withdraw", "Deposit" },
		Bazaar = { "BuyTreasure" },
		Shrine = { "Donate" },
		SlashCommand = {},  -- No actions, just the intent
	},

	States = {
		Inventory = {
			ownerId = "",
			gold = 0,
			treasure = 0,
		},
		Shrine = {
			ownerId = "",
			treasure = 0,
			userId = "",
		},
		SlashCommand = {
			ownerId = "",
			message = "",
		},
	},
}

-- Network module definition
local Network = {
	Intent = {},  -- Bolt.ReliableEvent instances (auto-generated below)
	State = {},   -- Bolt.RemoteProperty instances (auto-generated below)
	Actions = {}, -- Action constants (auto-generated below)
}

-- Auto-generate Actions from NetworkConfig.Controllers
for controllerName, actions in NetworkConfig.Controllers do
	Network.Actions[controllerName] = {}
	for _, actionName in actions do
		Network.Actions[controllerName][actionName] = actionName
	end
end

-- Action Type Exports (manually defined for type safety)
export type CashMachineAction = "Withdraw" | "Deposit"
export type BazaarAction = "BuyTreasure"
export type ShrineAction = "Donate"

-- State Type Exports (manually defined for type safety)
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

-- Auto-generate Intent Registration: Create ReliableEvents from NetworkConfig.Controllers
-- This ensures views can access Network.Intent.* before controllers initialize
for controllerName in NetworkConfig.Controllers do
	Network.Intent[controllerName] = Bolt.ReliableEvent(controllerName .. "Intent")
end

-- Auto-generate State Registration: Create RemoteProperties from NetworkConfig.States
-- This ensures views can access Network.State.* before models initialize
-- Defaults are taken from NetworkConfig for views that observe before models sync
for stateName, defaultValue in NetworkConfig.States do
	Network.State[stateName] = Bolt.RemoteProperty(stateName .. "State", defaultValue)
end

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

	error(`[Network] Unknown controller intent: {controllerName}. Add it to NetworkConfig.Controllers.`)
end

--[[
	Get a Bolt RemoteProperty for model state synchronization

	Note: Properties are eagerly created at module load, this just returns the existing one

	@param modelName - Name of the model (e.g., "Inventory")
	@return Bolt.RemoteProperty for this model
]]
function Network.registerState(modelName: string): any
	if Network.State[modelName] then
		return Network.State[modelName]
	end

	error(`[Network] Unknown model state: {modelName}. Add it to NetworkConfig.States.`)
end

return Network
