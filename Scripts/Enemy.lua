Script.Load("Core/GameSession")
Script.Load("Core/SurfaceMath")
Script.Load("Systems/EnemyMotor")
Script.Load("Systems/EnemyContact")

Enemy = {}

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
    self.hitCooldown = 1.5
    self.bounceTimer = 0.0
    self.player = nil
    self.world = self:GetWorld()
    self.lastGroundPos = nil
    self.initialized = false
    self.surfaceLostWarned = false

    EnemyContact.LoadAssets(self)

    self:AddTag("Enemy")
    self:EnableCollision(false)
    self:EnableOverlaps(false)
    DisableChildCollision(self)

    if self.world then
        self.player = self.world:FindNode("ThirdPersonPlayer")
    end

    EnemyMotor.SnapToSurface(self)
    self.initialized = true
end

function Enemy:Tick(deltaTime)
    if not self.initialized or not GameSession.IsPlaying() then
        return
    end

    local dt = math.min(deltaTime, 0.05)
    if dt <= 0.0 then
        return
    end

    self.hitCooldown = math.max(0.0, self.hitCooldown - dt)
    self.bounceTimer = math.max(0.0, self.bounceTimer - dt)

    local up = SurfaceMath.SafeNormalize(self:GetUpVector(), Vec(0.0, 1.0, 0.0))
    self.turnPhase = self.turnPhase + self.turnFrequency * 6.2831853 * dt
    local turn = math.sin(self.turnPhase) * self.turnRate * dt

    local forward = Vector.Rotate(self:GetForwardVector(), turn, up)
    forward = SurfaceMath.ProjectOnPlane(forward, up)
    if forward:Magnitude() < 0.001 then
        forward = self:GetForwardVector()
    end
    forward = SurfaceMath.SafeNormalize(forward, self:GetForwardVector())

    local speed = self.moveSpeed
    if self.bounceTimer > 0.0 then
        speed = self.bounceSpeed
    end

    local moved = EnemyMotor.MoveOnSurface(self, forward, speed, dt)

    if not moved then
        forward = -forward
        self.bounceTimer = self.bounceDuration
        moved = EnemyMotor.MoveOnSurface(self, forward, self.bounceSpeed, dt)

        if not moved then
            EnemyMotor.RestoreSurface(self)
        end
    end

    EnemyContact.CheckPlayerDistance(self)
end
