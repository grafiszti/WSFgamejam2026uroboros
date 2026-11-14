-- [Script hierarchy]
--   Root (Primitive3D)
--     Camera (Camera3D)
--     Controller (Node, with this script)

ThirdPersonController = {}

ThirdPersonController.kGroundingDot = 0.9

function ThirdPersonController:Create()
    -- Properties
    self.collider = nil
    self.camera = nil
    self.cameraPivot = nil
    self.mesh = nil
    self.cameraDistance = 10.0
    self.moveSpeed = 7.0
    self.followCamHeight = 4.0
    self.enableControl = true
    self.enableFollowCam = false
    self.enableCameraTrace = true
    self.AnimatedSprite = nil

    -- State
    self.moveDir = Vec(0, 0, 0)
    self.vertMoveChange = false
    self.lookVec = Vec()
    self.meshYaw = 0.0
    self.lastNormal = Vec()
    self.tweenID = nil
    self.tweenTarget = Vec()
    self.DirLight = nil
    self.Music = nil
    self.stunTimer = 0.0
    self.subscribedStun = false
end

function ThirdPersonController:GatherProperties()
    return
    {
        { name = "collider",          type = DatumType.Node },
        { name = "camera",            type = DatumType.Node },
        { name = "cameraPivot",       type = DatumType.Node },
        { name = "mesh",              type = DatumType.Node },
        { name = "cameraDistance",    type = DatumType.Float },
        { name = "moveSpeed",         type = DatumType.Float },
        { name = "followCamHeight",   type = DatumType.Float },
        { name = "enableControl",     type = DatumType.Bool },
        { name = "enableFollowCam",   type = DatumType.Bool },
        { name = "enableCameraTrace", type = DatumType.Bool },
        { name = "DirLight",          type = DatumType.Node },
        { name = "Music",             type = DatumType.Asset },
        { name = "AnimatedSprite",    type = DatumType.Node }
    }
end

function ThirdPersonController:Start()
    if self.Music then
        Audio.Play(self.Music, 1.0, 1.0, 0.0, true)
    end

    if (not self.collider) then
        self.collider = self:GetParent()
    end
    self.collider:AddTag("Controller")

    if (not self.camera) then
        self.camera = self.collider:FindChild("Camera", true)
    end

    self.stunTimer = 0.0
    if self.subscribedStun then
        SignalBus.Unsubscribe("PlayerStunned", self)
    end
    SignalBus.Subscribe("PlayerStunned", self, ThirdPersonController.OnPlayerStunned)
    self.subscribedStun = true
end

function ThirdPersonController:OnPlayerStunned(duration)
    self.stunTimer = math.max(self.stunTimer or 0.0, duration or 2.0)
    Log.Debug("ThirdPersonController: stunned")
end

function ThirdPersonController:Stop()
    if self.Music then
        Audio.StopSounds(self.Music)
    end

    if self.subscribedStun then
        SignalBus.Unsubscribe("PlayerStunned", self)
        self.subscribedStun = false
    end
    self.stunTimer = 0.0
end

function ThirdPersonController:Tick(deltaTime)
    self:UpdateInput(deltaTime)
    self:NewMove(deltaTime)
    self:UpdateCamera(deltaTime)
end

function ThirdPersonController:UpdateInput(deltaTime)
    if self.stunTimer > 0.0 then
        self.stunTimer = math.max(0.0, self.stunTimer - deltaTime)
        self.moveDir.x = 0.0
        self.moveDir.y = 0.0
        self.moveDir.z = 0.0
        return
    end

    if (self.enableControl) then
        local oldMoveZ = self.moveDir.z
        -- moveDir
        self.moveDir = Vec()
        if (Input.IsKeyDown(Key.A)) then
            self.moveDir.x = self.moveDir.x + -1.0
        end

        if (Input.IsKeyDown(Key.D)) then
            self.moveDir.x = self.moveDir.x + 1.0
        end

        if (Input.IsKeyDown(Key.W)) then
            self.moveDir.z = self.moveDir.z + -1.0
        end

        if (Input.IsKeyDown(Key.S)) then
            self.moveDir.z = self.moveDir.z + 1.0
        end

        local leftAxisX = Input.GetGamepadAxis(Gamepad.AxisLX)
        local leftAxisY = Input.GetGamepadAxis(Gamepad.AxisLY)

        -- Only add analog stick input beyond a deadzone limit
        if (math.abs(leftAxisX) > 0.1) then
            self.moveDir.x = self.moveDir.x + leftAxisX
        end
        if (math.abs(leftAxisY) > 0.1) then
            self.moveDir.z = self.moveDir.z - leftAxisY
        end

        if (self.moveDir.z ~= 0.0 and (Math.Sign(self.moveDir.z) ~= Math.Sign(oldMoveZ) or oldMoveZ == 0.0)) then
            self.vertMoveChange = true
        else
            self.vertMoveChange = false
        end

        -- Ensure length of moveDir is at most 1.0.
        local moveMag = self.moveDir:Magnitude()
        moveMag = math.min(moveMag, 1.0)
        self.moveDir = self.moveDir:Normalize()
        self.moveDir = self.moveDir * moveMag
    else
        self.moveDir = Vec()
    end
