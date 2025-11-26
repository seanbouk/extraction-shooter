--!strict

--[[
	SlashCommandClient (Client)

	Handles client-side slash command input and communication with server.
	Listens to TextChatService for slash command triggers and sends them to the server for execution.

	This is a client-side utility script, NOT a controller (controllers are server-side MVC components).
]]

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlashCommandClient = {}

-- RemoteEvent for sending command intents to server
local commandRemote: RemoteEvent = nil

--[[
	Sends a command to the server for execution
]]
local function sendCommand(commandString: string): ()
	if not commandRemote then
		warn("[SlashCommandClient] Command remote not found")
		return
	end

	-- Remove leading "/" if present
	if commandString:sub(1, 1) == "/" then
		commandString = commandString:sub(2)
	end

	-- Send to server
	commandRemote:FireServer(commandString)
end

--[[
	Initializes the client
	Sets up listeners for slash commands
]]
function SlashCommandClient.new(): ()
	-- Wait for RemoteEvent (follows Intent pattern)
	local eventsFolder = ReplicatedStorage:WaitForChild("Events")
	commandRemote = eventsFolder:WaitForChild("SlashCommandIntent") :: RemoteEvent

	-- Listen for TextChatCommands being triggered
	local textCommands = TextChatService:FindFirstChild("TextChatCommands")
	if textCommands then
		for _, command in textCommands:GetChildren() do
			if command:IsA("TextChatCommand") then
				command.Triggered:Connect(function(textSource, unfilteredText)
					sendCommand(unfilteredText)
				end)
			end
		end

		-- Listen for new commands being added (for late registration)
		textCommands.ChildAdded:Connect(function(command)
			if command:IsA("TextChatCommand") then
				command.Triggered:Connect(function(textSource, unfilteredText)
					sendCommand(unfilteredText)
				end)
			end
		end)
	else
		warn("[SlashCommandClient] TextChatCommands not found - slash commands may not work")
	end
end

-- Initialize immediately when script runs
SlashCommandClient.new()

return SlashCommandClient
