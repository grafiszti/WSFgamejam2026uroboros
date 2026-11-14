Enemy = {}

Enemy.activeEnemies = {}

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
    self.enemyRadius = 0.5
    self.enemyBounceCooldown = 0.5

    self.player = nil
    self.turnPhase = 0.0
    self.hitCooldown = 0.0
    self.bounceTimer = 0.0
    self.enemyCooldown = 0.0
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
        { name = "enemyRadius", type = DatumType.Float },
        { name = "enemyBounceCooldown", type = DatumType.Float },
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
    self.enemyRadius = math.max(0.1, self.enemyRadius or 0.5)
    self.enemyBounceCooldown = math.max(0.0, self.enemyBounceCooldown or 0.5)

    self.stunRadiusSq = self.stunRadius * self.stunRadius
    self.turnPhase = 0.0
    self.hitCooldown = 0.5
    self.bounceTimer = 0.0
    self.enemyCooldown = 0.0
    self.player = nil
    self.initialized = false

    self:AddTag("Enemy")
    self:Register()

    local world = self:GetWorld()
    if world then
        self.player = world:FindNode("ThirdPersonPlayer")
    end

    self:SnapToSurface()
    self.initialized = true
end

function Enemy:Register()
    local list = Enemy.activeEnemies
    for i = 1, #list do
        if list[i] == self then
            return
        end
    end
    list[#list + 1] = self
end

function Enemy:Unregister()
    local list = Enemy.activeEnemies
    for i = #list, 1, -1 do
        if list[i] == self then
            table.remove(list, i)
            return
        end
    end
end

function Enemy:Stop()
    self:Unregister()
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
    self.enemyCooldown = math.max(0.0, self.enemyCooldown - dt)

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
    local moveEnd = startPos + forward * speed * dt
    local moveResult = self:SweepToWorldPosition(moveEnd, 1)

    if moveResult.hitNode then
        local hit = moveResult.hitNode
        self:SetWorldPosition(startPos)
        if hit:HasTag("Player") then
            self:TryHitPlayer()
        elseif hit:HasTag("Enemy") then
            self:BounceFrom(hit, self:GetUpVector())
        else
            self:Reverse()
        end
        self:CheckEnemyCollisions()
        return
    end

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
        self:CheckPlayerDistance()
        self:CheckEnemyCollisions()
    else
        self:SetWorldPosition(startPos)
        self:Reverse()
        self:CheckEnemyCollisions()
    end
end

function Enemy:CheckEnemyCollisions()
    local list = Enemy.activeEnemies
    if #list <= 1 then
        return
    end

    local pos = self:GetWorldPosition()
    local up = self:GetUpVector()

    for i = 1, #list do
        local other = list[i]
        if other ~= self and other:IsValid() then
            local otherPos = other:GetWorldPosition()
            local dx = pos.x - otherPos.x
            local dy = pos.y - otherPos.y
            local dz = pos.z - otherPos.z
            local minDist = self.enemyRadius * 2.0
            if dx * dx + dy * dy + dz * dz < minDist * minDist then
                self:BounceFrom(other, up)
                pos = self:GetWorldPosition()
            end
        end
    end
end

function Enemy:BounceFrom(other, up)
    local pos = self:GetWorldPosition()
    local otherPos = other:GetWorldPosition()
    local away = ProjectOnPlane(pos - otherPos, up)
    if away:Magnitude() < 0.001 then
        away = -self:GetForwardVector()
    end
    away = away:Normalize()

    local minDist = self.enemyRadius * 2.0
    local dist = Vector.Distance(pos, otherPos)
    if dist > 0.0001 and dist < minDist then
        local push = (minDist - dist) * 0.5
        self:SetWorldPosition(pos + away * push)
    end

    if self.enemyCooldown <= 0.0 then
        self:LookAt(self:GetWorldPosition() + away, up)
        self.bounceTimer = self.bounceDuration
        self.enemyCooldown = self.enemyBounceCooldown
    end
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
    self.bounceTimer = self.bounceDuration
    Log.Debug("Enemy: hit player")
    SignalBus.Emit("PlayerStunned", self.stunDuration)
    self:Reverse()
end

function Enemy:Reverse()
    self.bounceTimer = self.bounceDuration
    self:LookAt(self:GetWorldPosition() - self:GetForwardVector(), self:GetUpVector())
end

function Enemy:BeginOverlap(me, other)
    if other:HasTag("Player") then
        self:TryHitPlayer()
    elseif other:HasTag("Enemy") then
        self:BounceFrom(other, self:GetUpVector())
    end
end
