--!strict

--[[
	WeaponSelectorView

	Handles client-side weapon selection UI. Supports clicking buttons
	and pressing number keys (1-6) to select weapons.
	Fires a BindableEvent so other views/controllers can react to selection changes.

	Expected hierarchy:
	PlayerGui
	└── WeaponSelector [ScreenGui, Tagged "WeaponSelector"]
	    └── Frame
	        ├── SelectedValue (Color3Value)
	        ├── 1 Potato (TextButton)
	        ├── 2 Pistol (TextButton)
	        ├── 3 Shot (TextButton)
	        ├── 4 Laser (TextButton)
	        ├── 5 Auto (TextButton)
	        └── 6 Canon (TextButton)
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local UserInputService = game:GetService("UserInputService")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))

local view = AbstractView.new("WeaponSelectorView", "WeaponSelector")

local weaponSelectedEvent = view:createEvent("WeaponSelectedEvent")

type WeaponEntry = {
	index: number,
	name: string,
	button: TextButton,
	originalColor: Color3,
}

local function setupWeaponSelector(screenGui: Instance)
	if not screenGui:IsA("ScreenGui") then
		warn(`WeaponSelectorView: {screenGui.Name} is not a ScreenGui`)
		return
	end

	local frame = screenGui:WaitForChild("Frame")
	local selectedValue = frame:WaitForChild("SelectedValue") :: Color3Value

	-- Collect and parse weapon buttons
	local weapons: { WeaponEntry } = {}

	for _, child in frame:GetChildren() do
		if not child:IsA("TextButton") then
			continue
		end

		local indexStr, weaponName = string.match(child.Name, "^(%d+)%s+(.+)$")
		if indexStr and weaponName then
			table.insert(weapons, {
				index = tonumber(indexStr) :: number,
				name = weaponName,
				button = child :: TextButton,
				originalColor = (child :: TextButton).BackgroundColor3,
			})
		end
	end

	table.sort(weapons, function(a, b)
		return a.index < b.index
	end)

	if #weapons == 0 then
		warn("WeaponSelectorView: No weapon buttons found in Frame")
		return
	end

	local selectedIndex = 1

	local function applySelection()
		for i, weapon in weapons do
			if i == selectedIndex then
				weapon.button.BackgroundColor3 = selectedValue.Value
			else
				weapon.button.BackgroundColor3 = weapon.originalColor
			end
		end
		weaponSelectedEvent:Fire(weapons[selectedIndex].name)
	end

	-- Click to select
	for i, weapon in weapons do
		weapon.button.Activated:Connect(function()
			selectedIndex = i
			applySelection()
		end)
	end

	-- Number keys to select weapon
	local keyToIndex: { [Enum.KeyCode]: number } = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
	}

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		local newIndex = keyToIndex[input.KeyCode]
		if newIndex and newIndex <= #weapons then
			selectedIndex = newIndex
			applySelection()
		end
	end)

	-- Initial selection
	applySelection()
end

view:initialize(setupWeaponSelector)
