--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigTypes = ReplicatedStorage:WaitForChild("Config"):WaitForChild("ConfigTypes")
local CandlesConfigTypes = require(ConfigTypes:WaitForChild("CandlesConfigTypes"))

type CandlesConfig = CandlesConfigTypes.CandlesConfig

local config: CandlesConfig = {
	lifetimeSeconds = 5,
}

return config
