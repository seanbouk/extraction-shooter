# Config Development Guide

This guide explains how to create and use Configs in this Roblox MVC project.

## What is a Config?

Configs are static game data modules that hold values like item prices, spawn rates, level thresholds, and other tunable constants. They are separate from code and designed to be easily adjusted without modifying game logic.

## Architecture Overview

Configs in this project follow a two-part pattern:

1. **Type definitions** (synced via Rojo): Define the structure of your config data
2. **Config modules** (created in Studio): Contain the actual data values

This separation allows:
- Type safety for config data throughout your codebase
- Easy adjustment of values directly in Roblox Studio
- Version control for types without cluttering git with data changes

## File Locations

### Types (Version Controlled)

```
Source/ReplicatedStorage/Config/ConfigTypes/{Name}ConfigTypes.luau
```

Type definition files are synced via Rojo and should be in version control. They define the structure that config modules must follow.

### Config Modules (Studio Only)

```
ReplicatedStorage.Config.{Name}Config (ModuleScript in Studio)
```

Config modules are created directly in Roblox Studio under ReplicatedStorage > Config. They are NOT synced via Rojo because:
- Config data often needs adjustment during playtesting
- Values like prices, rates, and thresholds change frequently
- Rojo's `$ignoreUnknownInstances: true` on the Config folder protects these from deletion

## Config Pattern

### Types File (Source/ReplicatedStorage/Config/ConfigTypes/{Name}ConfigTypes.luau)

```lua
--!strict
--[[
    {Name}ConfigTypes
    Type definitions for {description}
]]

-- Define table types for structured data
export type ItemPricesTable = {
    [string]: number,
}

-- Define the main config type
export type {Name}Config = {
    itemPrices: ItemPricesTable,
    baseMultiplier: number,
}

return nil
```

**Key points:**
- Use `--!strict` for type safety
- Export all types that consumers need
- Return `nil` - this is a types-only module
- Use descriptive names for table types

### Config Module (Created in Studio)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigTypes = ReplicatedStorage:WaitForChild("Config"):WaitForChild("ConfigTypes")
local {Name}ConfigTypes = require(ConfigTypes:WaitForChild("{Name}ConfigTypes"))

type {Name}Config = {Name}ConfigTypes.{Name}Config

local config: {Name}Config = {
    itemPrices = {
        Sword = 100,
        Shield = 75,
        Potion = 25,
    },
    baseMultiplier = 1.5,
}

return config
```

**Key points:**
- Use `--!strict` for type safety
- Import types from ConfigTypes folder
- Create a local type alias for cleaner code
- Annotate the config variable with the type
- Return the config table

## Decision Tree: When to Use Configs

**Question 1: Is this data that might need adjustment during development or playtesting?**
- **Yes** → Use a Config
- **No** → Continue to Question 2

**Question 2: Is this a constant that affects game balance (prices, rates, thresholds)?**
- **Yes** → Use a Config
- **No** → Continue to Question 3

**Question 3: Is this data that designers (non-programmers) might need to modify?**
- **Yes** → Use a Config
- **No** → Consider a constant in the relevant module

### Examples

**Use Configs for:**
- Item prices and costs
- Experience point thresholds
- Spawn rates and probabilities
- Cooldown durations
- Damage/health values
- Level requirements
- Drop tables
- Quest rewards

**Use Models instead when:**
- Data changes at runtime (player inventory, health)
- Data is per-player (user preferences, progress)
- Data needs server authority (game state)

**Use constants in code when:**
- Value never changes (math constants, fixed strings)
- Value is implementation detail (buffer sizes, internal IDs)
- Value is only used in one module

## Example: FavoursConfig

### Types File (FavoursConfigTypes.luau)

```lua
--!strict
--[[
    FavoursConfigTypes
    Type definitions for divine favours configuration
]]

export type FavoursTable = {
    [string]: number,
}

export type FavoursConfig = {
    favours: FavoursTable,
}

