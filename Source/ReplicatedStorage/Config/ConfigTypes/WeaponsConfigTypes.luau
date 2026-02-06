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
}

export type WeaponsTable = {
	[string]: WeaponStats,
}

export type WeaponsConfig = {
	weapons: WeaponsTable,
}

return nil
