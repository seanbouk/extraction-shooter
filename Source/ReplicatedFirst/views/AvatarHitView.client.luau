--!strict

--[[
	AvatarHitView

	Listens for avatar hit events from the server and spawns the Hit
	particle effect at the impact position.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hitTemplate: BasePart = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Hit") :: BasePart
local avatarHitEvent: RemoteEvent = ReplicatedStorage:WaitForChild("AvatarHitEvent") :: RemoteEvent

avatarHitEvent.OnClientEvent:Connect(function(position: Vector3)
	local hitPart = hitTemplate:Clone()
	hitPart.CFrame = CFrame.new(position)
	hitPart.Parent = workspace

	local emitter = hitPart:FindFirstChildWhichIsA("ParticleEmitter") :: ParticleEmitter?
	if not emitter then
		hitPart:Destroy()
		return
	end

	local count = emitter.Rate
	emitter:Emit(count)
	emitter.Rate = 0

	Debris:AddItem(hitPart, emitter.Lifetime.Max + 0.2)
end)
