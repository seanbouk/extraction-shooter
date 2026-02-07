--!strict

--[[
	AmmoController

	Handles all situations where a player's ammo increases or decreases.

	Actions:
	  - Spend(weaponType, amount): Deduct ammo when firing or using ammo
	  - Collect(weaponType, amount): Add ammo when picking up or receiving ammo

	Models:
	  - AmmoModel (User): Per-player ammo storage

	Usage from Client:
	  Network.Intent.Ammo:FireServer(Network.Actions.Ammo.Spend, "pistol", 1)
	  Network.Intent.Ammo:FireServer(Network.Actions.Ammo.Collect, "shot", 5)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local AmmoModel = require(script.Parent.Parent.models.user.AmmoModel)
local Network = require(ReplicatedStorage.Network)

local AmmoController = {}
AmmoController.__index = AmmoController
setmetatable(AmmoController, AbstractController)

export type AmmoController = typeof(setmetatable({}, AmmoController)) & AbstractController.AbstractController

local VALID_AMMO_TYPES: { [string]: boolean } = {
	pistol = true,
	shot = true,
	laser = true,
	auto = true,
	canon = true,
}

-- ============================================================================
-- ACTION HANDLERS
-- ============================================================================

local function spend(ammo: any, weaponType: string, amount: number, player: Player)
	if not ammo:spendAmmo(weaponType :: AmmoModel.AmmoType, amount) then
		warn(player.Name .. " tried to spend " .. amount .. " " .. weaponType .. " ammo but only has " .. ammo:getAmmo(weaponType :: AmmoModel.AmmoType))
		return
	end

	print(player.Name .. " spent " .. amount .. " " .. weaponType .. " ammo")
end

local function collect(ammo: any, weaponType: string, amount: number, player: Player)
	ammo:addAmmo(weaponType :: AmmoModel.AmmoType, amount)
	print(player.Name .. " collected " .. amount .. " " .. weaponType .. " ammo")
end

-- ============================================================================
-- ACTIONS LOOKUP TABLE
-- ============================================================================

local ACTIONS = {
	[Network.Actions.Ammo.Spend] = spend,
	[Network.Actions.Ammo.Collect] = collect,
}

-- ============================================================================
-- CONTROLLER IMPLEMENTATION
-- ============================================================================

function AmmoController:executeAction(player: Player, action: Network.AmmoAction, weaponType: string, amount: number)
	-- Validate weaponType
	if typeof(weaponType) ~= "string" or not VALID_AMMO_TYPES[weaponType] then
		warn("Invalid weapon type from " .. player.Name .. ": " .. tostring(weaponType))
		return
	end

	-- Validate amount
	if typeof(amount) ~= "number" or amount <= 0 or amount ~= math.floor(amount) then
		warn("Invalid amount from " .. player.Name .. ": " .. tostring(amount))
		return
	end

	-- Get model
	local ammo = AmmoModel.get(tostring(player.UserId))

	-- Dispatch to action handler
	self:dispatchAction(ACTIONS, action, player, ammo, weaponType, amount, player)
end

function AmmoController.new(): AmmoController
	local self = AbstractController.new("AmmoController") :: any
	setmetatable(self, AmmoController)

	self.intentEvent.OnServerEvent:Connect(function(player: Player, action: Network.AmmoAction, weaponType: string, amount: number)
		self:executeAction(player, action, weaponType, amount)
	end)

	return self :: AmmoController
end

return AmmoController
