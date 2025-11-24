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

-- RemoteEvent for sending commands to server
local commandRemote: RemoteEvent = nil

--[[
	Sends a command to the server for execution
]]
local function sendCommand(commandString: string): ()
	print(`[SlashCommandClient] Attempting to send command: "{commandString}"`)

	if not commandRemote then
		warn("[SlashCommandClient] Command remote not found")
		return
	end

	-- Remove leading "/" if present
	if commandString:sub(1, 1) == "/" then
		commandString = commandString:sub(2)
	end

	print(`[SlashCommandClient] Sending to server: "{commandString}"`)

	-- Send to server
	commandRemote:FireServer(commandString)
end

--[[
	Initializes the client
	Sets up listeners for slash commands
]]
function SlashCommandClient.new(): ()
	print("==================== [SlashCommandClient] Starting initialization... ====================")
	warn("==================== [SlashCommandClient] WARN TEST - This should show up! ====================")

	-- Wait for RemoteEvent
	local eventsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
	commandRemote = eventsFolder:WaitForChild("SlashCommand") :: RemoteEvent
	print("[SlashCommandClient] Found SlashCommand RemoteEvent")

	-- Listen for TextChatCommands being triggered
	local textCommands = TextChatService:FindFirstChild("TextChatCommands")
	if textCommands then
		print(`[SlashCommandClient] Found TextChatCommands with {#textCommands:GetChildren()} commands`)

		for _, command in textCommands:GetChildren() do
			if command:IsA("TextChatCommand") then
				print(`[SlashCommandClient] Registering listener for command: {command.PrimaryAlias}`)
				command.Triggered:Connect(function(textSource, unfilteredText)
					print(`[SlashCommandClient] Command triggered: {command.PrimaryAlias} with text: "{unfilteredText}"`)
					sendCommand(unfilteredText)
				end)
			end
		end

		-- Listen for new commands being added (for late registration)
		textCommands.ChildAdded:Connect(function(command)
			if command:IsA("TextChatCommand") then
				print(`[SlashCommandClient] New command added: {command.PrimaryAlias}`)
				command.Triggered:Connect(function(textSource, unfilteredText)
					print(`[SlashCommandClient] Command triggered: {command.PrimaryAlias} with text: "{unfilteredText}"`)
					sendCommand(unfilteredText)
				end)
			end
		end)
	else
		warn("[SlashCommandClient] TextChatCommands not found - slash commands may not work")
	end

	print("[SlashCommandClient] Initialized")
end

-- Initialize immediately when script runs
SlashCommandClient.new()

return SlashCommandClient
