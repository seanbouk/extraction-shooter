--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = {}
AbstractController.__index = AbstractController

export type AbstractController = typeof(setmetatable({} :: {
	remoteEvent: RemoteEvent,
}, AbstractController))

function AbstractController.new(controllerName: string): AbstractController
	local self = setmetatable({}, AbstractController)

	-- Derive event name by removing "Controller" suffix
	local eventName = controllerName:gsub("Controller$", "") .. "Intent"

	-- Ensure Events folder exists in ReplicatedStorage/Shared
	local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
	local eventsFolder = sharedFolder:FindFirstChild("Events")
	if not eventsFolder then
		eventsFolder = Instance.new("Folder")
		eventsFolder.Name = "Events"
		eventsFolder.Parent = sharedFolder
	end

	-- Create RemoteEvent
	local remoteEvent = eventsFolder:FindFirstChild(eventName)
	if not remoteEvent then
		remoteEvent = Instance.new("RemoteEvent")
		remoteEvent.Name = eventName
		remoteEvent.Parent = eventsFolder
	end

	self.remoteEvent = remoteEvent :: RemoteEvent

	print(controllerName .. " initialized")

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

-- Override this method in child controllers to enable action discovery via /help
function AbstractController:getAvailableActions(): { string }
	return {}
end

return AbstractController
