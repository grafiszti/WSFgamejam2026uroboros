Script.Load("Core/CollisionLayers")
Script.Load("Core/GameActions")

ThirdPersonCamera = {}

local kFollowMinDistXZ = 4.0
local kTracePadding = 0.03

function ThirdPersonCamera.Update(ctrl)
    if ctrl.camera == nil or ctrl.collider == nil then
        return
    end

    local world = ctrl:GetWorld()
    if ctrl.enableFollowCam then
        if world and ctrl.camera then
            ctrl.camera:Attach(world:GetRootNode())
        end

        local colliderPos = ctrl.collider:GetWorldPosition()

        if GameActions.RecenterCameraPressed() then
            ctrl.camera:SetWorldPosition(colliderPos -
                ctrl.collider:GetForwardVector() * ctrl.cameraDistance)
        end

        local deltaPos = ctrl.camera:GetWorldPosition() - colliderPos
        local deltaPosXZ = Vec(deltaPos.x, 0.0, deltaPos.z)
        local dist = deltaPosXZ:Magnitude()

        if dist > 0.0001 then
            if dist > ctrl.cameraDistance then
                deltaPosXZ = deltaPosXZ:Normalize() * ctrl.cameraDistance
            elseif dist < kFollowMinDistXZ then
                deltaPosXZ = deltaPosXZ:Normalize() * kFollowMinDistXZ
            end
        end

        local worldPos = colliderPos + Vec(deltaPosXZ.x, ctrl.followCamHeight, deltaPosXZ.z)
        ctrl.camera:SetWorldPosition(worldPos)
        ctrl.camera:LookAt(colliderPos)
    else
        if ctrl.cameraPivot then
            ctrl.camera:Attach(ctrl.cameraPivot)
        end
        ctrl.camera:SetRotation(Vec(0.0, 0.0, 0.0))
        ctrl.camera:SetPosition(Vec(0.0, 0.0, ctrl.cameraDistance))
    end

    if ctrl.enableCameraTrace and world then
        local rayStart = ctrl.collider:GetWorldPosition()
        local rayEnd = ctrl.camera:GetWorldPosition()
        local res = world:RayTest(rayStart, rayEnd, CollisionLayers.Solid)

        if res.hitNode then
            local fraction = math.max(0.0, res.hitFraction - kTracePadding)
            ctrl.camera:SetWorldPosition(Vector.Lerp(rayStart, rayEnd, fraction))
        end
    end
end

function ThirdPersonCamera.GetYaw(ctrl)
    if ctrl.enableFollowCam and ctrl.camera then
        return ctrl.camera:GetRotation().y
    elseif ctrl.cameraPivot then
        return ctrl.cameraPivot:GetRotation().y
    end
    return 0.0
end
