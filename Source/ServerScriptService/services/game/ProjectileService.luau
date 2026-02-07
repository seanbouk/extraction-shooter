--!strict

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProjectilesModel = require(ServerScriptService.models.serverEntities.ProjectilesModel)
local WeaponsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("WeaponsConfig"))

local ProjectileService = {}

local avatarHitEvent = Instance.new("RemoteEvent")
avatarHitEvent.Name = "AvatarHitEvent"
avatarHitEvent.Parent = ReplicatedStorage

local CHECK_INTERVAL_SECONDS = 0.5
local PROJECTILE_LIFETIME_SECONDS = 10
local DEBRIS_FALLBACK_SECONDS = 15

local isRunning = false

-- Track spawned parts for cleanup coordination
local spawnedParts: { [string]: BasePart } = {}

-- Per-projectile metadata for raycast hit detection
type ProjectileMeta = {
	previousPosition: Vector3,
	weaponName: string,
	sourceModel: Model?,
	firingPlayer: Player?,
}
local projectileMeta: { [string]: ProjectileMeta } = {}

-- Shared RaycastParams (filter list updated per-ray)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local shotTemplate: BasePart? = nil

local function findShotTemplate(): BasePart?
	local tagged = CollectionService:GetTagged("Shot")
	for _, instance in tagged do
		if instance:IsDescendantOf(ReplicatedStorage) and instance:IsA("BasePart") then
			return instance :: BasePart
		end
	end
	return nil
end

local function spawnProjectilePart(entityId: string, data: any, firingPlayer: Player?, sourceModel: Model?): ()
	if not shotTemplate then
		warn("[ProjectileService] No shot template found")
		return
	end

	local part = shotTemplate:Clone()

	-- Reconstruct vectors from decomposed floats
	local origin = Vector3.new(data.originX, data.originY, data.originZ)
	local direction = Vector3.new(data.directionX, data.directionY, data.directionZ)

	-- Size: cylinder X=length axis, Y/Z=diameter
	part.Size = Vector3.new(data.length, data.diameter, data.diameter)

	-- Color
	part.Color = Color3.new(data.colourR, data.colourG, data.colourB)

	-- Inherit the firing player's velocity so slow projectiles don't fall behind
	local playerVelocity = Vector3.zero
	if firingPlayer and firingPlayer.Character then
		local humanoid = firingPlayer.Character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			playerVelocity = humanoid.MoveDirection * humanoid.WalkSpeed
		end
	end

	local totalVelocity = direction * data.speed + playerVelocity

	-- Orient cylinder axis (X) along the actual travel direction (includes player velocity)
	local travelDirection = totalVelocity.Unit
	part.CFrame = CFrame.lookAt(origin, origin + travelDirection) * CFrame.Angles(0, math.rad(-90), 0)

	-- Use a LinearVelocity constraint instead of AssemblyLinearVelocity.
	-- Constraints are Instances (children of the part) that replicate WITH the part,
	-- so the client receives the velocity when it gets network ownership.
	-- AssemblyLinearVelocity is physics state that gets lost during ownership transfer.
	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local velocityConstraint = Instance.new("LinearVelocity")
	velocityConstraint.Attachment0 = attachment
	velocityConstraint.MaxForce = math.huge
	velocityConstraint.VectorVelocity = totalVelocity
	velocityConstraint.RelativeTo = Enum.ActuatorRelativeTo.World
	velocityConstraint.Parent = part

	-- Actively align orientation to the correct flight direction
	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.CFrame = part.CFrame
	alignOrientation.MaxTorque = math.huge
	alignOrientation.Responsiveness = 200
	alignOrientation.Parent = part

	-- Physics setup
	part.Anchored = false

	part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)

	-- NPC projectiles: use collision group so they pass through the NPC body
	if sourceModel then
		part.CollisionGroup = "NPCProjectile"
	end

	part.Parent = workspace

	-- Immediate network ownership — the LinearVelocity constraint replicates
	-- as a child of the part, so the client has the velocity from frame one.
	if firingPlayer then
		part:SetNetworkOwner(firingPlayer)
	else
		-- NPC projectile: assign nearest player so their client simulates physics
		local bestPlayer: Player? = nil
		local bestDist = math.huge
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local dist = (root.Position - origin).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestPlayer = player
					end
				end
			end
		end
		part:SetNetworkOwner(bestPlayer)
	end

	print(string.format(
		"[SVC] entityId=%s speed=%.1f playerVel=(%.1f,%.1f,%.1f) totalVel=(%.1f,%.1f,%.1f) dir=(%.2f,%.2f,%.2f)",
		entityId, data.speed,
		playerVelocity.X, playerVelocity.Y, playerVelocity.Z,
		totalVelocity.X, totalVelocity.Y, totalVelocity.Z,
		direction.X, direction.Y, direction.Z
	))

	-- Belt-and-braces backup cleanup via Debris
	Debris:AddItem(part, DEBRIS_FALLBACK_SECONDS)

	-- Track the part for cleanup coordination
	spawnedParts[entityId] = part
	projectileMeta[entityId] = {
		previousPosition = origin,
		weaponName = data.weaponName,
		sourceModel = sourceModel,
		firingPlayer = firingPlayer,
	}

	-- Touched connection for collision
	part.Touched:Connect(function(otherPart: BasePart)
		-- Ignore other projectiles (Shot-tagged parts)
		if CollectionService:HasTag(otherPart, "Shot") then
			return
		end

		-- Ignore the source model (NPC or player character)
		local ignoreModel = sourceModel or (firingPlayer and firingPlayer.Character)
		if ignoreModel and otherPart:IsDescendantOf(ignoreModel) then
			return
		end

		-- Early-return if already processed (prevents double-damage from Touched + raycast)
		if not spawnedParts[entityId] then
			return
		end
		spawnedParts[entityId] = nil
		projectileMeta[entityId] = nil

		-- Apply damage if we hit a character with a Humanoid
		local hitModel = otherPart.Parent
		if hitModel then
			local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local weaponStats = WeaponsConfig.weapons[data.weaponName]
				if weaponStats and weaponStats.impact then
					humanoid:TakeDamage(weaponStats.impact)
				end
				avatarHitEvent:FireAllClients(part.Position)
			end
		end

		-- Destroy the projectile and clean up
		part:Destroy()
		ProjectilesModel.remove(entityId)
		ProjectilesModel.syncAll()
	end)
