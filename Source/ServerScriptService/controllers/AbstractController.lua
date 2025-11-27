--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Network)

local AbstractController = {}
AbstractController.__index = AbstractController

export type AbstractController = typeof(setmetatable({} :: {
	intentEvent: any,
}, AbstractController))

function AbstractController.new(controllerName: string): AbstractController
	local self = setmetatable({}, AbstractController)

	-- Auto-register with Network using Bolt ReliableEvent
	local eventName = controllerName:gsub("Controller$", "")
	self.intentEvent = Network.registerIntent(eventName)

	print(controllerName .. " initialized with Bolt")

	return self
end

function AbstractController:dispatchAction(actionsTable: { [string]: (...any) -> () }, action: string, player: Player, ...: any)
	local actionFunc = actionsTable[action]
	if not actionFunc then
		warn("Invalid action received from " .. player.Name .. ": " .. tostring(action))
		return
	end

	actionFunc(...)
end

return AbstractController