return nil
```

### Config Module (Created in Studio)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigTypes = ReplicatedStorage:WaitForChild("Config"):WaitForChild("ConfigTypes")
local FavoursConfigTypes = require(ConfigTypes:WaitForChild("FavoursConfigTypes"))

type FavoursConfig = FavoursConfigTypes.FavoursConfig

local config: FavoursConfig = {
    favours = {
        Blessing = 100,
        Fortune = 250,
        Miracle = 500,
        Divinity = 1000,
    },
}

return config
```

## Using Configs in Code

### In Controllers/Models (Server)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FavoursConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FavoursConfig"))

-- Access config values
local blessingCost = FavoursConfig.favours.Blessing

-- Iterate over config data
for favourName, cost in FavoursConfig.favours do
    print(favourName, cost)
end
```

### In Views (Client)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FavoursConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FavoursConfig"))

-- Display config values in UI
for favourName, cost in FavoursConfig.favours do
    createFavourButton(favourName, cost)
end
```

## Best Practices

### 1. Use Descriptive Type Names

```lua
-- Good: Clear what the table contains
export type ItemPricesTable = {
    [string]: number,
}

-- Avoid: Generic names
export type Table = {
    [string]: number,
}
```

### 2. Group Related Data

```lua
-- Good: Related data in one config
export type ShopConfig = {
    prices: PricesTable,
    discountRates: DiscountTable,
    maxPurchasePerDay: number,
}

-- Avoid: Scattered across multiple configs
```

### 3. Use Consistent Naming

- Config types: `{Name}Config`
- Table types: `{Purpose}Table`
- Files: `{Name}ConfigTypes.luau` (types), `{Name}Config` (module in Studio)

### 4. Document Config Purpose

```lua
--[[
    ShopConfigTypes
    Type definitions for shop pricing and purchase limits

    Used by: ShopController, ShopView
    Updated: When adding new items or adjusting economy
]]
```

### 5. Keep Types and Data Separate

Types in ConfigTypes folder (version controlled):
- Define structure
- Document expected format
- Provide type safety

Config modules in Studio:
- Contain actual values
- Easy to adjust during playtesting
- Not in version control

## Common Patterns

### Tiered Values

```lua
export type TierTable = {
    [string]: number,
}

export type RewardsConfig = {
    tiers: TierTable,
}

-- Usage:
local config: RewardsConfig = {
    tiers = {
        Bronze = 10,
        Silver = 25,
        Gold = 50,
        Platinum = 100,
    },
}
```

### Lookup Tables

```lua
export type ItemStatsTable = {
    [string]: {
        damage: number,
        speed: number,
        range: number,
    },
}

export type WeaponsConfig = {
    weapons: ItemStatsTable,
}
```

### Probability Tables

```lua
export type DropRatesTable = {
    [string]: number, -- 0.0 to 1.0
}

export type LootConfig = {
    dropRates: DropRatesTable,
}
```

## Studio Setup

### Creating a New Config Module

1. Open Roblox Studio
2. Navigate to ReplicatedStorage > Config
3. Right-click Config folder > Insert Object > ModuleScript
4. Name it `{Name}Config` (e.g., `FavoursConfig`)
5. Paste the config module template
6. Fill in your data values
7. Test by requiring it in the command bar:
   ```lua
   local config = require(game.ReplicatedStorage.Config.YourConfig)
   print(config)
   ```

### Verifying Config Structure

After creating a config, verify it matches the types:

1. Require the config in a script
2. If types don't match, you'll get Luau type errors
3. Fix any mismatches between your data and the type definitions

## Troubleshooting

### "Cannot find ConfigTypes"

- Ensure Rojo is running and synced
- Check the file exists in `Source/ReplicatedStorage/Config/ConfigTypes/`
- Verify the filename matches what you're requiring

### "Type mismatch" errors

- Check that your config data matches the exported types
- Ensure all required fields are present
- Verify table key/value types match

### Config not updating in Studio

- Rojo only syncs ConfigTypes, not config modules
- Edit config modules directly in Studio
- Config modules are NOT in version control

## Next Steps

After creating your config:

1. **Use in Controllers** - Access config values for game logic validation
2. **Use in Views** - Display config data in UI elements
3. **Test in Studio** - Verify values work correctly in gameplay
4. **Adjust as needed** - Tune values based on playtesting feedback
