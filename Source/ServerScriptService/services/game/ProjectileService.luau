--!strict

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProjectilesModel = require(ServerScriptService.models.serverEntities.ProjectilesModel)

local ProjectileService = {}

local CHECK_INTERVAL_SECONDS = 0.5
local PROJECTILE_LIFETIME_SECONDS = 10
local DEBRIS_FALLBACK_SECONDS = 15

local isRunning = false

-- Track spawned parts and their creators for cleanup and collision filtering
local spawnedParts: { [string]: BasePart } = {}
local creatorPlayerIds: { [string]: number } = {}

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

local function spawnProjectilePart(entityId: string, data: any, firingPlayer: Player?): ()
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

	-- Orient cylinder axis (X) along direction vector
	part.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.Angles(0, math.rad(-90), 0)

	-- Physics setup
	part.Anchored = false
	part.CanCollide = true
	part.AssemblyLinearVelocity = direction * data.speed
	part.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)

	part.Parent = workspace

	-- Give the firing player network ownership for smooth client-side physics
	if firingPlayer then
		part:SetNetworkOwner(firingPlayer)
		creatorPlayerIds[entityId] = firingPlayer.UserId
	end

	-- Belt-and-braces backup cleanup via Debris
	Debris:AddItem(part, DEBRIS_FALLBACK_SECONDS)

	-- Track the part for cleanup coordination
	spawnedParts[entityId] = part

	-- Touched connection for collision
	part.Touched:Connect(function(otherPart: BasePart)
		-- Ignore other projectiles (Shot-tagged parts)
		if CollectionService:HasTag(otherPart, "Shot") then
			return
		end

		-- Ignore the firing player's own character
		local creatorId = creatorPlayerIds[entityId]
		if creatorId then
			local creator = Players:GetPlayerByUserId(creatorId)
			if creator and creator.Character and otherPart:IsDescendantOf(creator.Character) then
				return
			end
		end

		-- Destroy the part and remove the model entry
		if spawnedParts[entityId] then
			spawnedParts[entityId] = nil
			creatorPlayerIds[entityId] = nil
			part:Destroy()
			ProjectilesModel.remove(entityId)
			ProjectilesModel.syncAll()
		end
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
		end
		creatorPlayerIds[entityId] = nil
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

function ProjectileService.init()
	print("[ProjectileService] Initializing...")

	-- Find the shot template in ReplicatedStorage
	shotTemplate = findShotTemplate()
	if not shotTemplate then
		warn("[ProjectileService] Could not find 'Shot' tagged Part in ReplicatedStorage")
	end

	-- Register callback for new projectiles
	ProjectilesModel.onCreated(spawnProjectilePart)

	-- Start cleanup loop
	startCleanupLoop()
end

return ProjectileService
