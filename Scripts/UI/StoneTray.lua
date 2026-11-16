
StoneTray = {}

local STONE_SIZE = 30.0
local STONE_RADIUS = STONE_SIZE * 0.5
local DRAWER_PADDING = 4.0
local STONE_FALL_DURATION = 0.55
local STONE_FALL_START_SCALE = 2.6
local COLOR_STONE = Vec(0.56, 0.52, 0.46, 1.0)

function StoneTray.Init(ui)
    local drawerPosition = ui.drawer:GetPosition()
    local drawerSize = ui.drawer:GetDimensions()
    ui.drawerX = drawerPosition.x
    ui.drawerY = drawerPosition.y
    ui.drawerWidth = drawerSize.x
    ui.drawerHeight = drawerSize.y

    ui.stoneSize = STONE_SIZE
    ui.stoneRadius = STONE_RADIUS

    ui.drawerMinX = ui.drawerX + DRAWER_PADDING + STONE_RADIUS
    ui.drawerMaxX = ui.drawerX + ui.drawerWidth - DRAWER_PADDING - STONE_RADIUS
    ui.drawerMinY = ui.drawerY + DRAWER_PADDING + STONE_RADIUS
    ui.drawerMaxY = ui.drawerY + ui.drawerHeight - DRAWER_PADDING - STONE_RADIUS

    ui.stones = {}
    for i = 1, 32 do
        local stoneNode = ui.canvas:FindChild("Stone_" .. tostring(i))
        if stoneNode then
            local stonePosition = stoneNode:GetPosition()
            stoneNode:SetDimensions(STONE_SIZE, STONE_SIZE)
            stoneNode:SetVisible(false)
            ui.stones[#ui.stones + 1] =
            {
                node = stoneNode,
                homeX = stonePosition.x,
                homeY = stonePosition.y,
                x = stonePosition.x + STONE_RADIUS,
                y = stonePosition.y + STONE_RADIUS,
                vx = 0.0,
                vy = 0.0,
                renderX = stonePosition.x,
                renderY = stonePosition.y,
                available = false,
                placed = false,
                falling = false,
                fallTime = 0.0,
                fallDuration = STONE_FALL_DURATION,
                spawnX = 0.0,
                spawnY = 0.0,
                targetX = 0.0,
                targetY = 0.0,
                runeArt = "",
            }
        end
    end

    if #ui.stones == 0 then
        Log.Warning("BottomScreenUI: no Stone_1..Stone_32 widgets found")
    end
end

function StoneTray.GetLandingY(ui, stone)
    local targetY = stone.homeY + STONE_RADIUS
    if targetY < ui.drawerMinY then
        targetY = ui.drawerMinY
    elseif targetY > ui.drawerMaxY then
        targetY = ui.drawerMaxY
    end
    return targetY
end

function StoneTray.SpawnNext(ui, runeArt)
    local texture = ui:GetRuneTexture(runeArt)

    for i = 1, #ui.stones do
        local stone = ui.stones[i]
        if not stone.placed and not stone.available and stone ~= ui.dragStone then
            local startSize = STONE_SIZE * ui.stoneFallStartScale
            local startHalf = startSize * 0.5

            stone.available = true
            stone.falling = true
            stone.fallTime = 0.0
            stone.fallDuration = ui.stoneFallDuration
            stone.spawnX = ui.drawerX + ui.drawerWidth * 0.5
            stone.spawnY = ui.drawerY + ui.drawerHeight + startHalf
            stone.targetX = math.max(ui.drawerMinX,
                math.min(ui.drawerMaxX, stone.homeX + STONE_RADIUS))
            stone.targetY = StoneTray.GetLandingY(ui, stone)
            stone.x = stone.spawnX
            stone.y = stone.spawnY
            stone.vx = 0.0
            stone.vy = 0.0
            stone.renderX = stone.x - startHalf
            stone.renderY = stone.y - startHalf
            stone.runeArt = runeArt or ""
            stone.node:SetDimensions(startSize, startSize)
            stone.node:SetPosition(stone.renderX, stone.renderY)
            if texture then
                stone.node:SetTexture(texture)
                stone.node:SetColor(Vec(1.0, 1.0, 1.0, 1.0))
            else
                stone.node:SetTexture(nil)
                stone.node:SetColor(COLOR_STONE)
            end
            stone.node:SetVisible(true)
            Log.Debug("BottomScreenUI: stone revealed")
            return
        end
    end

    if not ui.trayFullWarned then
        ui.trayFullWarned = true
        Log.Debug("BottomScreenUI: stone tray is full")
    end
end

function StoneTray.Discard(ui, stone)
    if not stone or not stone.available or stone.placed or stone.falling then
        return
    end

    stone.available = false
    stone.placed = false
    stone.falling = false
    stone.vx = 0.0
    stone.vy = 0.0
    stone.runeArt = ""
    stone.node:SetTexture(nil)
    stone.node:SetColor(COLOR_STONE)
    stone.node:SetDimensions(STONE_SIZE, STONE_SIZE)
    stone.node:SetVisible(false)

    ui.trayFullWarned = false
    Log.Debug("BottomScreenUI: rune discarded")
end

function StoneTray.FindStoneAt(ui, x, y)
    for i = 1, #ui.stones do
        local stone = ui.stones[i]
        if stone.available and not stone.placed and not stone.falling then
            local dx = x - (ui.canvasX + stone.x)
            local dy = y - (ui.canvasY + stone.y)
            if dx * dx + dy * dy <= STONE_RADIUS * STONE_RADIUS then
                return stone
            end
        end
    end
    return nil
end

function StoneTray.Clamp(ui, stone, bounce)
    local restitution = 0.0
    if bounce then
        restitution = ui.drawerRestitution
    end

    if stone.x < ui.drawerMinX then
        stone.x = ui.drawerMinX
        stone.vx = -stone.vx * restitution
    elseif stone.x > ui.drawerMaxX then
        stone.x = ui.drawerMaxX
        stone.vx = -stone.vx * restitution
    end

    if stone.y < ui.drawerMinY then
        stone.y = ui.drawerMinY
        stone.vy = -stone.vy * restitution
    elseif stone.y > ui.drawerMaxY then
        stone.y = ui.drawerMaxY
        stone.vy = -stone.vy * restitution
    end
end

function StoneTray.ApplyNodePosition(ui, stone)
    local posX = stone.x - STONE_RADIUS
    local posY = stone.y - STONE_RADIUS
    if math.abs(posX - stone.renderX) > 0.5 or math.abs(posY - stone.renderY) > 0.5 then
        stone.renderX = posX
        stone.renderY = posY
        stone.node:SetPosition(posX, posY)
    end
end

function StoneTray.ResolveCollisions(ui)
    local minDist = STONE_SIZE
    local minDistSq = minDist * minDist

    for i = 1, #ui.stones - 1 do
        local a = ui.stones[i]
        if a.available and not a.placed and not a.falling and a ~= ui.dragStone then
            for j = i + 1, #ui.stones do
                local b = ui.stones[j]
                if b.available and not b.placed and not b.falling and b ~= ui.dragStone then
                    local dx = b.x - a.x
                    local dy = b.y - a.y
                    local distSq = dx * dx + dy * dy
                    if distSq < minDistSq then
                        local dist = math.sqrt(distSq)
                        local nx = 1.0
                        local ny = 0.0
                        if dist > 0.0001 then
                            nx = dx / dist
                            ny = dy / dist
                        end

                        local overlap = (minDist - dist) * 0.5
                        a.x = a.x - nx * overlap
                        a.y = a.y - ny * overlap
                        b.x = b.x + nx * overlap
                        b.y = b.y + ny * overlap

                        local rvx = b.vx - a.vx
                        local rvy = b.vy - a.vy
                        local velAlongNormal = rvx * nx + rvy * ny
                        if velAlongNormal < 0.0 then
                            local impulse = -(1.0 + ui.drawerRestitution) *
                                velAlongNormal * 0.5
                            a.vx = a.vx - impulse * nx
                            a.vy = a.vy - impulse * ny
                            b.vx = b.vx + impulse * nx
                            b.vy = b.vy + impulse * ny
                        end

                        StoneTray.Clamp(ui, a, true)
                        StoneTray.Clamp(ui, b, true)
                    end
                end
            end
        end
    end
end

function StoneTray.UpdatePhysics(ui, dt)
    if not ui.drawerEnabled or not ui.motion or dt <= 0.0 then
        return
    end
    if not ui.motion.GetGravityDeltaX then
        return
    end
    if ui.motion.IsEnabled and not ui.motion:IsEnabled() then
        return
    end
    if ui.motion.IsCalibrated and not ui.motion:IsCalibrated() then
        return
    end

    local gravityX = ui.motion:GetGravityDeltaX()
    local gravityY = ui.motion:GetGravityDeltaY()
    local linearX = ui.motion:GetLinearX()
    local linearY = ui.motion:GetLinearY()
    local linearZ = ui.motion:GetLinearZ()

    local tiltDeadzone = 0.03
    if math.abs(gravityX) < tiltDeadzone then
        gravityX = 0.0
    end
    if math.abs(gravityY) < tiltDeadzone then
        gravityY = 0.0
    end

    local accelX = -gravityX * ui.drawerTiltScale - linearX * ui.drawerImpulseScale
    local accelY = gravityY * ui.drawerTiltScale +
        (linearY + linearZ * ui.drawerZInfluence) * ui.drawerImpulseScale
    if ui.drawerInvertX then
        accelX = -accelX
    end
    if ui.drawerInvertY then
        accelY = -accelY
    end

    local damping = 1.0 - ui.drawerFriction * dt
    if damping < 0.0 then
        damping = 0.0
    end

    for i = 1, #ui.stones do
        local stone = ui.stones[i]
        if stone.available and not stone.placed and not stone.falling and stone ~= ui.dragStone then
            stone.vx = stone.vx + accelX * dt
            stone.vy = stone.vy + accelY * dt
            stone.vx = stone.vx * damping
            stone.vy = stone.vy * damping

            local speed = math.sqrt(stone.vx * stone.vx + stone.vy * stone.vy)
            if speed > ui.drawerMaxSpeed and speed > 0.0001 then
                local scale = ui.drawerMaxSpeed / speed
                stone.vx = stone.vx * scale
                stone.vy = stone.vy * scale
            end

            stone.x = stone.x + stone.vx * dt
            stone.y = stone.y + stone.vy * dt
            StoneTray.Clamp(ui, stone, true)
        end
    end

    StoneTray.ResolveCollisions(ui)

    for i = 1, #ui.stones do
        local stone = ui.stones[i]
        if stone.available and not stone.placed and not stone.falling and stone ~= ui.dragStone then
            StoneTray.ApplyNodePosition(ui, stone)
        end
    end
end

function StoneTray.UpdateFalling(ui, dt)
    if dt <= 0.0 then
        return
    end

    for i = 1, #ui.stones do
        local stone = ui.stones[i]
        if stone.falling and not stone.placed then
            stone.fallTime = stone.fallTime + dt
            local t = stone.fallTime / stone.fallDuration
            if t > 1.0 then
                t = 1.0
            end

            local eased = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
            stone.x = stone.spawnX + (stone.targetX - stone.spawnX) * eased
            stone.y = stone.spawnY + (stone.targetY - stone.spawnY) * eased

            local scale = ui.stoneFallStartScale + (1.0 - ui.stoneFallStartScale) * eased
            local size = STONE_SIZE * scale
            local half = size * 0.5
            stone.renderX = stone.x - half
            stone.renderY = stone.y - half
            stone.node:SetDimensions(size, size)
            stone.node:SetPosition(stone.renderX, stone.renderY)

            if t >= 1.0 then
                stone.falling = false
                stone.x = stone.targetX
                stone.y = stone.targetY
                stone.node:SetDimensions(STONE_SIZE, STONE_SIZE)
                StoneTray.ApplyNodePosition(ui, stone)
            end
        end
    end
end

function StoneTray.RestoreFromDrag(ui, stone, x, y)
    stone.available = true
    stone.vx = 0.0
    stone.vy = 0.0
    if x and y and x >= 0.0 and y >= 0.0 then
        stone.x = x - ui.canvasX
        stone.y = y - ui.canvasY
    end
    StoneTray.Clamp(ui, stone, false)
    stone.renderX = stone.x - STONE_RADIUS
    stone.renderY = stone.y - STONE_RADIUS
    stone.node:SetDimensions(STONE_SIZE, STONE_SIZE)
    stone.node:SetPosition(stone.renderX, stone.renderY)
    stone.node:SetVisible(true)
end

function StoneTray.Stop(ui)
    ui.stones = {}
    ui.dragStone = nil
end
