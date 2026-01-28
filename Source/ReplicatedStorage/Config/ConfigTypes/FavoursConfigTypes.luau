--!strict
--[[
    FavoursConfigTypes
    Type definitions for divine favours configuration
]]

-- Chance values are 0-1 (e.g., 0.5 = 50% chance when selected)
export type FavoursTable = {
    [string]: number,
}

export type FavoursConfig = {
    favours: FavoursTable,
}

return nil
