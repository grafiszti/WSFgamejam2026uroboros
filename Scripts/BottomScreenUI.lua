BottomScreenUI = {}

local COLOR_PANEL = Vec(0.10, 0.22, 0.26, 1.0)
local COLOR_PANEL_ACTIVE = Vec(0.18, 0.72, 0.58, 1.0)
local COLOR_TEXT = Vec(0.92, 0.96, 0.95, 1.0)
local COLOR_TEXT_DIM = Vec(0.55, 0.68, 0.66, 1.0)
local COLOR_PANEL_TEXT = Vec(0.04, 0.08, 0.08, 1.0)
local COLOR_STONE = Vec(0.56, 0.52, 0.46, 1.0)
local COLOR_SLOT = Vec(0.08, 0.12, 0.14, 1.0)
local COLOR_SLOT_ACTIVE = Vec(0.25, 0.72, 0.58, 1.0)
local COLOR_GAUGE_LOW = Vec(0.25, 0.55, 0.55, 1.0)
local COLOR_GAUGE_HIGH = Vec(0.95, 0.78, 0.25, 1.0)

local STATUS_COLLECT = "SHAKE NEAR A RUNE"
local STATUS_DRAG = "DRAG A STONE TO THE BOWL"
local STATUS_FULL = "BOWL FULL"
local STATUS_TRAY_FULL = "TRAY FULL"

local STONE_COUNT = 5
local STONE_SIZE = 44.0
local STONE_RADIUS = STONE_SIZE * 0.5
local PLACED_STONE_SIZE = 30.0
local DRAWER_PADDING = 4.0
local SLOT_COUNT = 5
local STONE_FALL_DURATION = 0.55
local STONE_FALL_START_SCALE = 2.6

local function ResolveCanvas(script)
    local canvas = script:FindChild("BottomScreenCanvas")
    if canvas then
        return canvas
    end

    if script:FindChild("StatusText") then
        return script
    end

    return nil
end

function BottomScreenUI:Create()
    self.pointerIndex = 1

    self.canvas = nil
    self.status = nil
    self.panel = nil
    self.panelLabel = nil
    self.counter = nil
    self.marker = nil
    self.motionBarFill = nil
    self.motionLabel = nil
    self.dragGhost = nil
    self.motion = nil

    self.stones = {}
    self.slots = {}
    self.runeTextures = {}
    self.dragStone = nil
    self.placedCount = 0

    self.drawer = nil
    self.drawerX = 8.0
    self.drawerY = 164.0
    self.drawerWidth = 304.0
    self.drawerHeight = 72.0
    self.drawerMinX = 0.0
    self.drawerMaxX = 0.0
    self.drawerMinY = 0.0
    self.drawerMaxY = 0.0

    self.drawerEnabled = true
    self.drawerTiltScale = 160.0
    self.drawerImpulseScale = 700.0
    self.drawerZInfluence = 0.6
    self.drawerInvertX = false
    self.drawerInvertY = false
    self.drawerFriction = 0.0
    self.drawerRestitution = 0.55
    self.drawerMaxSpeed = 650.0

    self.stoneFallDuration = 0.55
    self.stoneFallStartScale = 2.6

    self.ready = false
    self.subscribed = false
    self.subscribedNote = false

    self.canvasX = 0.0
    self.canvasY = 0.0
    self.panelX = 0.0
    self.panelY = 0.0
    self.panelWidth = 0.0
    self.panelHeight = 0.0
    self.bowlX = 0.0
    self.bowlY = 0.0

    self.lastTouchX = -1
    self.lastTouchY = -1
    self.lastMarkerX = -1
    self.lastMarkerY = -1
    self.markerVisible = false
    self.statusTimer = 0.0
    self.markerHalfWidth = 10.0
    self.markerHalfHeight = 10.0

    self.gaugeWidth = 96.0
    self.lastGaugeWidth = -1.0
    self.gaugeHigh = false
    self.motionFlashTimer = 0.0
    self.motionLabelDefault = "SHAKE UP"
end

