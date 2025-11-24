--!strict

--[[
	ChatMessageClient

	Displays state change messages from the server in the player's chat window.
	Used by SlashCommandService to show command results and errors.
	Follows the StateChanged pattern for consistency with MVC architecture.
]]

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatMessageClient = {}

function ChatMessageClient.new(): ()
	local eventsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
	local messageRemote = eventsFolder:WaitForChild("SlashCommandStateChanged") :: RemoteEvent

	messageRemote.OnClientEvent:Connect(function(message: string)
		local textChannels = TextChatService:WaitForChild("TextChannels")
		local generalChannel = textChannels:FindFirstChild("RBXGeneral")

		if generalChannel then
			generalChannel:DisplaySystemMessage(message)
		else
			warn("[ChatMessageClient] Could not find RBXGeneral channel")
		end
	end)

	print("ChatMessageClient initialized")
end

ChatMessageClient.new()

return ChatMessageClient
