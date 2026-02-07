--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local ProjectilesModel = {}
ProjectilesModel.__index = ProjectilesModel
setmetatable(ProjectilesModel, AbstractModel)

export type ProjectilesModel = typeof(setmetatable({} :: {
	weaponName: string,
	originX: number,
	originY: number,
	originZ: number,
	directionX: number,
	directionY: number,
	directionZ: number,
	speed: number,
	diameter: number,
	length: number,
	colourR: number,
	colourG: number,
	colourB: number,
	createdTime: number,
}, ProjectilesModel)) & AbstractModel.AbstractModel

local _onCreatedCallbacks: { (entityId: string, data: ProjectilesModel, firingPlayer: Player?, sourceModel: Model?) -> () } = {}

function ProjectilesModel.new(entityId: string): ProjectilesModel
	local self = AbstractModel.new("ProjectilesModel", "SERVER", "ServerEntity", entityId) :: any
	setmetatable(self, ProjectilesModel)

	self.weaponName = ""
	self.originX = 0
	self.originY = 0
	self.originZ = 0
	self.directionX = 0
	self.directionY = 0
	self.directionZ = 0
	self.speed = 0
	self.diameter = 0
	self.length = 0
	self.colourR = 0
	self.colourG = 0
	self.colourB = 0
	self.createdTime = 0

	return self :: ProjectilesModel
end

function ProjectilesModel.get(entityId: string): ProjectilesModel
	return AbstractModel.getOrCreate("ProjectilesModel", "SERVER", function()
		return ProjectilesModel.new(entityId)
	end, entityId) :: ProjectilesModel
end

function ProjectilesModel.remove(entityId: string): ()
	AbstractModel.removeServerEntity("ProjectilesModel", entityId)
end

function ProjectilesModel.create(
	entityId: string,
	weaponName: string,
	originX: number, originY: number, originZ: number,
	directionX: number, directionY: number, directionZ: number,
	speed: number,
	diameter: number, length: number,
	colourR: number, colourG: number, colourB: number,
	firingPlayer: Player?,
	sourceModel: Model?
): ProjectilesModel
	local projectile = ProjectilesModel.get(entityId)
	projectile.weaponName = weaponName
	projectile.originX = originX
	projectile.originY = originY
	projectile.originZ = originZ
	projectile.directionX = directionX
	projectile.directionY = directionY
	projectile.directionZ = directionZ
	projectile.speed = speed
	projectile.diameter = diameter
	projectile.length = length
	projectile.colourR = colourR
	projectile.colourG = colourG
	projectile.colourB = colourB
	projectile.createdTime = os.clock()
	projectile:syncState()

	-- Invoke onCreated callbacks
	for _, callback in _onCreatedCallbacks do
		task.spawn(callback, entityId, projectile, firingPlayer, sourceModel)
	end

	return projectile
end

-- Register a callback to be invoked when a new projectile is created
function ProjectilesModel.onCreated(callback: (entityId: string, data: ProjectilesModel, firingPlayer: Player?, sourceModel: Model?) -> ()): ()
	table.insert(_onCreatedCallbacks, callback)
end

-- Get all active projectiles
function ProjectilesModel.getAll(): { [string]: ProjectilesModel }
	return AbstractModel.getAllServerEntities("ProjectilesModel") :: any
end

-- Sync all projectiles to clients (handles empty state case)
function ProjectilesModel.syncAll(): ()
	local all = ProjectilesModel.getAll()
	local anyProjectile = next(all)
	if anyProjectile then
		all[anyProjectile]:syncState()
	else
		-- No projectiles remain - broadcast empty state
		local Network = require(game:GetService("ReplicatedStorage").Network)
		Network.State.Projectiles:Set({})
	end
end

-- Required: Initialize server entities on startup
function ProjectilesModel.initAllServerEntities(): ()
	-- Projectiles are created dynamically via ProjectilesModel.create()
	-- No predefined entities to initialize
end

return ProjectilesModel