function BottomScreenUI:GatherProperties()
    return
    {
        { name = "pointerIndex", type = DatumType.Integer },
        { name = "drawerEnabled", type = DatumType.Bool },
        { name = "drawerTiltScale", type = DatumType.Float },
        { name = "drawerImpulseScale", type = DatumType.Float },
        { name = "drawerZInfluence", type = DatumType.Float },
        { name = "drawerInvertX", type = DatumType.Bool },
        { name = "drawerInvertY", type = DatumType.Bool },
        { name = "drawerFriction", type = DatumType.Float },
        { name = "drawerRestitution", type = DatumType.Float },
        { name = "drawerMaxSpeed", type = DatumType.Float },
        { name = "stoneFallDuration", type = DatumType.Float },
        { name = "stoneFallStartScale", type = DatumType.Float },
    }
end

function BottomScreenUI:Start()
    self.pointerIndex = math.max(1, math.min(4, math.floor(self.pointerIndex or 1)))
    self.drawerFriction = math.max(0.0, self.drawerFriction or 0.0)
    self.stoneFallDuration = math.max(0.05, self.stoneFallDuration or 0.55)
    self.stoneFallStartScale = math.max(1.0, self.stoneFallStartScale or 2.6)

    local canvas = ResolveCanvas(self)
    if not canvas then
        Log.Warning("BottomScreenUI: missing Canvas (expected BottomScreenCanvas)")
        self.ready = false
        return
    end

    self.canvas = canvas
    self.status = canvas:FindChild("StatusText")
    self.panel = canvas:FindChild("Panel")
    self.panelLabel = canvas:FindChild("PanelLabel")
    self.counter = canvas:FindChild("CounterText")
    self.marker = canvas:FindChild("TouchMarker")
    self.motionBarFill = canvas:FindChild("MotionBarFill")
    self.motionLabel = canvas:FindChild("MotionLabel")
    self.dragGhost = canvas:FindChild("DragGhost")

    if not (self.status and self.panel and self.panelLabel and self.counter and
        self.marker and self.motionBarFill and self.motionLabel and self.dragGhost) then
        Log.Warning("BottomScreenUI: missing authored widgets")
        self.ready = false
        return
    end

    local root = canvas:GetParent()
    if root then
        self.motion = root:FindChild("MotionSensor")
    end
    if not self.motion then
        local world = self:GetWorld()
        if world then
            self.motion = world:FindNode("MotionSensor")
        end
    end
    if not self.motion then
        Log.Warning("BottomScreenUI: missing MotionSensor node")
    elseif not (self.motion.GetIntensity and self.motion.GetGravityDeltaX) then
        Log.Warning("BottomScreenUI: MotionSensor script API missing")
    else
        Log.Debug("BottomScreenUI: motion API found")
    end

    local markerSize = self.marker:GetDimensions()
    self.markerHalfWidth = markerSize.x * 0.5
    self.markerHalfHeight = markerSize.y * 0.5

    local canvasPosition = canvas:GetPosition()
    local panelPosition = self.panel:GetPosition()
    local panelSize = self.panel:GetDimensions()
    self.canvasX = canvasPosition.x
    self.canvasY = canvasPosition.y
    self.panelX = panelPosition.x
    self.panelY = panelPosition.y
    self.panelWidth = panelSize.x
    self.panelHeight = panelSize.y
    self.bowlX = self.canvasX + self.panelX
    self.bowlY = self.canvasY + self.panelY

    local gaugeSize = canvas:FindChild("MotionBarBack")
    if gaugeSize then
        self.gaugeWidth = gaugeSize:GetDimensions().x
    end

    self.drawer = canvas:FindChild("Drawer")
    if self.drawer then
        local drawerPosition = self.drawer:GetPosition()
        local drawerSize = self.drawer:GetDimensions()
        self.drawerX = drawerPosition.x
        self.drawerY = drawerPosition.y
        self.drawerWidth = drawerSize.x
        self.drawerHeight = drawerSize.y
    else
        Log.Warning("BottomScreenUI: missing Drawer widget; using fallback bounds")
    end

    self.drawerMinX = self.drawerX + DRAWER_PADDING + STONE_RADIUS
    self.drawerMaxX = self.drawerX + self.drawerWidth - DRAWER_PADDING - STONE_RADIUS
    self.drawerMinY = self.drawerY + DRAWER_PADDING + STONE_RADIUS
    self.drawerMaxY = self.drawerY + self.drawerHeight - DRAWER_PADDING - STONE_RADIUS

    self.stones = {}
    for i = 1, STONE_COUNT do
        local stoneNode = canvas:FindChild("Stone_" .. tostring(i))
        if stoneNode then
            local stonePosition = stoneNode:GetPosition()
            stoneNode:SetDimensions(STONE_SIZE, STONE_SIZE)
            stoneNode:SetVisible(false)
            self.stones[#self.stones + 1] = {
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
            }
        end
    end
    if #self.stones == 0 then
        Log.Warning("BottomScreenUI: no Stone_1..Stone_5 widgets found")
    end

    self.slots = {}
    for i = 1, SLOT_COUNT do
        local slotNode = canvas:FindChild("Slot_" .. tostring(i))
        if slotNode then
            local slotPosition = slotNode:GetPosition()
            local slotSize = slotNode:GetDimensions()
            slotNode:SetColor(COLOR_SLOT)
            slotNode:SetVisible(true)
            self.slots[#self.slots + 1] = {
                node = slotNode,
                x = slotPosition.x,
                y = slotPosition.y,
                width = slotSize.x,
                height = slotSize.y,
                occupied = false,
                stone = nil,
            }
        end
    end
    if #self.slots == 0 then
        Log.Warning("BottomScreenUI: no Slot_1..Slot_5 widgets found")
    end

    self.dragGhost:SetDimensions(STONE_SIZE, STONE_SIZE)
    self.dragGhost:SetColor(COLOR_STONE)
    self.dragGhost:SetVisible(false)

    self.motionBarFill:SetWidth(0.0)
    self.motionBarFill:SetColor(COLOR_GAUGE_LOW)
    self.motionLabelDefault = "SHAKE UP"
    self.motionLabel:SetText(self.motionLabelDefault)
    self.motionLabel:SetColor(COLOR_TEXT_DIM)
    self.panel:SetColor(COLOR_PANEL)
    self.panelLabel:SetColor(COLOR_TEXT)
    self.status:SetText(STATUS_COLLECT)
    self.counter:SetText("STONES 0")
    self.marker:SetVisible(false)

    self.dragStone = nil
    self.placedCount = 0
    self.runeTextures = {}
    self.gaugeHigh = false
    self.lastGaugeWidth = -1.0
    self.motionFlashTimer = 0.0
    self.statusTimer = 0.0
    self.lastTouchX = -1
    self.lastTouchY = -1
    self.lastMarkerX = -1
    self.lastMarkerY = -1
    self.markerVisible = false

    if self.subscribed then
        SignalBus.Unsubscribe("ShakeDetected", self)
    end
    SignalBus.Subscribe("ShakeDetected", self, BottomScreenUI.OnShakeDetected)
    self.subscribed = true

    if self.subscribedNote then
        SignalBus.Unsubscribe("NoteCollected", self)
    end
    SignalBus.Subscribe("NoteCollected", self, BottomScreenUI.OnNoteCollected)
    self.subscribedNote = true

    self.ready = true
    Log.Debug("BottomScreenUI: ready")
