--!strict

--[[
	NPCService

	Spawns NPCs when a player touches an "NPC"-tagged spawner part.
	Each spawner may have at most one living NPC at a time.
	NPCs cycle between walking toward the nearest player and stopping to shoot.

	NPC templates must have these attributes set in Studio:
	  Speed      (number)  – Humanoid WalkSpeed
	  ShootDelay (number)  – seconds of walking before stopping to shoot
	  ShootFor   (number)  – seconds of standing still and shooting
	  Weapon     (string)  – weapon name matching a key in WeaponsConfig
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProjectilesModel = require(ServerScriptService.models.serverEntities.ProjectilesModel)
local WeaponsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponsConfig"))

local NPCService = {}

local npcAssets: Folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("NPCs") :: Folder

type NPCState = {
	npc: Model,
	phase: string, -- "walking" | "shooting"
	phaseStartTime: number,
	lastShotTime: number,
	-- Cached attributes
	shootDelay: number,
	shootFor: number,
	weapon: string,
}

-- Map spawner → its current NPC state (if any)
local npcStates: { [BasePart]: NPCState } = {}

-- Round-robin indices
local spawnerIndex = 0
local npcIndex = 0

-- ID generation for projectiles
local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

local function generateProjectileId(): string
	local id = ""
	for _ = 1, 12 do
		local index = math.random(1, #CHARS)
		id = id .. string.sub(CHARS, index, index)
	end
	return id
end

local function getNearestPlayer(position: Vector3): Player?
	local closest: Player? = nil
	local closestDist = math.huge

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local dist = (root.Position - position).Magnitude
		if dist < closestDist then
			closestDist = dist
			closest = player
		end
	end

	return closest
end

local function getNearestPlayerPosition(position: Vector3): Vector3?
	local player = getNearestPlayer(position)
	if not player or not player.Character then
		return nil
	end
	local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	return root.Position
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local function isPlayerTouching(spawner: BasePart): boolean
	-- Build a filter list of all player characters
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	if #characters == 0 then
		return false
	end

	overlapParams.FilterDescendantsInstances = characters
	local parts = workspace:GetPartsInPart(spawner, overlapParams)
	return #parts > 0
end

local function trySpawnNPC(spawner: BasePart): ()
	-- Already has a living NPC
	local existing = npcStates[spawner]
	if existing and existing.npc.Parent then
		return
	end
	npcStates[spawner] = nil

	-- Need a player touching the spawner
	if not isPlayerTouching(spawner) then
		return
	end

	-- Find the template by the spawner's name
	local template = npcAssets:FindFirstChild(spawner.Name)
	if not template or not template:IsA("Model") then
		warn(`[NPCService] No NPC template found for "{spawner.Name}" in ReplicatedStorage.Assets.NPCs`)
		return
	end

	-- Find spawn attachment
	local attachment = spawner:FindFirstChild("Attachment") :: Attachment?
	if not attachment then
		warn(`[NPCService] Spawner "{spawner.Name}" has no Attachment child`)
		return
	end

	local npc = template:Clone()
	npc:PivotTo(attachment.WorldCFrame)

	-- Set collision group so NPC projectiles pass through NPC bodies
	for _, descendant in npc:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "NPCBody"
		end
	end

	npc.Parent = workspace

	-- Read attributes from the NPC template
	local speed = npc:GetAttribute("Speed") :: number? or 16
	local shootDelay = npc:GetAttribute("ShootDelay") :: number? or 3
	local shootFor = npc:GetAttribute("ShootFor") :: number? or 2
	local weapon = npc:GetAttribute("Weapon") :: string? or "Pistol"

	-- Apply walk speed
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end

	-- Clean up on death: destroy after brief delay so spawner becomes available
	if humanoid then
		humanoid.Died:Connect(function()
			task.delay(0.5, function()
				npc:Destroy()
			end)
		end)
	end

	local now = os.clock()
	npcStates[spawner] = {
		npc = npc,
		phase = "walking",
		phaseStartTime = now,
		lastShotTime = 0,
		shootDelay = shootDelay,
		shootFor = shootFor,
		weapon = weapon,
	}

	print(`[NPCService] Spawned NPC "{spawner.Name}" (weapon={weapon}, speed={speed}, shootDelay={shootDelay}, shootFor={shootFor})`)
end

local function updateNPCMovement(state: NPCState): ()
	if state.phase ~= "walking" then
		return
	end

	local npc = state.npc
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local targetPos = getNearestPlayerPosition(root.Position)
	if not targetPos then
		return
	end

	humanoid:MoveTo(targetPos)
end

local function fireNPCWeapon(state: NPCState): ()
	local npc = state.npc
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local weaponStats = WeaponsConfig.weapons[state.weapon]
	if not weaponStats then
		warn(`[NPCService] Unknown weapon "{state.weapon}" on NPC`)
		return
	end

	local targetPos = getNearestPlayerPosition(root.Position)
	if not targetPos then
		warn("[NPCService] fireNPCWeapon: no target player found")
		return
	end

	print(`[NPCService] NPC firing {state.weapon} ({weaponStats.numberOfProjectiles} projectiles)`)
	local baseDirection = (targetPos - root.Position).Unit
	local origin = root.Position + baseDirection * 2

	for _ = 1, weaponStats.numberOfProjectiles do
		local noiseRad = math.rad(weaponStats.noise)
		local randomYaw = (math.random() * 2 - 1) * noiseRad
		local randomPitch = (math.random() * 2 - 1) * noiseRad
		local noisedDirection = (CFrame.new(Vector3.zero, baseDirection) * CFrame.Angles(randomPitch, randomYaw, 0)).LookVector

		local projectileId = generateProjectileId()
		local colour = weaponStats.colour

		ProjectilesModel.create(
			projectileId,
			state.weapon,
			origin.X, origin.Y, origin.Z,
			noisedDirection.X, noisedDirection.Y, noisedDirection.Z,
			weaponStats.speed,
			weaponStats.diameter, weaponStats.length,
			colour.R, colour.G, colour.B,
			nil, -- no firingPlayer
			npc  -- sourceModel for collision ignore
		)
	end
end

local function updateNPCCombat(state: NPCState): ()
	local npc = state.npc
	local now = os.clock()
	local elapsed = now - state.phaseStartTime

	if state.phase == "walking" then
		if elapsed >= state.shootDelay then
			-- Switch to shooting: stop movement
			state.phase = "shooting"
			state.phaseStartTime = now
			state.lastShotTime = 0 -- allow immediate first shot
			print(`[NPCService] NPC entering shooting phase (weapon={state.weapon})`)

			local humanoid = npc:FindFirstChildOfClass("Humanoid")
			if humanoid then
				-- Stop walking by moving to current position
				local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					humanoid:MoveTo(root.Position)
				end
			end
		end
	elseif state.phase == "shooting" then
		if elapsed >= state.shootFor then
			-- Switch back to walking
			state.phase = "walking"
			state.phaseStartTime = now
			return
		end

		-- Fire based on weapon auto interval
		local weaponStats = WeaponsConfig.weapons[state.weapon]
		if not weaponStats then
			warn(`[NPCService] No weapon stats for "{state.weapon}" — check NPC Weapon attribute matches a WeaponsConfig key`)
			return
		end

		local timeSinceLastShot = now - state.lastShotTime
		if weaponStats.auto > 0 then
			-- Auto weapon: fire at the auto interval rate
			if timeSinceLastShot >= weaponStats.auto then
				state.lastShotTime = now
				fireNPCWeapon(state)
			end
		else
			-- Semi-auto weapon: fire once at the start of the shooting phase
			if state.lastShotTime == 0 then
				state.lastShotTime = now
				fireNPCWeapon(state)
			end
		end
	end
end

function NPCService.init()
	print("[NPCService] Initializing...")

	RunService.Heartbeat:Connect(function()
		-- Round-robin: check one spawner per heartbeat
		local spawners = CollectionService:GetTagged("NPC")
		if #spawners > 0 then
			spawnerIndex = spawnerIndex % #spawners + 1
			local spawner = spawners[spawnerIndex]
			if spawner:IsA("BasePart") then
				trySpawnNPC(spawner)
			end
		end

		-- Collect alive NPC states
		local aliveStates: { NPCState } = {}
		for spawner, state in npcStates do
			if state.npc.Parent then
				table.insert(aliveStates, state)
			else
				npcStates[spawner] = nil
			end
		end

		-- Round-robin: update one NPC's movement per heartbeat
		if #aliveStates > 0 then
			npcIndex = npcIndex % #aliveStates + 1
			updateNPCMovement(aliveStates[npcIndex])
		end

		-- All NPCs: update combat state & shooting (cheap per-NPC)
		for _, state in aliveStates do
			updateNPCCombat(state)
		end
	end)
end

return NPCService
