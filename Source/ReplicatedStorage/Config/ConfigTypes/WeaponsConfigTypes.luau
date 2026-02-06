--!strict
--[[
    WeaponsConfigTypes
    Type definitions for weapons configuration
]]

export type WeaponStats = {
	numberOfProjectiles: number,
	colour: Color3,
	diameter: number,
	length: number,
	speed: number,
	noise: number, -- degrees of spread
	auto: number, -- 0 = semi-auto (fire per click), >0 = auto-fire interval in seconds
}

export type WeaponsTable = {
	[string]: WeaponStats,
}

export type WeaponsConfig = {
	weapons: WeaponsTable,
}

return nil