end

function BottomScreenUI:IsInsidePanel(x, y)
    return x >= self.bowlX and x <= self.bowlX + self.panelWidth and
        y >= self.bowlY and y <= self.bowlY + self.panelHeight
end

function BottomScreenUI:FindSlotAt(x, y)
    local padding = 4.0
    for i = 1, #self.slots do
        local slot = self.slots[i]
        local left = self.canvasX + slot.x - padding
        local top = self.canvasY + slot.y - padding
        if x >= left and x <= left + slot.width + padding * 2.0 and
            y >= top and y <= top + slot.height + padding * 2.0 then
            return slot
        end
    end
    return nil
end

function BottomScreenUI:FindStoneAt(x, y)
    for i = 1, #self.stones do
        local stone = self.stones[i]
        if stone.available and not stone.placed and not stone.falling then
            local dx = x - (self.canvasX + stone.x)
            local dy = y - (self.canvasY + stone.y)
            if dx * dx + dy * dy <= STONE_RADIUS * STONE_RADIUS then
                return stone
            end
        end
    end
    return nil
end

function BottomScreenUI:ClampStoneToDrawer(stone, bounce)
    local restitution = 0.0
    if bounce then
        restitution = self.drawerRestitution
    end

    if stone.x < self.drawerMinX then
        stone.x = self.drawerMinX
        stone.vx = -stone.vx * restitution
    elseif stone.x > self.drawerMaxX then
        stone.x = self.drawerMaxX
        stone.vx = -stone.vx * restitution
    end

    if stone.y < self.drawerMinY then
        stone.y = self.drawerMinY
        stone.vy = -stone.vy * restitution
    elseif stone.y > self.drawerMaxY then
        stone.y = self.drawerMaxY
        stone.vy = -stone.vy * restitution
    end
