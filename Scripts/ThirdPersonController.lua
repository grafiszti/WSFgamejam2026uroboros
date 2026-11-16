-- [Script hierarchy]
--   Root (Primitive3D)
--     Camera (Camera3D)
--     Controller (Node, with this script)

ThirdPersonController = {}

ThirdPersonController.kGroundingDot = 0.9

local kEnvironmentMask = 0x02
local kStoneGroup = 0x08
local kSolidMask = kEnvironmentMask + kStoneGroup
local kGroundProbeDistance = 5.0
local kGroundSnapPadding = 0.002
local kGroundNormalDot = 0.5
local kGroundTweenDot = 0.999
local kGroundRecoveryFrames = 3

local kEndingSignal = "EndingRequested"
local kEndingScene = "SC_Title"
local kEndingAnimation = "Boop"
local kEndingAnimationTimeout = 2.0
local kEndingFreezeHold = 0.25
local kEndingFadeDuration = 1.2
local kEndingHoldDuration = 0.2

local function CreateWhiteOutOverlay(canvas)
    if not canvas then
        return nil
    end

    local overlay = canvas:CreateChild("Quad")
    if not overlay then
        return nil
    end

    local resolution = canvas:GetScreenResolution()
    if resolution == nil or resolution.x <= 0.0 or resolution.y <= 0.0 then
        resolution = Vec(400.0, 240.0, 0.0)
    end

    overlay:SetName("EndingWhiteOut")
    overlay:SetPosition(0.0, 0.0)
    overlay:SetDimensions(resolution.x, resolution.y)
    overlay:SetTexture(nil)
    overlay:SetColor(Vec(1.0, 1.0, 1.0, 1.0))
    overlay:SetOpacityFloat(0.0)
    overlay:SetVisible(true)
    return overlay
end

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
    self.meshBaseRotation = nil
    self.footstepSounds = nil
    self.footstepSounds1 = nil
    self.footstepSounds2 = nil
    self.footstepSounds3 = nil
    self.footstepSounds4 = nil

    -- State
    self.moveDir = Vec(0, 0, 0)
    self.currentAnimation = nil
    self.meshFlipped = false
    self.footstepIndex = 1
    self.footstepTimer = 0.0
    self.currentFootstep = nil
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
    self.subscribedComplete = false
    self.consoleVisible = false
    self.lastValidGroundPos = Vec()
    self.groundMissFrames = 0
    self.groundLost = false
    self.groundHitLogged = false
    self.EndingAnimation = kEndingAnimation
    self.ending = false
    self.endingSprite = nil
    self.endingTopOverlay = nil
    self.endingBottomOverlay = nil
    self.endingAnimTimer = 0.0
    self.endingFreezeTimer = 0.0
    self.endingFadeStarted = false
    self.endingFadeTimer = 0.0
    self.endingHoldTimer = 0.0
    self.endingRedirected = false
    self.subscribedEnding = false
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
        { name = "EndingAnimation",   type = DatumType.String },
        { name = "DirLight",          type = DatumType.Node },
        { name = "Music",             type = DatumType.Asset },
        { name = "AnimatedSprite",    type = DatumType.Node },
        { name = "footstepSounds1",   type = DatumType.Asset },
        { name = "footstepSounds2",   type = DatumType.Asset },
        { name = "footstepSounds3",   type = DatumType.Asset },
        { name = "footstepSounds4",   type = DatumType.Asset },
    }
end

