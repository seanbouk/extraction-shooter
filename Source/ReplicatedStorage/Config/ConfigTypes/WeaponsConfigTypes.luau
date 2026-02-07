--!strict
--[[
    WeaponsConfigTypes
    Type definitions for weapons configuration
]]

export type SoundConfig = {
	volume: number,
	playbackSpeed: number,
	eqLow: number,
	eqMid: number,
	eqHigh: number,
	reverb: number,
	echo: number,
	chorus: number,
	distortion: number,
}

export type WeaponStats = {
	numberOfProjectiles: number,
	colour: Color3,
	diameter: number,
	length: number,
	speed: number,
	noise: number, -- degrees of spread
	auto: number, -- 0 = semi-auto (fire per click), >0 = auto-fire interval in seconds
	icon: string,
	impact: number,
	sound: SoundConfig,
}

export type WeaponsTable = {
	[string]: WeaponStats,
}

export type WeaponsConfig = {
	weapons: WeaponsTable,
}

return nil