end

function BottomScreenUI:ApplyStoneNodePosition(stone)
    local posX = stone.x - STONE_RADIUS
    local posY = stone.y - STONE_RADIUS
    if math.abs(posX - stone.renderX) > 0.5 or math.abs(posY - stone.renderY) > 0.5 then
        stone.renderX = posX
        stone.renderY = posY
        stone.node:SetPosition(posX, posY)
    end
end

function BottomScreenUI:UpdateMarker(x, y, forceStatus)
    local markerX = x - self.canvasX - self.markerHalfWidth
    local markerY = y - self.canvasY - self.markerHalfHeight
    if markerX ~= self.lastMarkerX or markerY ~= self.lastMarkerY then
        self.lastMarkerX = markerX
        self.lastMarkerY = markerY
        self.marker:SetPosition(markerX, markerY)
    end
    if not self.markerVisible then
        self.markerVisible = true
        self.marker:SetVisible(true)
    end

    if forceStatus then
        self.lastTouchX = math.floor(x)
        self.lastTouchY = math.floor(y)
        self.statusTimer = 0.1
    end
end

function BottomScreenUI:OnShakeDetected(intensity)
    if not self.ready then
        return
    end

    self.motionFlashTimer = 0.35
    self.motionLabel:SetText("DETECTED")
    self.motionLabel:SetColor(COLOR_GAUGE_HIGH)
end

function BottomScreenUI:OnNoteCollected(nodeType, runeArt)
    if not self.ready then
        return
    end

    self.motionFlashTimer = 0.35
    self.motionLabel:SetText("COLLECTED")
    self.motionLabel:SetColor(COLOR_GAUGE_HIGH)
    self:ShowNextStone(self:GetRuneTexture(runeArt))
end

function BottomScreenUI:GetRuneTexture(runeArt)
    if not runeArt or runeArt == "" then
        return nil
    end

    local cached = self.runeTextures[runeArt]
    if cached == nil then
        local asset = LoadAsset(runeArt)
        if asset and asset.GetTypeName and asset:GetTypeName() == "Texture" then
            cached = asset
        else
            cached = false
            if asset then
                Log.Warning("BottomScreenUI: rune art is not a Texture: " .. runeArt)
            else
                Log.Warning("BottomScreenUI: missing rune art: " .. runeArt)
            end
        end
        self.runeTextures[runeArt] = cached
    end

    if cached then
        return cached
    end
    return nil
end

function BottomScreenUI:GetStoneLandingY(stone)
    local targetY = stone.homeY + STONE_RADIUS
    if targetY < self.drawerMinY then
        targetY = self.drawerMinY
    elseif targetY > self.drawerMaxY then
        targetY = self.drawerMaxY
    end
    return targetY
end

function BottomScreenUI:ShowNextStone(texture)
    for i = 1, #self.stones do
        local stone = self.stones[i]
        if not stone.placed and not stone.available then
            local startSize = STONE_SIZE * self.stoneFallStartScale
            local startHalf = startSize * 0.5

            stone.available = true
            stone.falling = true
            stone.fallTime = 0.0
            stone.fallDuration = self.stoneFallDuration
            stone.spawnX = self.drawerX + self.drawerWidth * 0.5
            stone.spawnY = self.drawerY + self.drawerHeight + startHalf
            stone.targetX = math.max(self.drawerMinX, math.min(self.drawerMaxX, stone.homeX + STONE_RADIUS))
            stone.targetY = self:GetStoneLandingY(stone)
            stone.x = stone.spawnX
            stone.y = stone.spawnY
            stone.vx = 0.0
            stone.vy = 0.0
            stone.renderX = stone.x - startHalf
            stone.renderY = stone.y - startHalf
            stone.node:SetDimensions(startSize, startSize)
            stone.node:SetPosition(stone.renderX, stone.renderY)
            if texture then
                stone.node:SetTexture(texture)
                stone.node:SetColor(Vec(1, 1, 1, 1))
            else
                stone.node:SetTexture(nil)
                stone.node:SetColor(COLOR_STONE)
            end
            stone.node:SetVisible(true)
            self.status:SetText(STATUS_DRAG)
            Log.Debug("BottomScreenUI: stone revealed")
            return
        end
    end

    if self.placedCount >= #self.stones then
        self.status:SetText(STATUS_FULL)
    else
        self.status:SetText(STATUS_TRAY_FULL)
    end
