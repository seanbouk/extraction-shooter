--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigTypes = ReplicatedStorage:WaitForChild("Config"):WaitForChild("ConfigTypes")
local FavoursConfigTypes = require(ConfigTypes:WaitForChild("FavoursConfigTypes"))

type FavoursConfig = FavoursConfigTypes.FavoursConfig

local config: FavoursConfig = {
	favours = {
		Blessing = 1,    -- 100% acceptance when selected
		Fortune = 0.5,   -- 50% acceptance when selected
		Miracle = 0.1,   -- 10% acceptance when selected
	},
}

return config
