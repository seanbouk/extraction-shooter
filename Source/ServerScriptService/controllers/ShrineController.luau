--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local ShrineModel = require(script.Parent.Parent.models.server.ShrineModel)
local FavoursModel = require(script.Parent.Parent.models.userEntities.FavoursModel)
local Network = require(ReplicatedStorage.Network)
local FavoursConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FavoursConfig"))

local ShrineController = {}
ShrineController.__index = ShrineController
setmetatable(ShrineController, AbstractController)

export type ShrineController = typeof(setmetatable({}, ShrineController)) & AbstractController.AbstractController

local DONATION_AMOUNT = 1
local MAX_ROLL_ATTEMPTS = 100

local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

local function generateFavourId(): string
	-- Generate a short unique ID (12 chars) to stay under DataStore 50 char key limit
	local id = ""
	for _ = 1, 12 do
		local index = math.random(1, #CHARS)
		id = id .. string.sub(CHARS, index, index)
	end
	return id
end

local function rollForFavour(): string?
	local favourTypes = {}
	for favourType, _ in FavoursConfig.favours do
		table.insert(favourTypes, favourType)
	end

	if #favourTypes == 0 then
		warn("No favour types configured in FavoursConfig")
		return nil
	end

	for _ = 1, MAX_ROLL_ATTEMPTS do
		local randomIndex = math.random(1, #favourTypes)
		local selectedType = favourTypes[randomIndex]
		local chanceValue = FavoursConfig.favours[selectedType]

		-- Chance values are 0-1, math.random() returns 0-1
		if math.random() < chanceValue then
			return selectedType
		end
	end

	return nil
end

local function donate(inventory: any, shrine: any, player: Player)
	if inventory:spendTreasure(DONATION_AMOUNT) then
		shrine:donate(tostring(player.UserId), DONATION_AMOUNT)

		local favourType = rollForFavour()
		if favourType then
			local favourId = generateFavourId()
			local ownerId = tostring(player.UserId)

			local favour = FavoursModel.new(ownerId, favourId)
			favour:setFavourType(favourType)
			inventory:addFavourId(favourId)

			print(player.Name .. " received a " .. favourType .. " favour!")
		end
	else
		warn(player.Name .. " attempted to donate to shrine but didn't have enough treasure")
	end
end

local ACTIONS = {
	[Network.Actions.Shrine.Donate] = donate,
}

function ShrineController:executeAction(player: Player, action: Network.ShrineAction)
	local inventory = InventoryModel.get(tostring(player.UserId))
	local shrine = ShrineModel.get("SERVER")

	self:dispatchAction(ACTIONS, action, player, inventory, shrine, player)
end

function ShrineController.new(): ShrineController
	local self = AbstractController.new("ShrineController") :: any
	setmetatable(self, ShrineController)

	self.intentEvent.OnServerEvent:Connect(function(player: Player, action: Network.ShrineAction)
		self:executeAction(player, action)
	end)

	return self :: ShrineController
end

return ShrineController