end

function BottomScreenUI:StartDrag(stone, x, y)
    self.dragStone = stone
    stone.available = false
    stone.vx = 0.0
    stone.vy = 0.0

    local texture = stone.node:GetTexture()
    stone.node:SetVisible(false)

    self.dragGhost:SetDimensions(STONE_SIZE, STONE_SIZE)
    self.dragGhost:SetTexture(texture)
    self.dragGhost:SetColor(texture and Vec(1, 1, 1, 1) or COLOR_STONE)
    self.dragGhost:SetPosition(x - self.canvasX - STONE_SIZE * 0.5, y - self.canvasY - STONE_SIZE * 0.5)
    self.dragGhost:SetVisible(true)
    self.status:SetText(STATUS_DRAG)
    self:UpdateBowlHighlight(x, y)
end

function BottomScreenUI:UpdateSlotHighlight(x, y)
    local hovered = self:FindSlotAt(x, y)
    for i = 1, #self.slots do
        local slot = self.slots[i]
        slot.node:SetColor(slot == hovered and COLOR_SLOT_ACTIVE or COLOR_SLOT)
    end
end

function BottomScreenUI:UpdateBowlHighlight(x, y)
    local inside = self:IsInsidePanel(x, y)
    self.panel:SetColor(inside and COLOR_PANEL_ACTIVE or COLOR_PANEL)
    self.panelLabel:SetColor(inside and COLOR_PANEL_TEXT or COLOR_TEXT)
    self:UpdateSlotHighlight(x, y)
end

function BottomScreenUI:ResetSlotHighlight()
    for i = 1, #self.slots do
        self.slots[i].node:SetColor(COLOR_SLOT)
    end
end

function BottomScreenUI:UpdateDrag(x, y)
    self.dragGhost:SetPosition(x - self.canvasX - STONE_SIZE * 0.5, y - self.canvasY - STONE_SIZE * 0.5)
    self:UpdateBowlHighlight(x, y)
end

function BottomScreenUI:DropStone(x, y)
    local stone = self.dragStone
    if not stone then
        return
    end

    self.dragStone = nil
    self.dragGhost:SetVisible(false)
    self.panel:SetColor(COLOR_PANEL)
    self.panelLabel:SetColor(COLOR_TEXT)
    self:ResetSlotHighlight()

    local slot = self:FindSlotAt(x, y)
    if slot then
        local existing = slot.stone
        if existing then
            existing.placed = false
            existing.available = true
            existing.vx = 0.0
            existing.vy = 0.0
            existing.x = existing.homeX + STONE_RADIUS
            existing.y = existing.homeY + STONE_RADIUS
            self:ClampStoneToDrawer(existing, false)
            existing.renderX = existing.x - STONE_RADIUS
            existing.renderY = existing.y - STONE_RADIUS
            existing.node:SetDimensions(STONE_SIZE, STONE_SIZE)
            existing.node:SetPosition(existing.renderX, existing.renderY)
            existing.node:SetVisible(true)
        else
            self.placedCount = self.placedCount + 1
        end

        stone.placed = true
        stone.available = false
        stone.slot = slot
        slot.stone = stone
        slot.occupied = true

        local centerX = slot.x + slot.width * 0.5
        local centerY = slot.y + slot.height * 0.5
        stone.x = centerX
        stone.y = centerY
        stone.renderX = centerX - PLACED_STONE_SIZE * 0.5
        stone.renderY = centerY - PLACED_STONE_SIZE * 0.5
        stone.node:SetDimensions(PLACED_STONE_SIZE, PLACED_STONE_SIZE)
        stone.node:SetPosition(stone.renderX, stone.renderY)
        stone.node:SetVisible(true)

        self.counter:SetText("STONES " .. tostring(self.placedCount))
        Log.Debug("BottomScreenUI: stone placed")
        if self.placedCount >= #self.slots then
            self.status:SetText(STATUS_FULL)
        else
            self.status:SetText(STATUS_DRAG)
        end
    else
        stone.available = true
        stone.vx = 0.0
        stone.vy = 0.0
        if x and y then
            stone.x = x - self.canvasX
            stone.y = y - self.canvasY
        end
        self:ClampStoneToDrawer(stone, false)
        stone.renderX = stone.x - STONE_RADIUS
        stone.renderY = stone.y - STONE_RADIUS
        stone.node:SetDimensions(STONE_SIZE, STONE_SIZE)
        stone.node:SetPosition(stone.renderX, stone.renderY)
        stone.node:SetVisible(true)
        self.status:SetText(STATUS_DRAG)
    end
