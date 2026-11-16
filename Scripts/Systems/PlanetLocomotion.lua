Script.Load("Core/CollisionLayers")
Script.Load("Core/SurfaceMath")

PlanetLocomotion = {}

local kGroundProbeDistance = 5.0
local kGroundSnapPadding = 0.002
local kGroundNormalDot = 0.5
local kGroundTweenDot = 0.999
local kGroundRecoveryFrames = 3

function PlanetLocomotion.UpdateInput(ctrl, deltaTime)
    if ctrl.stunTimer > 0.0 then
        ctrl.stunTimer = math.max(0.0, ctrl.stunTimer - deltaTime)
        ctrl.moveDir.x = 0.0
        ctrl.moveDir.y = 0.0
        ctrl.moveDir.z = 0.0
        return
    end

    if not ctrl.enableControl then
        ctrl.moveDir.x = 0.0
        ctrl.moveDir.y = 0.0
        ctrl.moveDir.z = 0.0
        return
    end

    local oldMoveZ = ctrl.moveDir.z
    ctrl.moveDir = Vec()

    if Input.IsKeyDown(Key.A) then
        ctrl.moveDir.x = ctrl.moveDir.x - 1.0
    end
    if Input.IsKeyDown(Key.D) then
        ctrl.moveDir.x = ctrl.moveDir.x + 1.0
    end
    if Input.IsKeyDown(Key.W) then
        ctrl.moveDir.z = ctrl.moveDir.z - 1.0
    end
    if Input.IsKeyDown(Key.S) then
        ctrl.moveDir.z = ctrl.moveDir.z + 1.0
    end

    local leftAxisX = Input.GetGamepadAxis(Gamepad.AxisLX)
    local leftAxisY = Input.GetGamepadAxis(Gamepad.AxisLY)

    if math.abs(leftAxisX) > 0.1 then
        ctrl.moveDir.x = ctrl.moveDir.x + leftAxisX
    end
    if math.abs(leftAxisY) > 0.1 then
        ctrl.moveDir.z = ctrl.moveDir.z - leftAxisY
    end

    ctrl.vertMoveChange = ctrl.moveDir.z ~= 0.0 and
        (Math.Sign(ctrl.moveDir.z) ~= Math.Sign(oldMoveZ) or oldMoveZ == 0.0)

    local moveMag = math.min(ctrl.moveDir:Magnitude(), 1.0)
    ctrl.moveDir = ctrl.moveDir:Normalize() * moveMag
end

function PlanetLocomotion.Move(ctrl, deltaTime)
    if ctrl.collider == nil then
        return
    end

    local dt = math.min(deltaTime, 0.05)

    if ctrl.vertMoveChange then
        ctrl.collider:SetRotation(ctrl.tweenTarget)
    end

    local moveVector = (ctrl.collider:GetForwardVector() * -ctrl.moveDir.z +
        ctrl.collider:GetRightVector() * ctrl.moveDir.x)

    if ctrl.lastNormal:Magnitude() > 0.5 then
        moveVector = moveVector - ctrl.lastNormal * Vector.Dot(moveVector, ctrl.lastNormal)
    end

    local deltaVec = moveVector * ctrl.moveSpeed * dt
    for i = 1, 3 do
        if deltaVec:Magnitude() < 0.0001 then
            break
        end

        local startPos = ctrl.collider:GetWorldPosition()
        local sweepRes = ctrl.collider:SweepToWorldPosition(startPos + deltaVec)
        if not sweepRes.hitNode then
            break
        end

        deltaVec = deltaVec * (1.0 - sweepRes.hitFraction)
        local into = Vector.Dot(deltaVec, sweepRes.hitNormal)
        if into < 0.0 then
            deltaVec = deltaVec - sweepRes.hitNormal * into
        end
    end

    local up = ctrl.collider:GetUpVector()
    local startPos = ctrl.collider:GetWorldPosition() + up * 0.2
    local endPos = startPos - up * kGroundProbeDistance
    local sweepRes = ctrl.collider:SweepToWorldPosition(endPos, CollisionLayers.Environment, true)

    local grounded = false
    local hitNormal = SurfaceMath.SafeNormalize(sweepRes.hitNormal, nil)
    if sweepRes.hitNode and hitNormal ~= nil and
        Vector.Dot(hitNormal, up) > kGroundNormalDot then
        grounded = true
        local snapPos = startPos + (endPos - startPos) * sweepRes.hitFraction +
            hitNormal * kGroundSnapPadding
        ctrl.collider:SetWorldPosition(snapPos)
        ctrl.lastValidGroundPos = snapPos
        ctrl.groundMissFrames = 0
        ctrl.groundLost = false

        if not ctrl.groundHitLogged then
            ctrl.groundHitLogged = true
            Log.Debug("ThirdPersonController: ground hit " .. sweepRes.hitNode:GetName())
        end

        if Vector.Dot(hitNormal, ctrl.lastNormal) < kGroundTweenDot then
            if ctrl.tweenID then
                Tween.Cancel(ctrl.tweenID)
            end
            local angle = Vector.SignedAngle(ctrl.collider:GetUpVector(), hitNormal,
                ctrl.collider:GetRightVector())
            ctrl.tweenTarget = ctrl.collider:GetRotation() + (angle * Vec(1, 0, 0))
            ctrl.tweenID = Tween.Rotation(ctrl.collider, Easing.InOutQuad, ctrl.tweenTarget, 0.12)
        end
        ctrl.lastNormal = hitNormal
    end

    if not grounded then
        ctrl.groundMissFrames = ctrl.groundMissFrames + 1
        if ctrl.groundMissFrames == 1 then
            Log.Warning("ThirdPersonController: ground probe missed; holding last valid ground position")
        end

        if ctrl.groundMissFrames >= kGroundRecoveryFrames then
            ctrl.collider:SetWorldPosition(ctrl.lastValidGroundPos)
            if not ctrl.groundLost then
                ctrl.groundLost = true
                Log.Warning("ThirdPersonController: restoring player to last valid ground position")
            end
        end
    end
end

function PlanetLocomotion.AimSun(ctrl)
    if ctrl.DirLight == nil or ctrl.collider == nil then
        return
    end

    ctrl.DirLight:LookAt(-ctrl.collider:GetUpVector() * 10.0 +
        ctrl.collider:GetForwardVector() * 2.0)
end
