--!strict

-- Auto-discover and initialize all controllers (skip Abstract)
local controllersFolder = script.Parent
local controllerInfos = {}

type ControllerClass = {
	new: () -> any,
}

for _, moduleScript in controllersFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") and not moduleScript.Name:find("^Abstract") then
		local Controller = require(moduleScript) :: ControllerClass
		local instance = Controller.new()

		-- Store controller instance with its name for SlashCommandService
		table.insert(controllerInfos, {
			name = moduleScript.Name,
			instance = instance,
		})

		print("ControllerRunner: Initialized controller - " .. moduleScript.Name)
	end
end

print("ControllerRunner: All " .. #controllerInfos .. " controller(s) initialized")

-- Register controllers with SlashCommandService
local SlashCommandService = require(script.Parent.Parent.services.SlashCommandService)
SlashCommandService:registerControllers(controllerInfos)