end

function BottomScreenUI:UpdateMotionIndicator(dt)
    local intensity = 0.0
    if self.motion and self.motion.GetIntensity then
        intensity = self.motion:GetIntensity() or 0.0
    end

    local width = math.max(0.0, math.min(1.0, intensity)) * self.gaugeWidth
    if math.abs(width - self.lastGaugeWidth) >= 1.0 then
        self.lastGaugeWidth = width
        self.motionBarFill:SetWidth(width)
    end

    local high = intensity >= 0.7
    if high ~= self.gaugeHigh then
        self.gaugeHigh = high
        self.motionBarFill:SetColor(high and COLOR_GAUGE_HIGH or COLOR_GAUGE_LOW)
    end

    if self.motionFlashTimer > 0.0 then
        self.motionFlashTimer = self.motionFlashTimer - dt
        if self.motionFlashTimer <= 0.0 then
            self.motionLabel:SetText(self.motionLabelDefault)
            self.motionLabel:SetColor(COLOR_TEXT_DIM)
        end
    end
end

function BottomScreenUI:ResolveStoneCollisions()
    local minDist = STONE_SIZE
    local minDistSq = minDist * minDist

    for i = 1, #self.stones - 1 do
        local a = self.stones[i]
        if a.available and not a.placed and not a.falling and a ~= self.dragStone then
            for j = i + 1, #self.stones do
                local b = self.stones[j]
                if b.available and not b.placed and not b.falling and b ~= self.dragStone then
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
                            local impulse = -(1.0 + self.drawerRestitution) * velAlongNormal * 0.5
                            a.vx = a.vx - impulse * nx
                            a.vy = a.vy - impulse * ny
                            b.vx = b.vx + impulse * nx
                            b.vy = b.vy + impulse * ny
                        end

                        self:ClampStoneToDrawer(a, true)
                        self:ClampStoneToDrawer(b, true)
                    end
                end
            end
        end
    end
end

function BottomScreenUI:UpdateDrawerPhysics(dt)
    if not self.drawerEnabled or not self.motion or dt <= 0.0 then
        return
    end
    if not self.motion.GetGravityDeltaX then
        return
    end

    if self.motion.IsCalibrated and not self.motion:IsCalibrated() then
        return
    end

    local gravityX = self.motion:GetGravityDeltaX()
    local gravityY = self.motion:GetGravityDeltaY()
    local linearX = self.motion:GetLinearX()
    local linearY = self.motion:GetLinearY()
    local linearZ = self.motion:GetLinearZ()

    local tiltDeadzone = 0.03
    if math.abs(gravityX) < tiltDeadzone then
        gravityX = 0.0
    end
    if math.abs(gravityY) < tiltDeadzone then
        gravityY = 0.0
    end

    local accelX = -gravityX * self.drawerTiltScale - linearX * self.drawerImpulseScale
    local accelY = gravityY * self.drawerTiltScale +
        (linearY + linearZ * self.drawerZInfluence) * self.drawerImpulseScale
    if self.drawerInvertX then
        accelX = -accelX
    end
    if self.drawerInvertY then
        accelY = -accelY
    end

    local damping = 1.0 - self.drawerFriction * dt
    if damping < 0.0 then
        damping = 0.0
    end

    for i = 1, #self.stones do
        local stone = self.stones[i]
        if stone.available and not stone.placed and not stone.falling and stone ~= self.dragStone then
            stone.vx = stone.vx + accelX * dt
            stone.vy = stone.vy + accelY * dt
            stone.vx = stone.vx * damping
            stone.vy = stone.vy * damping

            local speed = math.sqrt(stone.vx * stone.vx + stone.vy * stone.vy)
            if speed > self.drawerMaxSpeed and speed > 0.0001 then
                local scale = self.drawerMaxSpeed / speed
                stone.vx = stone.vx * scale
                stone.vy = stone.vy * scale
            end

            stone.x = stone.x + stone.vx * dt
            stone.y = stone.y + stone.vy * dt
            self:ClampStoneToDrawer(stone, true)
        end
    end

    self:ResolveStoneCollisions()

    for i = 1, #self.stones do
        local stone = self.stones[i]
        if stone.available and not stone.placed and not stone.falling and stone ~= self.dragStone then
            self:ApplyStoneNodePosition(stone)
        end
    end
