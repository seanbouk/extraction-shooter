--!strict

--[[
	NPCService

	Spawns NPCs when a player touches an "NPC"-tagged spawner part.
	Each spawner may have at most one living NPC at a time.
	NPCs walk toward the nearest player, updated one-per-heartbeat in round-robin.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NPCService = {}

local npcAssets: Folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("NPCs") :: Folder

-- Map spawner → its currently alive NPC (if any)
local spawnedNPCs: { [BasePart]: Model } = {}

-- Round-robin indices
local spawnerIndex = 0
local npcIndex = 0

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
	local existing = spawnedNPCs[spawner]
	if existing and existing.Parent then
		return
	end
	spawnedNPCs[spawner] = nil

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
	npc.Parent = workspace

	spawnedNPCs[spawner] = npc
	print(`[NPCService] Spawned NPC "{spawner.Name}"`)
end

local function updateNPCMovement(npc: Model): ()
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local nearestPlayer = getNearestPlayer(root.Position)
	if not nearestPlayer or not nearestPlayer.Character then
		return
	end

	local targetRoot = nearestPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	humanoid:MoveTo(targetRoot.Position)
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

		-- Round-robin: update one NPC per heartbeat
		local npcs: { Model } = {}
		for _, npc in spawnedNPCs do
			if npc.Parent then
				table.insert(npcs, npc)
			end
		end
		if #npcs > 0 then
			npcIndex = npcIndex % #npcs + 1
			updateNPCMovement(npcs[npcIndex])
		end
	end)
end

return NPCService
