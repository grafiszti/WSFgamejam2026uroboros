Enemy = {}

local STUN_PARTICLE = "PlayerStunnedParticle"
local STUN_PARTICLE_MATERIAL = "ParticleMaterial"
local sStunParticleWarned = false
local sStunMaterialWarned = false

local function ProjectOnPlane(v, normal)
    local length = normal:Magnitude()
    if length < 0.0001 then
        return v
    end

    local n = normal / length
    return v - n * Vector.Dot(v, n)
end

local function DisableChildCollision(node)
    for i = 1, node:GetNumChildren() do
        local child = node:GetChild(i)
        if child:IsA("Primitive3D") then
            child:EnableCollision(false)
            child:EnableOverlaps(false)
        end
        DisableChildCollision(child)
    end
end

function Enemy:Create()
    self.moveSpeed = 9.0
    self.bounceSpeed = 14.0
    self.turnRate = 0.7
    self.turnFrequency = 0.35
    self.snapDistance = 20.0
    self.stunRadius = 1.1
    self.stunDuration = 2.0
    self.hitCooldownDuration = 0.9
    self.bounceDuration = 0.35

    self.world = nil
    self.player = nil
    self.turnPhase = 0.0
    self.hitCooldown = 0.0
    self.bounceTimer = 0.0
    self.stunRadiusSq = 1.21
    self.lastNormal = Vec()
    self.lastGroundPos = nil
    self.initialized = false
    self.surfaceLostWarned = false
    self.stunParticle = nil
    self.stunParticleMaterial = nil
end

function Enemy:GatherProperties()
    return {
        { name = "moveSpeed", type = DatumType.Float },
        { name = "bounceSpeed", type = DatumType.Float },
        { name = "turnRate", type = DatumType.Float },
        { name = "turnFrequency", type = DatumType.Float },
        { name = "snapDistance", type = DatumType.Float },
        { name = "stunRadius", type = DatumType.Float },
        { name = "stunDuration", type = DatumType.Float },
        { name = "hitCooldownDuration", type = DatumType.Float },
        { name = "bounceDuration", type = DatumType.Float },
    }
end

function Enemy:Start()
    self.moveSpeed = math.max(0.1, self.moveSpeed or 9.0)
    self.bounceSpeed = math.max(self.moveSpeed, self.bounceSpeed or 14.0)
    self.turnRate = math.max(0.0, self.turnRate or 0.7)
    self.turnFrequency = math.max(0.0, self.turnFrequency or 0.35)
    self.snapDistance = math.max(1.0, self.snapDistance or 20.0)
    self.stunRadius = math.max(0.1, self.stunRadius or 1.1)
    self.stunDuration = math.max(0.1, self.stunDuration or 2.0)
    self.hitCooldownDuration = math.max(0.0, self.hitCooldownDuration or 0.9)
    self.bounceDuration = math.max(0.0, self.bounceDuration or 0.35)

    self.stunRadiusSq = self.stunRadius * self.stunRadius
    self.turnPhase = 0.0
    self.hitCooldown = 0.5
    self.bounceTimer = 0.0
    self.player = nil
    self.world = self:GetWorld()
    self.lastGroundPos = nil
    self.initialized = false
    self.surfaceLostWarned = false

    self.stunParticle = LoadAsset(STUN_PARTICLE)
    if self.stunParticle == nil and not sStunParticleWarned then
        sStunParticleWarned = true
        Log.Warning("Enemy: missing particle " .. STUN_PARTICLE)
    end

    self.stunParticleMaterial = LoadAsset(STUN_PARTICLE_MATERIAL)
    if self.stunParticleMaterial == nil and not sStunMaterialWarned then
        sStunMaterialWarned = true
        Log.Warning("Enemy: missing material " .. STUN_PARTICLE_MATERIAL)
    end

    self:AddTag("Enemy")
    self:EnableCollision(false)
    self:EnableOverlaps(false)
    DisableChildCollision(self)

    if self.world then
        self.player = self.world:FindNode("ThirdPersonPlayer")
    end

    self:SnapToSurface()
    self.initialized = true
end

function Enemy:SnapToSurface()
    local up = self:GetUpVector()
    local startPos = self:GetWorldPosition() + up * 0.5
    self:SetWorldPosition(startPos)

    local endPos = startPos - up * self.snapDistance
    local result = self:SweepToWorldPosition(endPos, 2)
    if not result.hitNode then
        Log.Warning("Enemy: could not find roller surface at spawn")
        return
    end

    local normal = result.hitNormal
    local position = self:GetWorldPosition()
    local forward = self:GetForwardVector()

    if self.player then
        local playerPosition = self.player:GetWorldPosition()
        forward = ProjectOnPlane(playerPosition - position, normal)
    end

    forward = ProjectOnPlane(forward, normal)
    if forward:Magnitude() < 0.001 then
        forward = self:GetForwardVector()
    end
    forward = forward:Normalize()

    self:LookAt(position + forward, normal)
    self.lastNormal = normal
    self.lastGroundPos = position
