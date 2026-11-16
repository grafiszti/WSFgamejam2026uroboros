Script.Load("Core/CollisionLayers")
Script.Load("Core/SurfaceMath")

EnemyMotor = {}

function EnemyMotor.SnapToSurface(enemy)
    local up = SurfaceMath.SafeNormalize(enemy:GetUpVector(), Vec(0.0, 1.0, 0.0))
    local startPos = enemy:GetWorldPosition() + up * 0.5
    local endPos = startPos - up * enemy.snapDistance
    local result = enemy:SweepToWorldPosition(endPos, CollisionLayers.Environment)

    if not result.hitNode then
        Log.Warning("Enemy: could not find roller surface at spawn")
        enemy:SetWorldPosition(startPos)
        return
    end

    local normal = SurfaceMath.SafeNormalize(result.hitNormal, up)
    local hitCenter = Vector.Lerp(startPos, endPos, result.hitFraction)
    hitCenter = hitCenter + normal * 0.002
    enemy:SetWorldPosition(hitCenter)

    local forward = enemy:GetForwardVector()
    if enemy.player then
        forward = SurfaceMath.ProjectOnPlane(enemy.player:GetWorldPosition() - hitCenter, normal)
    end

    forward = SurfaceMath.ProjectOnPlane(forward, normal)
    if forward:Magnitude() < 0.001 then
        forward = enemy:GetForwardVector()
    end
    forward = SurfaceMath.SafeNormalize(forward, enemy:GetForwardVector())

    enemy:LookAt(hitCenter + forward, normal)
    enemy.lastNormal = normal
    enemy.lastGroundPos = hitCenter
end

function EnemyMotor.ProbeSurface(enemy, center, up)
    if not enemy.world then
        return nil
    end

    local startPos = center + up * enemy.snapDistance
    local endPos = center - up * enemy.snapDistance
    local result = enemy.world:SweepTest(enemy, startPos, endPos, CollisionLayers.Environment)
    if not result or not result.hitNode or result.hitFraction >= 1.0 then
        return nil
    end

    local node = result.hitNode
    while node ~= nil and node ~= enemy do
        node = node:GetParent()
    end
    if node == enemy then
        return nil
    end

    local hitCenter = Vector.Lerp(startPos, endPos, result.hitFraction)
    local normal = SurfaceMath.SafeNormalize(result.hitNormal, up)
    hitCenter = hitCenter + normal * 0.002
    return hitCenter, normal
end

function EnemyMotor.MoveOnSurface(enemy, forward, speed, dt)
    local startPos = enemy:GetWorldPosition()
    local up = SurfaceMath.SafeNormalize(enemy:GetUpVector(), Vec(0.0, 1.0, 0.0))
    local targetPos = startPos + forward * speed * dt
    local hitCenter, hitNormal = EnemyMotor.ProbeSurface(enemy, targetPos, up)
    if not hitCenter then
        return false
    end

    enemy:SetWorldPosition(hitCenter)

    local newForward = SurfaceMath.ProjectOnPlane(forward, hitNormal)
    if newForward:Magnitude() > 0.001 then
        forward = SurfaceMath.SafeNormalize(newForward, forward)
    end

    enemy.lastNormal = hitNormal
    enemy.lastGroundPos = hitCenter
    enemy.surfaceLostWarned = false
    enemy:LookAt(enemy:GetWorldPosition() + forward, hitNormal)
    return true
end

function EnemyMotor.RestoreSurface(enemy)
    local up = SurfaceMath.SafeNormalize(enemy:GetUpVector(), Vec(0.0, 1.0, 0.0))
    local hitCenter, hitNormal = EnemyMotor.ProbeSurface(enemy, enemy:GetWorldPosition(), up)
    if hitCenter then
        enemy:SetWorldPosition(hitCenter)
        enemy.lastNormal = hitNormal
        enemy.lastGroundPos = hitCenter
        return
    end

    if enemy.lastGroundPos then
        enemy:SetWorldPosition(enemy.lastGroundPos)
    end

    if not enemy.surfaceLostWarned then
        enemy.surfaceLostWarned = true
        Log.Warning("Enemy: lost roller surface")
    end
end
