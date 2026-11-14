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

    if self.animationRun == nil then
        self.animationRun = "Run"
    end
    if self.animationIdle == nil then
        self.animationIdle = "Idle"
    end
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
        { name = "animationRun",      type = DatumType.String },
        { name = "animationIdle",     type = DatumType.String },
        { name = "DirLight",          type = DatumType.Node },
        { name = "Music",             type = DatumType.Asset }
    }
end

function ThirdPersonController:Start()
    --Input.LockCursor(true)
    --Input.TrapCursor(true)
    --Input.ShowCursor(false)
    Audio.Play(self.Music, 1.0, 1.0, 0.0, true)

    if (not self.collider) then
        self.collider = self:GetParent()
    end
    self.collider:AddTag("Controller")

    if (not self.camera) then
        self.camera = self.collider:FindChild("Camera", true)
    end
end

function ThirdPersonController:Stop()
    Audio.StopSounds(self.Music)
end

function ThirdPersonController:Tick(deltaTime)
    self:UpdateInput(deltaTime)
    self:NewMove(deltaTime)
    self:UpdateCamera(deltaTime)
    self:UpdateMesh(deltaTime)
end

function ThirdPersonController:UpdateInput(deltaTime)
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

        if (Math.Sign(self.moveDir.z) ~= Math.Sign(oldMoveZ)) then
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
            self.camera:SetWorldPosition(colliderPos - self.mesh:GetForwardVector() * self.cameraDistance)
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

        --[[ local lookRot = self.lookVec * self.lookSpeed

        -- Adjust rotation of camera pivot based on player input
        local camPivotRot = self.cameraPivot:GetRotation()
        camPivotRot.y = camPivotRot.y - lookRot.x * deltaTime
        camPivotRot.x = camPivotRot.x - lookRot.y * deltaTime
        camPivotRot.x = Math.Clamp(camPivotRot.x, -89.9, 89.9)
        self.cameraPivot:SetRotation(camPivotRot) ]]

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

function ThirdPersonController:UpdateMesh(deltaTime)
    -- Update orientation of the mesh if the player is moving
    if (math.abs(self.moveDir.x) >= 0.01 or
            math.abs(self.moveDir.z) >= 0.01) then
        local camYaw = self:GetCameraYaw()
        local moveDir = Vector.Rotate(self.moveDir, camYaw, Vec(0, 1, 0))

        local targetYaw = math.atan(-moveDir.x, -moveDir.z)
        targetYaw = math.deg(targetYaw)

        self.meshYaw = Math.ApproachAngle(self.meshYaw, targetYaw, 1000.0, deltaTime)
        self.mesh:SetRotation(Vec(0, self.meshYaw, 0))
    end

    -- Update looping animation
    --[[ if (not self.grounded and self.timeSinceGrounded > 0.1) then
        -- Don't play fall animation if jump animation is playing.
        -- Wait until it finishes so that we get a seamless transition between
        -- the end of the jump animation and the beginning of the fall animation.
        if (not self.mesh:IsAnimationPlaying(self.animationJump)) then
            self.mesh:PlayAnimation(self.animationFall, 0, true, 1, 1)
        end
    elseif (self.moveVelocity:Length2() > 1.0) then
        self.mesh:PlayAnimation(self.animationRun, 0, true, 1.5, 1)
    else
        self.mesh:PlayAnimation(self.animationIdle, 0, true, 1, 1)
    end ]]
end

function ThirdPersonController:GetCameraYaw()
    return self.enableFollowCam and
        self.camera:GetRotation().y or
        self.cameraPivot:GetRotation().y
end
