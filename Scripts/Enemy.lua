Enemy = {}

local function ProjectOnPlane(v, normal)
    local length = normal:Magnitude()
    if length < 0.0001 then
        return v
    end

    local n = normal / length
    return v - n * Vector.Dot(v, n)
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

    self.player = nil
    self.turnPhase = 0.0
    self.hitCooldown = 0.0
    self.bounceTimer = 0.0
    self.stunRadiusSq = 1.21
    self.lastNormal = Vec()
    self.initialized = false
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
    self.initialized = false

    self:AddTag("Enemy")
    self:EnableCollision(false)
    self:EnableOverlaps(false)

    local world = self:GetWorld()
    if world then
        self.player = world:FindNode("ThirdPersonPlayer")
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

    local startPos = self:GetWorldPosition()
    self:SetWorldPosition(startPos + forward * speed * dt)

    local downUp = self:GetUpVector()
    local downStart = self:GetWorldPosition() + downUp * 0.2
    self:SetWorldPosition(downStart)

    local downEnd = downStart - downUp * self.snapDistance
    local downResult = self:SweepToWorldPosition(downEnd, 2)

    if downResult.hitNode then
        local normal = downResult.hitNormal
        local newForward = ProjectOnPlane(forward, normal)
        if newForward:Magnitude() > 0.001 then
            forward = newForward:Normalize()
        end
        self.lastNormal = normal
        self:LookAt(self:GetWorldPosition() + forward, normal)
    else
        self:SetWorldPosition(startPos)
        self:Reverse()
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

function Enemy:TryHitPlayer()
    if self.hitCooldown > 0.0 then
        return
    end

    self.hitCooldown = self.hitCooldownDuration
    Log.Debug("Enemy: hit player")
    SignalBus.Emit("PlayerStunned", self.stunDuration)
end

function Enemy:Reverse()
    self.bounceTimer = self.bounceDuration
    self:LookAt(self:GetWorldPosition() - self:GetForwardVector(), self:GetUpVector())
end
