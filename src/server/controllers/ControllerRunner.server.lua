--!strict

-- Auto-discover and initialize all controllers (skip Abstract)
local controllersFolder = script.Parent
local controllers = {}

type ControllerClass = {
	new: () -> any,
}

for _, moduleScript in controllersFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") and not moduleScript.Name:find("^Abstract") then
		local Controller = require(moduleScript) :: ControllerClass
		Controller.new()
		table.insert(controllers, Controller)
		print("ControllerRunner: Initialized controller - " .. moduleScript.Name)
	end
end

print("ControllerRunner: All " .. #controllers .. " controller(s) initialized")
