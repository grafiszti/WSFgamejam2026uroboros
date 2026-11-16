PlayerVisuals = {}

function PlayerVisuals.Update(ctrl)
    if ctrl.ending then
        return
    end

    if ctrl.currentAnimation == "Boop" and ctrl.stunTimer > 0.0 then
        return
    end

    local animation = "Idle"
    local flipSide = true
    local isMoving = ctrl.moveDir:Magnitude() >= 0.1

    if isMoving then
        if math.abs(ctrl.moveDir.x) > math.abs(ctrl.moveDir.z) then
            animation = "WalkSide"
            flipSide = ctrl.moveDir.x < 0.0
        else
            animation = "WalkFront"
        end
    end

    if ctrl.AnimatedSprite and animation ~= ctrl.currentAnimation then
        ctrl.AnimatedSprite:PlayAnimation(animation)
        ctrl.currentAnimation = animation
    end

    if ctrl.mesh and ctrl.meshBaseRotation and flipSide ~= ctrl.meshFlipped then
        local rotation = ctrl.meshBaseRotation
        ctrl.mesh:SetRotation(Vec(rotation.x, rotation.y + (flipSide and 0.0 or 180.0),
            rotation.z))
        ctrl.meshFlipped = flipSide
    end
end