end

local function removeExpiredProjectiles(): ()
	local currentTime = os.clock()
	local allProjectiles = ProjectilesModel.getAll()
	local toRemove: { string } = {}

	for entityId, projectile in allProjectiles do
		if currentTime - projectile.createdTime >= PROJECTILE_LIFETIME_SECONDS then
			table.insert(toRemove, entityId)
		end
	end

	for _, entityId in toRemove do
		-- Destroy the tracked part if it still exists
		local part = spawnedParts[entityId]
		if part then
			part:Destroy()
			spawnedParts[entityId] = nil
			projectileMeta[entityId] = nil
		end
		ProjectilesModel.remove(entityId)
	end

	if #toRemove > 0 then
		ProjectilesModel.syncAll()
	end
end

local function startCleanupLoop()
	if isRunning then
		return
	end
	isRunning = true

	task.spawn(function()
		while true do
			removeExpiredProjectiles()
			task.wait(CHECK_INTERVAL_SECONDS)
		end
	end)
end

-- Raycast from previous→current position each frame to catch fast projectiles
-- that tunnel through characters between physics steps.
local function raycastStep(): ()
	for entityId, part in spawnedParts do
		local meta = projectileMeta[entityId]
		if not meta then
			continue
		end

		local currentPos = part.Position
		local prevPos = meta.previousPosition
		local sweep = currentPos - prevPos
		local distance = sweep.Magnitude
		meta.previousPosition = currentPos

		if distance < 0.01 then
			continue
		end

		-- Build exclude list: all Shot-tagged parts + source model
		local excludeList: { Instance } = CollectionService:GetTagged("Shot")
		local ignoreModel: Model? = meta.sourceModel or (meta.firingPlayer and meta.firingPlayer.Character)
		if ignoreModel then
			table.insert(excludeList, ignoreModel)
		end
		raycastParams.FilterDescendantsInstances = excludeList

		local result = workspace:Raycast(prevPos, sweep, raycastParams)
		if not result then
			continue
		end

		local hitModel = result.Instance.Parent
		if not hitModel then
			continue
		end

		local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			continue
		end

		-- Guard against double-processing (raycast + Touched race)
		if not spawnedParts[entityId] then
			continue
		end
		spawnedParts[entityId] = nil
		projectileMeta[entityId] = nil

		local weaponStats = WeaponsConfig.weapons[meta.weaponName]
		if weaponStats and weaponStats.impact then
			humanoid:TakeDamage(weaponStats.impact)
		end
		avatarHitEvent:FireAllClients(result.Position)

		part:Destroy()
		ProjectilesModel.remove(entityId)
		ProjectilesModel.syncAll()
	end
end

function ProjectileService.init()
	print("[ProjectileService] Initializing...")

	-- Collision groups: NPC projectiles pass through NPC bodies
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, "NPCProjectile")
	pcall(PhysicsService.RegisterCollisionGroup, PhysicsService, "NPCBody")
	PhysicsService:CollisionGroupSetCollidable("NPCProjectile", "NPCBody", false)

	-- Find the shot template in ReplicatedStorage
	shotTemplate = findShotTemplate()
	if not shotTemplate then
		warn("[ProjectileService] Could not find 'Shot' tagged Part in ReplicatedStorage")
	end

	-- Register callback for new projectiles
	ProjectilesModel.onCreated(spawnProjectilePart)

	-- Raycast sweep every frame to catch fast projectiles tunnelling through characters
	RunService.Heartbeat:Connect(raycastStep)

	-- Start cleanup loop
	startCleanupLoop()
end

return ProjectileService
