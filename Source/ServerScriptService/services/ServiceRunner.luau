--!strict
--[[
	ServiceRunner
	Orchestrates service initialization:
	1. Framework services (explicit order)
	2. Game services (auto-discovered)
]]

local frameworkFolder = script.Parent:FindFirstChild("framework")
local gameFolder = script.Parent:FindFirstChild("game")

local ServiceRunner = {}

local PersistenceService = nil
local SlashCommandService = nil

-- Phase 1: Must run before any model is used
function ServiceRunner.initPersistence()
	PersistenceService = require(frameworkFolder.PersistenceService)
	PersistenceService.init()
end

-- Phase 2: After models discovered
function ServiceRunner.initSlashCommands()
	SlashCommandService = require(frameworkFolder.SlashCommandService)
	SlashCommandService:init()
end

function ServiceRunner.registerModels(modelInfos)
	SlashCommandService:registerModels(modelInfos)
end

function ServiceRunner.registerControllers(controllerInfos)
	SlashCommandService:registerControllers(controllerInfos)
end

function ServiceRunner.finalizeSlashCommands()
	SlashCommandService:createTextChatCommands()
end

-- Phase 3: Auto-discover game services after models ready
function ServiceRunner.initGameServices()
	if not gameFolder then
		return
	end

	for _, moduleScript in gameFolder:GetChildren() do
		if moduleScript:IsA("ModuleScript") then
			local service = require(moduleScript)
			if service.init then
				service.init()
				print("[ServiceRunner] Initialized: " .. moduleScript.Name)
			end
		end
	end
end

function ServiceRunner.getPersistenceService()
	return PersistenceService
end

return ServiceRunner