end

function Enemy:ProbeSurface(center, up)
    if not self.world then
        return nil
    end

    local startPos = center + up * self.snapDistance
    local endPos = center - up * self.snapDistance
    local result = self.world:SweepTest(self, startPos, endPos, 2)
    if not result or not result.hitNode or result.hitFraction >= 1.0 then
        return nil
    end

    local node = result.hitNode
    while node ~= nil and node ~= self do
        node = node:GetParent()
    end
    if node == self then
        return nil
    end

    local hitCenter = Vector.Lerp(startPos, endPos, result.hitFraction)
    hitCenter = hitCenter + result.hitNormal * 0.002
    return hitCenter, result.hitNormal
end

function Enemy:MoveOnSurface(forward, speed, dt)
    local startPos = self:GetWorldPosition()
    local up = self:GetUpVector()
    local targetPos = startPos + forward * speed * dt
    local hitCenter, hitNormal = self:ProbeSurface(targetPos, up)
    if not hitCenter then
        return false
    end

    self:SetWorldPosition(hitCenter)

    local newForward = ProjectOnPlane(forward, hitNormal)
    if newForward:Magnitude() > 0.001 then
        forward = newForward:Normalize()
    end
    self.lastNormal = hitNormal
    self.lastGroundPos = hitCenter
    self.surfaceLostWarned = false
    self:LookAt(self:GetWorldPosition() + forward, hitNormal)
    return true
end

function Enemy:Tick(deltaTime)
    if not self.initialized then
        return
    end

    local dt = math.min(deltaTime, 0.05)
    if dt <= 0.0 then
        return
    end

    self.hitCooldown = math.max(0.0, self.hitCooldown - dt)
    self.bounceTimer = math.max(0.0, self.bounceTimer - dt)

    local up = self:GetUpVector()
    self.turnPhase = self.turnPhase + self.turnFrequency * 6.2831853 * dt
    local turn = math.sin(self.turnPhase) * self.turnRate * dt

    local forward = Vector.Rotate(self:GetForwardVector(), turn, up)
    forward = ProjectOnPlane(forward, up)
    if forward:Magnitude() < 0.001 then
        forward = self:GetForwardVector()
    end
    forward = forward:Normalize()

    local speed = self.moveSpeed
    if self.bounceTimer > 0.0 then
        speed = self.bounceSpeed
    end

    local moved = self:MoveOnSurface(forward, speed, dt)

    if not moved then
        forward = -forward
        self.bounceTimer = self.bounceDuration
        moved = self:MoveOnSurface(forward, self.bounceSpeed, dt)

        if not moved then
            local upNow = self:GetUpVector()
            local hitCenter, hitNormal = self:ProbeSurface(self:GetWorldPosition(), upNow)
            if hitCenter then
                self:SetWorldPosition(hitCenter)
                self.lastNormal = hitNormal
                self.lastGroundPos = hitCenter
            else
                if self.lastGroundPos then
                    self:SetWorldPosition(self.lastGroundPos)
                end
                if not self.surfaceLostWarned then
                    self.surfaceLostWarned = true
                    Log.Warning("Enemy: lost roller surface")
                end
            end
        end
    end

    self:CheckPlayerDistance()
end

function Enemy:CheckPlayerDistance()
    if self.hitCooldown > 0.0 or not self.player then
        return
    end

    local a = self:GetWorldPosition()
    local b = self.player:GetWorldPosition()
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z

    if dx * dx + dy * dy + dz * dz <= self.stunRadiusSq then
        self:TryHitPlayer()
    end
end

function Enemy:SpawnStunParticle()
    if not self.stunParticle then
        return
    end

    local world = self:GetWorld()
    if not world then
        return
    end

    local position = self:GetWorldPosition()
    if self.player then
        position = self.player:GetWorldPosition()
    end

    local particle = world:SpawnParticle(self.stunParticle, position)
    if particle then
        if self.stunParticleMaterial then
            particle:SetMaterialOverride(self.stunParticleMaterial)
        end
        if TargetScreen then
            particle:SetTargetScreen(TargetScreen.Top)
        end
    end
end

function Enemy:TryHitPlayer()
    if self.hitCooldown > 0.0 then
        return
    end

    self.hitCooldown = self.hitCooldownDuration
    Log.Debug("Enemy: hit player")
    self:SpawnStunParticle()
    SignalBus.Emit("PlayerStunned", self.stunDuration)
end
