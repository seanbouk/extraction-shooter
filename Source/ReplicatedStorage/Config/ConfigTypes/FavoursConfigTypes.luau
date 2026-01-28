--!strict
--[[
    FavoursConfigTypes
    Type definitions for divine favours configuration
]]

export type FavourName =
    -- Common favours
    | "CandleOfDevotion"
    | "BlessedCoin"
    | "PrayerBeads"
    | "SacredAsh"
    | "HolyWaterVial"
    -- Uncommon favours
    | "InscribedTalisman"
    | "IdolFragment"
    | "OracleScroll"
    | "AnointedCharm"
    -- Rare favours
    | "RelicShard"
    | "DivineSigil"
    -- Very rare favours
    | "GodlyEmblem"
    | "MiracleToken"

export type FavoursTable = {
    [FavourName]: number,
}

export type FavoursConfig = {
    favours: FavoursTable,
}

return nil
