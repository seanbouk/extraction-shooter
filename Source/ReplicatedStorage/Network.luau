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
		self.intentEvent = Network.registerIntent("Weapons")

	Usage in Models:
		local Network = require(ReplicatedStorage.Network)
		self._stateProperty = Network.registerState("Projectiles", defaultState)

	Usage in Views:
		local Network = require(ReplicatedStorage.Network)
		local weaponsIntent = Network.Intent.Weapons
		weaponsIntent:FireServer(Network.Actions.Weapons.Fire)

		local projectilesState = Network.State.Projectiles
		projectilesState:Observe(function(data) ... end)
]]

local Bolt = require(script.Parent.Bolt)
local NetworkBuilder = require(script.Parent.NetworkBuilder)

-- ============================================================================
-- GAME CONFIGURATION: Add new controllers and models here
-- ============================================================================

-- Network Configuration: Single source of truth for all controllers and state
local NetworkConfig = {
	Controllers = {
		SlashCommand = {},  -- No actions, just the intent
		Weapons = { "Fire" },
	},

	States = {
		Ammo = {
			ownerId = "",
			pistol = 100,
			shot = 1,
			laser = 1,
			auto = 20,
			canon = 1,
		},
		Projectiles = {
			ownerId = "",
			modelId = "",
			weaponName = "",
			originX = 0, originY = 0, originZ = 0,
			directionX = 0, directionY = 0, directionZ = 0,
			speed = 0,
			diameter = 0, length = 0,
			colourR = 0, colourG = 0, colourB = 0,
			createdTime = 0,
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
export type WeaponsAction = "Fire"

-- State Type Exports (manually defined for type safety)
export type AmmoState = {
	ownerId: string,
	pistol: number,
	shot: number,
	laser: number,
	auto: number,
	canon: number,
}

export type ProjectilesState = {
	ownerId: string,
	modelId: string,
	weaponName: string,
	originX: number, originY: number, originZ: number,
	directionX: number, directionY: number, directionZ: number,
	speed: number,
	diameter: number, length: number,
	colourR: number, colourG: number, colourB: number,
	createdTime: number,
}

-- ============================================================================

return Network