function ThirdPersonController:Start()
    if self.Music then
        Audio.Play(self.Music, 1.0, 1.0, 0.0, true)
    end

    self.footstepSounds = {
        self.footstepSounds1,
        self.footstepSounds2,
        self.footstepSounds3,
        self.footstepSounds4
    }

    if (not self.collider) then
        self.collider = self:GetParent()
    end
    self.collider:AddTag("Controller")

    if (not self.camera) then
        self.camera = self.collider:FindChild("Camera", true)
    end

    if self.mesh then
        self.meshBaseRotation = self.mesh:GetRotation()
        if self.mesh ~= self.collider then
            if self.mesh.EnableCollision then
                self.mesh:EnableCollision(false)
            end
            if self.mesh.EnableOverlaps then
                self.mesh:EnableOverlaps(false)
            end
        end
    end

    self.stunTimer = 0.0
    self.lastNormal = self.collider:GetUpVector():Normalize()
    self.lastValidGroundPos = self.collider:GetWorldPosition()
    self.groundMissFrames = 0
    self.groundLost = false
    self.groundHitLogged = false

    if self.EndingAnimation == nil or self.EndingAnimation == "" then
        self.EndingAnimation = kEndingAnimation
    end
    self.ending = false
    self.endingSprite = nil
    self.endingTopOverlay = nil
    self.endingBottomOverlay = nil
    self.endingAnimTimer = 0.0
    self.endingFreezeTimer = 0.0
    self.endingFadeStarted = false
    self.endingFadeTimer = 0.0
    self.endingHoldTimer = 0.0
    self.endingRedirected = false

    if self.subscribedStun then
        SignalBus.Unsubscribe("PlayerStunned", self)
    end
    SignalBus.Subscribe("PlayerStunned", self, ThirdPersonController.OnPlayerStunned)
    self.subscribedStun = true

    if self.subscribedComplete then
        SignalBus.Unsubscribe("GameCompleted", self)
    end
    SignalBus.Subscribe("GameCompleted", self, ThirdPersonController.OnGameCompleted)
    self.subscribedComplete = true

    if self.subscribedEnding then
        SignalBus.Unsubscribe(kEndingSignal, self)
    end
    SignalBus.Subscribe(kEndingSignal, self, ThirdPersonController.OnEndingRequested)
    self.subscribedEnding = true

    self.consoleVisible = false
    Renderer.EnableConsole(false)
    self:DisableOverlapChecks()
end

function ThirdPersonController:DisableOverlapChecks()
    local function disableOverlaps(node)
        if node:IsA("Primitive3D") then
            node:EnableOverlaps(false)
        end
        for i = 1, node:GetNumChildren() do
            disableOverlaps(node:GetChild(i))
        end
    end

    if self.collider then
        self.collider:EnableOverlaps(false)
    end

    local world = self:GetWorld()
    local root = world and world:GetRootNode()
    if root then
        disableOverlaps(root)
    end
end

function ThirdPersonController:OnPlayerStunned(duration)
    self.stunTimer = math.max(self.stunTimer or 0.0, duration or 2.0)
    Log.Debug("ThirdPersonController: stunned")
end

function ThirdPersonController:OnGameCompleted()
    self.enableControl = false
    self.moveDir = Vec(0, 0, 0)
    if self.Music then
        Audio.StopSounds(self.Music)
    end
    Log.Debug("ThirdPersonController: game complete")
end

function ThirdPersonController:OnEndingRequested()
    if self.ending then
        return
    end

    self.ending = true
    self.enableControl = false
    self.moveDir.x = 0.0
    self.moveDir.y = 0.0
    self.moveDir.z = 0.0
    self.stunTimer = 0.0
    self.endingAnimTimer = 0.0
    self.endingFreezeTimer = 0.0
    self:StopFootsteps()

    if self.tweenID then
        Tween.Cancel(self.tweenID)
        self.tweenID = nil
    end

    if self.Music then
        Audio.StopSounds(self.Music)
    end

    local world = self:GetWorld()
    if not world then
        return
    end

    self.endingSprite = self.AnimatedSprite
    if not self.endingSprite then
        self.endingSprite = world:FindNode("AnimatedSprite3D")
    end
    if self.endingSprite then
        self.endingSprite:PlayAnimation(self.EndingAnimation)
    end

    self.endingTopOverlay = CreateWhiteOutOverlay(world:FindNode("Canvas_UI"))
    self.endingBottomOverlay = CreateWhiteOutOverlay(world:FindNode("BottomScreenCanvas"))
    Log.Debug("ThirdPersonController: ending started")
end

function ThirdPersonController:SetEndingOverlayOpacity(opacity)
    if self.endingTopOverlay then
        self.endingTopOverlay:SetOpacityFloat(opacity)
    end
    if self.endingBottomOverlay then
        self.endingBottomOverlay:SetOpacityFloat(opacity)
    end
end

