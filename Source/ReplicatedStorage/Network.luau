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
local NetworkBuilder = require(script.Parent.NetworkBuilder)

-- ============================================================================
-- GAME CONFIGURATION: Add new controllers and models here
-- ============================================================================

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

-- ============================================================================
-- BUILD NETWORK MODULE (Engine code - do not modify)
-- ============================================================================

local Network = NetworkBuilder.build(NetworkConfig, Bolt)

-- ============================================================================
-- TYPE EXPORTS: Add type definitions for new actions and states
-- ============================================================================

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

-- ============================================================================

return Network
