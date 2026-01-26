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
	local Network = require(ReplicatedStorage:WaitForChild("Network"))

	local textChannels = TextChatService:WaitForChild("TextChannels")
	local generalChannel = textChannels:FindFirstChild("RBXGeneral")

	if not generalChannel then
		warn("[ChatMessageClient] Could not find RBXGeneral channel")
		return
	end

	Network.State.SlashCommand:Observe(function(data: { message: string })
		if data.message ~= "" then
			generalChannel:DisplaySystemMessage(data.message)
		end
	end)

	print("ChatMessageClient initialized")
end

ChatMessageClient.new()

return ChatMessageClient