function ThirdPersonController:UpdateEnding(deltaTime)
    local dt = math.min(Engine.GetRealDeltaTime(), 0.1)
    if dt <= 0.0 then
        dt = math.min(deltaTime, 0.1)
    end
    if dt <= 0.0 then
        return
    end

    self.endingAnimTimer = self.endingAnimTimer + dt

    if not self.endingFadeStarted then
        local waiting = false
        if self.endingSprite and self.endingSprite.IsPlaying then
            local animName = nil
            if self.endingSprite.GetCurrentAnimationName then
                animName = self.endingSprite:GetCurrentAnimationName()
            end
            waiting = (animName == self.EndingAnimation) and self.endingSprite:IsPlaying()
        end

        if waiting and self.endingAnimTimer < kEndingAnimationTimeout then
            return
        end

        self.endingFreezeTimer = self.endingFreezeTimer + dt
        if self.endingFreezeTimer < kEndingFreezeHold then
            return
        end

        self.endingFadeStarted = true
        self.endingFadeTimer = 0.0
        self:SetEndingOverlayOpacity(0.0)
    end

    self.endingFadeTimer = self.endingFadeTimer + dt
    local t = math.min(1.0, self.endingFadeTimer / kEndingFadeDuration)
    self:SetEndingOverlayOpacity(t)

    if t >= 1.0 then
        self.endingHoldTimer = self.endingHoldTimer + dt
        if self.endingHoldTimer >= kEndingHoldDuration and not self.endingRedirected then
            self.endingRedirected = true
            local world = self:GetWorld()
            if world then
                world:LoadScene(kEndingScene, false)
            end
        end
    end
end

function ThirdPersonController:Stop()
    if self.Music then
        Audio.StopSounds(self.Music)
    end
    self:StopFootsteps()

    if self.subscribedStun then
        SignalBus.Unsubscribe("PlayerStunned", self)
        self.subscribedStun = false
    end
    if self.subscribedComplete then
        SignalBus.Unsubscribe("GameCompleted", self)
        self.subscribedComplete = false
    end
    if self.subscribedEnding then
        SignalBus.Unsubscribe(kEndingSignal, self)
        self.subscribedEnding = false
    end
    self.stunTimer = 0.0

    if self.tweenID then
        Tween.Cancel(self.tweenID)
        self.tweenID = nil
    end
    self.groundMissFrames = 0
    self.groundLost = false
    self.ending = false
    self.endingSprite = nil
    self.endingTopOverlay = nil
    self.endingBottomOverlay = nil
    self.endingRedirected = false

    Renderer.EnableConsole(false)
    self.consoleVisible = false
end

function ThirdPersonController:Tick(deltaTime)
    if self.ending then
        self:UpdateEnding(deltaTime)
        return
    end

    self:UpdateDebugConsoleToggle()

    if self.stunTimer <= 0.0 and
        (Input.IsKeyPressed(Key.E) or Input.IsGamepadPressed(Gamepad.A)) then
        self:OnPlayerStunned(0.8)
        if self.AnimatedSprite then
            self.AnimatedSprite:PlayAnimation("Boop")
            self.currentAnimation = "Boop"
        end
    end

    self:UpdateInput(deltaTime)
    self:UpdateAnimation()
    self:UpdateFootsteps(deltaTime)
    self:NewMove(deltaTime)
    self:UpdateCamera(deltaTime)
end

function ThirdPersonController:UpdateDebugConsoleToggle()
    if Input.IsGamepadPressed(Gamepad.L2) or Input.IsKeyPressed(Key.F1) then
        self.consoleVisible = not self.consoleVisible
        Renderer.EnableConsole(self.consoleVisible)
    end
end

function ThirdPersonController:UpdateFootsteps(deltaTime)
    local isWalking = self.currentAnimation == "WalkFront" or self.currentAnimation == "WalkSide"
    if not isWalking then
        self:StopFootsteps()
        return
    end

    self.footstepTimer = self.footstepTimer - deltaTime
    if self.footstepTimer <= 0.0 then
        if self.currentFootstep then
            Audio.StopSounds(self.currentFootstep)
        end

        self.currentFootstep = self.footstepSounds[self.footstepIndex]
        Audio.Play(self.currentFootstep)
        self.footstepIndex = self.footstepIndex % #self.footstepSounds + 1
        self.footstepTimer = 0.4
    end
end

function ThirdPersonController:StopFootsteps()
    if self.currentFootstep then
        Audio.StopSounds(self.currentFootstep)
        self.currentFootstep = nil
    end
    --self.footstepIndex = 1
    self.footstepTimer = 0.0
end

