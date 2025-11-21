--!strict

--[[
	IntentActions - Centralized action constants for view-controller communication

	This module provides type-safe action strings used by Views to send intents
	to Controllers. By centralizing these constants, we prevent typos and provide
	better IDE support.

	Usage in Views (client):
		local IntentActions = require(ReplicatedStorage.Shared.IntentActions)
		remoteEvent:FireServer(IntentActions.Shrine.Donate, amount)

	Usage in Controllers (server):
		local IntentActions = require(ReplicatedStorage.Shared.IntentActions)
		local ACTIONS = {
			[IntentActions.Shrine.Donate] = handleDonate,
		}
]]

local IntentActions = {
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

-- Export types for type-safe usage
export type CashMachineAction = "Withdraw" | "Deposit"
export type BazaarAction = "BuyTreasure"
export type ShrineAction = "Donate"

return IntentActions