end

function BottomScreenUI:UpdateFallingStones(dt)
    if dt <= 0.0 then
        return
    end

    for i = 1, #self.stones do
        local stone = self.stones[i]
        if stone.falling and not stone.placed then
            stone.fallTime = stone.fallTime + dt
            local t = stone.fallTime / stone.fallDuration
            if t > 1.0 then
                t = 1.0
            end

            local eased = 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)
            stone.x = stone.spawnX + (stone.targetX - stone.spawnX) * eased
            stone.y = stone.spawnY + (stone.targetY - stone.spawnY) * eased

            local scale = self.stoneFallStartScale + (1.0 - self.stoneFallStartScale) * eased
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
                self:ApplyStoneNodePosition(stone)
            end
        end
    end
end

function BottomScreenUI:Tick(deltaTime)
    if not self.ready then
        return
    end

    local realDelta = Engine.GetRealDeltaTime()
    local gameDelta = math.min(Engine.GetGameDeltaTime(), 0.05)
    self.statusTimer = self.statusTimer - realDelta
    self:UpdateMotionIndicator(realDelta)
    self:UpdateFallingStones(gameDelta)
    self:UpdateDrawerPhysics(gameDelta)

    if Input.IsPointerPressed(self.pointerIndex) then
        local x, y = Input.GetPointerPosition(self.pointerIndex)
        if x then
            self:UpdateMarker(x, y, true)
            if not self.dragStone then
                local stone = self:FindStoneAt(x, y)
                if stone then
                    self:StartDrag(stone, x, y)
                end
            end
        end
    elseif Input.IsPointerDown(self.pointerIndex) then
        local x, y = Input.GetPointerPosition(self.pointerIndex)
        if x then
            self:UpdateMarker(x, y, false)
            if self.dragStone then
                self:UpdateDrag(x, y)
            end
        end
    end

    if Input.IsPointerReleased(self.pointerIndex) then
        local x, y = Input.GetPointerPosition(self.pointerIndex)
        if self.dragStone then
            if x then
                self:DropStone(x, y)
            else
                self:DropStone(-1.0, -1.0)
            end
        end

        if self.markerVisible then
            self.markerVisible = false
            self.marker:SetVisible(false)
        end

        self.lastTouchX = -1
        self.lastTouchY = -1
        self.lastMarkerX = -1
        self.lastMarkerY = -1
        self.statusTimer = 0.0
    end
end

function BottomScreenUI:Stop()
    if self.subscribed then
        SignalBus.Unsubscribe("ShakeDetected", self)
        self.subscribed = false
    end
    if self.subscribedNote then
        SignalBus.Unsubscribe("NoteCollected", self)
        self.subscribedNote = false
    end

    self.canvas = nil
    self.status = nil
    self.panel = nil
    self.panelLabel = nil
    self.counter = nil
    self.marker = nil
    self.motionBarFill = nil
    self.motionLabel = nil
    self.dragGhost = nil
    self.motion = nil
    self.stones = {}
    self.slots = {}
    self.runeTextures = {}
    self.dragStone = nil
    self.ready = false
end