end

function ThirdPersonController:NewMove(deltaTime)
    if (self.vertMoveChange) then
        self.collider:SetRotation(self.tweenTarget)
    end
    local moveVector = (self.collider:GetForwardVector() * -self.moveDir.z + self.collider:GetRightVector() * self.moveDir.x)
    local startPos = self.collider:GetWorldPosition()
    --self.collider:SetWorldPosition(startPos)
    local endPos = startPos + moveVector * self.moveSpeed * deltaTime
    local sweepRes = self.collider:SweepToWorldPosition(endPos)
    startPos = self.collider:GetWorldPosition() + self.collider:GetUpVector() * 0.2
    self.collider:SetWorldPosition(startPos)
    endPos = startPos + -self.collider:GetUpVector() * 5
    sweepRes = self.collider:SweepToWorldPosition(endPos, 2)
    if (sweepRes.hitNode and (sweepRes.hitNormal ~= self.lastNormal)) then
        if (self.tweenID) then
            Tween.Cancel(self.tweenID)
        end
        local angle = Vector.SignedAngle(self.collider:GetUpVector(), sweepRes.hitNormal, self.collider:GetRightVector())
        self.tweenTarget = self.collider:GetRotation() + (angle * Vec(1, 0, 0))
        self.tweenID = Tween.Rotation(self.collider, Easing.InOutQuad,
            self.tweenTarget, 0.12)
    end
    self.DirLight:LookAt(-self.collider:GetUpVector() * 10 + self.collider:GetForwardVector() * 2)
end

function ThirdPersonController:UpdateCamera(deltaTime)
    local kFollowMinDistXZ = 4.0

    if (self.enableFollowCam) then
        -- Ensure proper attachment in case follow cam is toggled
        self.camera:Attach(self.world:GetRootNode())

        local colliderPos = self.collider:GetWorldPosition()

        if (Input.IsKeyPressed(Key.Q) or Input.IsGamepadPressed(Gamepad.L1)) then
            -- Move camera behind player
            self.camera:SetWorldPosition(colliderPos - self.collider:GetForwardVector() * self.cameraDistance)
        end

        local deltaPos = self.camera:GetWorldPosition() - colliderPos
        local deltaPosXZ = Vec(deltaPos.x, 0, deltaPos.z)

        deltaPosXZ.y = 0.0

        local dist = deltaPosXZ:Magnitude()

        if (dist > self.cameraDistance) then
            deltaPosXZ = deltaPosXZ:Normalize() * self.cameraDistance
        elseif (dist < kFollowMinDistXZ) then
            deltaPosXZ = deltaPosXZ:Normalize() * kFollowMinDistXZ
        end

        deltaPos = Vec(deltaPosXZ.x, self.followCamHeight, deltaPosXZ.z)

        local worldPos = colliderPos + deltaPos
        self.camera:SetWorldPosition(worldPos)
        self.camera:LookAt(colliderPos)
    else
        -- Ensure proper attachment in case follow cam is toggled
        self.camera:Attach(self.cameraPivot)
        self.camera:SetRotation(Vec(0, 0, 0))

        -- Adjust camera distance
        self.camera:SetPosition(Vec(0, 0, self.cameraDistance))
    end

    -- Do camera collision tracing
    if (self.enableCameraTrace) then
        local rayStart = self.collider:GetWorldPosition()
        local rayEnd = self.camera:GetWorldPosition()
        local colMask = 0x02 -- Default collision group for environment
        local res = self.world:RayTest(rayStart, rayEnd, colMask)

        if (res.hitNode) then
            -- The trace hit something, so place the camera at the hit location
            local pos = Vector.Lerp(rayStart, rayEnd, res.hitFraction)
            self.camera:SetWorldPosition(pos)
        end
    end
end

function ThirdPersonController:GetCameraYaw()
    return self.enableFollowCam and
        self.camera:GetRotation().y or
        self.cameraPivot:GetRotation().y
end