function ThirdPersonController:UpdateAnimation()
    if self.ending then
        return
    end

    if self.currentAnimation == "Boop" and self.stunTimer > 0.0 then
        return
    end

    local animation = "Idle"
    local flipSide = true
    local isMoving = self.moveDir:Magnitude() >= 0.1

    if isMoving then
        if math.abs(self.moveDir.x) > math.abs(self.moveDir.z) then
            animation = "WalkSide"
            flipSide = self.moveDir.x < 0.0
        else
            animation = "WalkFront"
        end
    end

    if self.AnimatedSprite and animation ~= self.currentAnimation then
        self.AnimatedSprite:PlayAnimation(animation)
        self.currentAnimation = animation
    end

    if self.mesh and self.meshBaseRotation and flipSide ~= self.meshFlipped then
        local rotation = self.meshBaseRotation
        self.mesh:SetRotation(Vec(rotation.x, rotation.y + (flipSide and 0.0 or 180.0), rotation.z))
        self.meshFlipped = flipSide
    end
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
    local dt = math.min(deltaTime, 0.05)

    if (self.vertMoveChange) then
        self.collider:SetRotation(self.tweenTarget)
    end

    local moveVector = (self.collider:GetForwardVector() * -self.moveDir.z + self.collider:GetRightVector() * self.moveDir.x)

    if self.lastNormal:Magnitude() > 0.5 then
        moveVector = moveVector - self.lastNormal * Vector.Dot(moveVector, self.lastNormal)
    end

    local deltaVec = moveVector * self.moveSpeed * dt
    for i = 1, 3 do
        if deltaVec:Magnitude() < 0.0001 then
            break
        end

        local startPos = self.collider:GetWorldPosition()
        local sweepRes = self.collider:SweepToWorldPosition(startPos + deltaVec)
        if not sweepRes.hitNode then
            break
        end

        deltaVec = deltaVec * (1.0 - sweepRes.hitFraction)
        local into = Vector.Dot(deltaVec, sweepRes.hitNormal)
        if into < 0.0 then
            deltaVec = deltaVec - sweepRes.hitNormal * into
        end
    end

    local up = self.collider:GetUpVector()
    local startPos = self.collider:GetWorldPosition() + up * 0.2
    local endPos = startPos + -up * kGroundProbeDistance
    local sweepRes = self.collider:SweepToWorldPosition(endPos, kEnvironmentMask, true)

    local grounded = false
    local hitNormal = sweepRes.hitNormal
    local normalLength = hitNormal and hitNormal:Magnitude() or 0.0
    if sweepRes.hitNode and normalLength > 0.0001 then
        hitNormal = hitNormal / normalLength
        if Vector.Dot(hitNormal, up) > kGroundNormalDot then
            grounded = true
            local snapPos = startPos + (endPos - startPos) * sweepRes.hitFraction + hitNormal * kGroundSnapPadding
            self.collider:SetWorldPosition(snapPos)
            self.lastValidGroundPos = snapPos
            self.groundMissFrames = 0
            self.groundLost = false

            if not self.groundHitLogged then
                self.groundHitLogged = true
                Log.Debug("ThirdPersonController: ground hit " .. sweepRes.hitNode:GetName())
            end

            if Vector.Dot(hitNormal, self.lastNormal) < kGroundTweenDot then
                if (self.tweenID) then
                    Tween.Cancel(self.tweenID)
                end
                local angle = Vector.SignedAngle(self.collider:GetUpVector(), hitNormal, self.collider:GetRightVector())
                self.tweenTarget = self.collider:GetRotation() + (angle * Vec(1, 0, 0))
                self.tweenID = Tween.Rotation(self.collider, Easing.InOutQuad,
                    self.tweenTarget, 0.12)
            end
            self.lastNormal = hitNormal
        end
    end

    if not grounded then
        self.groundMissFrames = self.groundMissFrames + 1
        if self.groundMissFrames == 1 then
            Log.Warning("ThirdPersonController: ground probe missed; holding last valid ground position")
        end

        if self.groundMissFrames >= kGroundRecoveryFrames then
            self.collider:SetWorldPosition(self.lastValidGroundPos)
            if not self.groundLost then
                self.groundLost = true
                Log.Warning("ThirdPersonController: restoring player to last valid ground position")
            end
        end
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
        local res = self.world:RayTest(rayStart, rayEnd, kSolidMask)

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
