--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local AbstractView = {}
AbstractView.__index = AbstractView

local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")

export type AbstractView = typeof(setmetatable({} :: {
	_viewName: string,
	_tag: string,
	_eventCache: { [string]: BindableEvent },
}, AbstractView))

local function isInStarterGui(instance: Instance): boolean
	return instance:IsDescendantOf(StarterGui)
end

function AbstractView.new(viewName: string, tag: string): AbstractView
	local self = setmetatable({}, AbstractView) :: any
	self._viewName = viewName
	self._tag = tag
	self._eventCache = {}
	return self
end

function AbstractView:initialize(setupFn: (Instance) -> ()): ()
	for _, instance in ipairs(CollectionService:GetTagged(self._tag)) do
		if not isInStarterGui(instance) then
			task.spawn(function()
				setupFn(instance)
			end)
		end
	end

	CollectionService:GetInstanceAddedSignal(self._tag):Connect(function(instance: Instance)
		if not isInStarterGui(instance) then
			task.spawn(function()
				setupFn(instance)
			end)
		end
	end)
end

function AbstractView:createEvent(eventName: string): BindableEvent
	local event = Instance.new("BindableEvent")
	event.Name = eventName
	event.Parent = playerScripts
	self._eventCache[eventName] = event
	return event
end

function AbstractView:getEvent(eventName: string, timeout: number?): BindableEvent?
	if self._eventCache[eventName] then
		return self._eventCache[eventName]
	end

	local event = playerScripts:WaitForChild(eventName, timeout or 5)
	if event and event:IsA("BindableEvent") then
		self._eventCache[eventName] = event :: BindableEvent
		return self._eventCache[eventName]
	end

	warn(`{self._viewName}: Could not find {eventName} in PlayerScripts`)
	return nil
end

return AbstractView
