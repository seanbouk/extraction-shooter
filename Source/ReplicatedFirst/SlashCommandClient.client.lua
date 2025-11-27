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

local commandRemote: RemoteEvent = nil

local function sendCommand(commandString: string): ()
	if not commandRemote then
		warn("[SlashCommandClient] Command remote not found")
		return
	end

	if commandString:sub(1, 1) == "/" then
		commandString = commandString:sub(2)
	end

	commandRemote:FireServer(commandString)
end

function SlashCommandClient.new(): ()
	local Network = require(ReplicatedStorage:WaitForChild("Network"))
	commandRemote = Network.Intent.SlashCommand

	local textCommands = TextChatService:FindFirstChild("TextChatCommands")
	if textCommands then
		for _, command in textCommands:GetChildren() do
			if command:IsA("TextChatCommand") then
				command.Triggered:Connect(function(textSource, unfilteredText)
					sendCommand(unfilteredText)
				end)
			end
		end

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

SlashCommandClient.new()

return SlashCommandClient
