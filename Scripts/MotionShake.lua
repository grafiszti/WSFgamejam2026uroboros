MotionShake = {}

local EPSILON = 0.0001

function MotionShake:Create()
    self.enabled = true
    self.upThreshold = 0.35
    self.releaseThreshold = 0.12
    self.cooldown = 0.75
    self.smoothing = 8.0
    self.calibrationTime = 0.5
    self.invertUp = false
    self.useGyro = false
    self.gyroThreshold = 1.5
    self.enableButtonFallback = true

    self.gravityX = 0.0
    self.gravityY = 0.0
    self.gravityZ = 1.0
    self.hasGravity = false
    self.calibrationTimer = 0.0
    self.cooldownTimer = 0.0
    self.armed = false
    self.shakePending = false
    self.intensity = 0.0
    self.shakeCount = 0
    self.calibrated = false
end

function MotionShake:GatherProperties()
    return
    {
        { name = "enabled", type = DatumType.Bool },
        { name = "upThreshold", type = DatumType.Float },
        { name = "releaseThreshold", type = DatumType.Float },
        { name = "cooldown", type = DatumType.Float },
        { name = "smoothing", type = DatumType.Float },
        { name = "calibrationTime", type = DatumType.Float },
        { name = "invertUp", type = DatumType.Bool },
        { name = "useGyro", type = DatumType.Bool },
        { name = "gyroThreshold", type = DatumType.Float },
        { name = "enableButtonFallback", type = DatumType.Bool },
    }
end

function MotionShake:Start()
    self.hasGravity = false
    self.calibrationTimer = math.max(0.0, self.calibrationTime)
    self.cooldownTimer = 0.0
    self.armed = false
    self.shakePending = false
    self.intensity = 0.0
    self.shakeCount = 0
    self.calibrated = false
end

function MotionShake:GetIntensity()
    return self.intensity
end

function MotionShake:GetShakeCount()
    return self.shakeCount
end

function MotionShake:ConsumeShake()
    if self.shakePending then
        self.shakePending = false
        return true
    end
    return false
end

function MotionShake:Tick(deltaTime)
    if not self.enabled then
        self.intensity = 0.0
        return
    end

    local dt = math.min(Engine.GetGameDeltaTime(), 0.05)
    if dt <= 0.0 then
        return
    end

    local accel = Input.GetGamepadAcceleration(1)
    local ax = accel.x or 0.0
    local ay = accel.y or 0.0
    local az = accel.z or 0.0

    if not self.hasGravity then
        self.gravityX = ax
        self.gravityY = ay
        self.gravityZ = az
        self.hasGravity = true
    end

    local alpha = 1.0 - math.exp(-self.smoothing * dt)
    self.gravityX = self.gravityX + (ax - self.gravityX) * alpha
    self.gravityY = self.gravityY + (ay - self.gravityY) * alpha
    self.gravityZ = self.gravityZ + (az - self.gravityZ) * alpha

    if self.calibrationTimer > 0.0 then
        self.calibrationTimer = self.calibrationTimer - dt
        self.intensity = 0.0
        return
    end

    if not self.calibrated then
        self.calibrated = true
        Log.Debug("MotionShake: calibrated")
    end

    local lx = ax - self.gravityX
    local ly = ay - self.gravityY
    local lz = az - self.gravityZ

    local gravityLength = math.sqrt(self.gravityX * self.gravityX +
        self.gravityY * self.gravityY + self.gravityZ * self.gravityZ)

    local upImpulse = 0.0
    if gravityLength > EPSILON then
        upImpulse = (lx * self.gravityX + ly * self.gravityY + lz * self.gravityZ) / gravityLength
    end
    if self.invertUp then
        upImpulse = -upImpulse
    end

    local normalized = upImpulse / math.max(self.upThreshold, EPSILON)
    normalized = math.max(0.0, math.min(1.0, normalized))
    self.intensity = self.intensity + (normalized - self.intensity) * math.min(1.0, dt * 12.0)

    if self.cooldownTimer > 0.0 then
        self.cooldownTimer = self.cooldownTimer - dt
    end

    local debugPressed = false
    if self.enableButtonFallback then
        debugPressed = Input.IsGamepadPressed(Gamepad.Y) or Input.IsKeyPressed(Key.G)
    end

    local fire = false
    if debugPressed and self.cooldownTimer <= 0.0 then
        fire = true
        self.cooldownTimer = self.cooldown
        self.armed = false
    elseif self.armed and self.cooldownTimer <= 0.0 and upImpulse >= self.upThreshold then
        fire = true
        self.armed = false
        self.cooldownTimer = self.cooldown
    end

    if fire then
        if self.useGyro then
            local gyro = Input.GetGamepadGyro(1)
            local gx = gyro.x or 0.0
            local gy = gyro.y or 0.0
            local gz = gyro.z or 0.0
            local gyroLength = math.sqrt(gx * gx + gy * gy + gz * gz)
            if gyroLength > self.gyroThreshold and not debugPressed then
                self.intensity = 0.0
                return
            end
        end

        self.shakeCount = self.shakeCount + 1
        self.shakePending = true
        self.intensity = 1.0
        SignalBus.Emit("ShakeDetected", 1.0)
    end

    if not self.armed and self.cooldownTimer <= 0.0 and upImpulse < self.releaseThreshold then
        self.armed = true
    end
end

function MotionShake:Stop()
    self.hasGravity = false
    self.calibrationTimer = 0.0
    self.cooldownTimer = 0.0
    self.armed = false
    self.shakePending = false
    self.intensity = 0.0
end
