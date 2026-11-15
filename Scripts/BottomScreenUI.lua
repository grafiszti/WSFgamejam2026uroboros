BottomScreenUI = {}

local COLOR_STONE = Vec(0.56, 0.52, 0.46, 1.0)
local COLOR_TILE_PENDING = Vec(0.55, 0.55, 0.55, 1.0)
local COLOR_TILE_FILLED = Vec(1.0, 1.0, 1.0, 1.0)
local PENDING_OPACITY = 0.45

local RUNE_ARTS =
{
    "Tile - Mol1",
    "Tile - Mol2",
    "Tile - Mol3",
    "Tile - Mol4",
    "Tile - Dur1",
    "Tile - Dur2",
    "Tile - Dur3",
    "Tile - Dur4",
    "Tile - Dur5",
    "Tile - Dur6",
}

local RUNE_SFX =
{
    ["Tile - Mol1"] = "C-Mol1-SFX",
    ["Tile - Mol2"] = "D-Mol2-SFX",
    ["Tile - Mol3"] = "F-Mol3-SFX",
    ["Tile - Mol4"] = "G-Mol4-SFX",
    ["Tile - Dur1"] = "C-Dur1-SFX",
    ["Tile - Dur2"] = "D-Dur2-SFX",
    ["Tile - Dur3"] = "E-Dur3-SFX",
    ["Tile - Dur4"] = "F-Dur4-SFX",
    ["Tile - Dur5"] = "G-Dur5-SFX",
    ["Tile - Dur6"] = "A-Dur6-SFX",
}

local STONE_COUNT = 7
local SONG_SLOT_COUNT = 7
local STONE_SIZE = 44.0
local STONE_RADIUS = STONE_SIZE * 0.5
local DRAWER_PADDING = 4.0
local SLOT_PADDING = 2.0
local STONE_FALL_DURATION = 0.55
local STONE_FALL_START_SCALE = 2.6

local function ResolveCanvas(script)
    local canvas = script:FindChild("BottomScreenCanvas")
    if canvas then
        return canvas
    end

    if script:FindChild("Drawer") then
        return script
    end

    return nil
end

local function LoadTextureAsset(name)
    if not name or name == "" then
        return nil
    end

    local asset = LoadAsset(name)
    if asset and asset.GetTypeName and asset:GetTypeName() == "Texture" then
        return asset
    end

    return nil
end

function BottomScreenUI:Create()
    self.pointerIndex = 1

    self.canvas = nil
    self.marker = nil
    self.dragGhost = nil
    self.motion = nil

    self.stones = {}
    self.songSlots = {}
    self.runeTextures = {}
    self.song = {}
    self.songSfx = {}
    self.dragStone = nil

    self.songLength = 7
    self.maxRuneRepeats = 2
    self.noteInterval = 0.38
    self.songFilled = 0
    self.playback = nil
    self.gameComplete = false
    self.pausedByGame = false
    self.trayFullWarned = false

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
    self.subscribedNote = false

    self.canvasX = 0.0
    self.canvasY = 0.0

    self.lastMarkerX = -1
    self.lastMarkerY = -1
    self.markerVisible = false
    self.markerHalfWidth = 10.0
    self.markerHalfHeight = 10.0
end

function BottomScreenUI:GatherProperties()
    return
    {
        { name = "pointerIndex", type = DatumType.Integer },
        { name = "songLength", type = DatumType.Integer },
        { name = "maxRuneRepeats", type = DatumType.Integer },
        { name = "noteInterval", type = DatumType.Float },
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
    self.songLength = math.max(1, math.floor(self.songLength or 7))
    self.maxRuneRepeats = math.max(1, math.floor(self.maxRuneRepeats or 2))
    self.noteInterval = math.max(0.05, self.noteInterval or 0.38)
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
    self.marker = canvas:FindChild("TouchMarker")
    self.dragGhost = canvas:FindChild("DragGhost")
    self.drawer = canvas:FindChild("Drawer")

    if not (self.marker and self.dragGhost and self.drawer) then
        Log.Warning("BottomScreenUI: missing Drawer, DragGhost, or TouchMarker")
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
    end

    local markerSize = self.marker:GetDimensions()
    self.markerHalfWidth = markerSize.x * 0.5
    self.markerHalfHeight = markerSize.y * 0.5

    local canvasPosition = canvas:GetPosition()
    self.canvasX = canvasPosition.x
    self.canvasY = canvasPosition.y

    local drawerPosition = self.drawer:GetPosition()
    local drawerSize = self.drawer:GetDimensions()
    self.drawerX = drawerPosition.x
    self.drawerY = drawerPosition.y
    self.drawerWidth = drawerSize.x
    self.drawerHeight = drawerSize.y

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
            self.stones[#self.stones + 1] =
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
    if #self.stones == 0 then
        Log.Warning("BottomScreenUI: no Stone_1..Stone_7 widgets found")
    end

    self.songSlots = {}
    for i = 1, SONG_SLOT_COUNT do
        local slotNode = canvas:FindChild("SongSlot_" .. tostring(i))
        if slotNode then
            local slotPosition = slotNode:GetPosition()
            local slotSize = slotNode:GetDimensions()
            slotNode:SetVisible(true)
            self.songSlots[#self.songSlots + 1] =
            {
                node = slotNode,
                x = slotPosition.x,
                y = slotPosition.y,
                width = slotSize.x,
                height = slotSize.y,
                runeArt = "",
                filled = false,
            }
        end
    end
    if #self.songSlots == 0 then
        Log.Warning("BottomScreenUI: no SongSlot_1..SongSlot_7 widgets found")
        self.ready = false
        return
    end

    self.songLength = math.min(self.songLength, #self.songSlots, #RUNE_ARTS)
    self.maxRuneRepeats = math.min(self.maxRuneRepeats, self.songLength)

    self.runeTextures = {}
    for i = 1, #RUNE_ARTS do
        local art = RUNE_ARTS[i]
        local texture = LoadTextureAsset(art)
        if texture then
            self.runeTextures[art] = texture
        else
            self.runeTextures[art] = false
            Log.Warning("BottomScreenUI: missing rune texture: " .. art)
        end
    end

    self:GenerateSong()
    self:ApplySongToSlots()

    self.songSfx = {}
    for i = 1, #self.song do
        local sfxName = RUNE_SFX[self.song[i]]
        if sfxName then
            local sound = LoadAsset(sfxName)
            if sound then
                self.songSfx[i] = sound
            else
                Log.Warning("BottomScreenUI: missing rune SFX: " .. sfxName)
            end
        end
    end

    self.dragGhost:SetDimensions(STONE_SIZE, STONE_SIZE)
    self.dragGhost:SetColor(COLOR_STONE)
    self.dragGhost:SetTexture(nil)
    self.dragGhost:SetVisible(false)

    self.marker:SetVisible(false)

    self.dragStone = nil
    self.songFilled = 0
    self.playback = nil
    self.gameComplete = false
    self.pausedByGame = false
    self.trayFullWarned = false
    self.lastMarkerX = -1
    self.lastMarkerY = -1
    self.markerVisible = false

    if self.subscribedNote then
        SignalBus.Unsubscribe("NoteCollected", self)
    end
    SignalBus.Subscribe("NoteCollected", self, BottomScreenUI.OnNoteCollected)
    self.subscribedNote = true

    Engine.SetPaused(false)
    self.ready = true
    Log.Debug("BottomScreenUI: ready with " .. tostring(#self.song) .. " song tiles")
end

function BottomScreenUI:GenerateSong()
    self.song = {}
    self.songFilled = 0

    if math.randomseed then
        local seed = math.floor((Engine.GetTime() or 0.0) * 1000000.0)
        math.randomseed(seed)
    end

    local counts = {}
    for i = 1, self.songLength do
        local candidates = {}
        for j = 1, #RUNE_ARTS do
            if (counts[j] or 0) < self.maxRuneRepeats then
                candidates[#candidates + 1] = j
            end
        end

        if #candidates == 0 then
            break
        end

        local pick = candidates[math.random(1, #candidates)]
        counts[pick] = (counts[pick] or 0) + 1
        self.song[#self.song + 1] = RUNE_ARTS[pick]
    end
end

function BottomScreenUI:ApplySongToSlots()
    for i = 1, #self.songSlots do
        local slot = self.songSlots[i]
        local art = self.song[i]
        if art then
            slot.runeArt = art
            slot.filled = false
            slot.node:SetTexture(self:GetRuneTexture(art))
            slot.node:SetColor(COLOR_TILE_PENDING)
            slot.node:SetOpacityFloat(PENDING_OPACITY)
            slot.node:SetVisible(true)
        else
            slot.runeArt = ""
            slot.filled = true
            slot.node:SetVisible(false)
        end
    end
end

function BottomScreenUI:FindSlotAt(x, y)
    for i = 1, #self.songSlots do
        local slot = self.songSlots[i]
        local left = self.canvasX + slot.x - SLOT_PADDING
        local top = self.canvasY + slot.y - SLOT_PADDING
        if x >= left and x <= left + slot.width + SLOT_PADDING * 2.0 and
            y >= top and y <= top + slot.height + SLOT_PADDING * 2.0 then
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

function BottomScreenUI:UpdateMarker(x, y)
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
end

function BottomScreenUI:OnNoteCollected(nodeType, runeArt)
    if not self.ready or self.gameComplete then
        return
    end

    self:ShowNextStone(runeArt)
end

function BottomScreenUI:GetRuneTexture(runeArt)
    if not runeArt or runeArt == "" then
        return nil
    end

    local cached = self.runeTextures[runeArt]
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

function BottomScreenUI:ShowNextStone(runeArt)
    local texture = self:GetRuneTexture(runeArt)

    for i = 1, #self.stones do
        local stone = self.stones[i]
        if not stone.placed and not stone.available and stone ~= self.dragStone then
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

    if not self.trayFullWarned then
        self.trayFullWarned = true
        Log.Debug("BottomScreenUI: stone tray is full")
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
    self.dragGhost:SetColor(texture and Vec(1.0, 1.0, 1.0, 1.0) or COLOR_STONE)
    self.dragGhost:SetPosition(x - self.canvasX - STONE_SIZE * 0.5, y - self.canvasY - STONE_SIZE * 0.5)
    self.dragGhost:SetVisible(true)
end

function BottomScreenUI:UpdateDrag(x, y)
    self.dragGhost:SetPosition(x - self.canvasX - STONE_SIZE * 0.5, y - self.canvasY - STONE_SIZE * 0.5)
end

function BottomScreenUI:DropStone(x, y)
    local stone = self.dragStone
    if not stone then
        return
    end

    self.dragStone = nil
    self.dragGhost:SetVisible(false)

    local slot = nil
    if x and y and x >= 0.0 and y >= 0.0 then
        slot = self:FindSlotAt(x, y)
    end

    if slot and not slot.filled and slot.runeArt ~= "" and slot.runeArt == stone.runeArt then
        stone.placed = true
        stone.available = false
        stone.falling = false
        stone.vx = 0.0
        stone.vy = 0.0
        stone.runeArt = ""
        stone.node:SetVisible(false)

        slot.filled = true
        slot.node:SetColor(COLOR_TILE_FILLED)
        slot.node:SetOpacityFloat(1.0)

        self.songFilled = self.songFilled + 1
        self.trayFullWarned = false
        Log.Debug("BottomScreenUI: song tile filled")

        if self.songFilled >= #self.song then
            self:BeginCompletion()
        end
        return
    end

    stone.available = true
    stone.vx = 0.0
    stone.vy = 0.0
    if x and y and x >= 0.0 and y >= 0.0 then
        stone.x = x - self.canvasX
        stone.y = y - self.canvasY
    end
    self:ClampStoneToDrawer(stone, false)
    stone.renderX = stone.x - STONE_RADIUS
    stone.renderY = stone.y - STONE_RADIUS
    stone.node:SetDimensions(STONE_SIZE, STONE_SIZE)
    stone.node:SetPosition(stone.renderX, stone.renderY)
    stone.node:SetVisible(true)
end

function BottomScreenUI:BeginCompletion()
    if self.gameComplete then
        return
    end

    self.gameComplete = true
    self.playback = { index = 1, timer = 0.0 }
    SignalBus.Emit("GameCompleted")
    Log.Debug("BottomScreenUI: song complete")
end

function BottomScreenUI:UpdatePlayback(dt)
    if not self.playback or dt <= 0.0 then
        return
    end

    local playback = self.playback
    playback.timer = playback.timer - dt
    if playback.timer > 0.0 then
        return
    end

    if playback.index <= #self.song then
        local sound = self.songSfx[playback.index]
        if sound then
            Audio.PlaySound2D(sound, 1.0, 1.0)
        end
        playback.index = playback.index + 1
        playback.timer = self.noteInterval
    else
        self.playback = nil
        self.pausedByGame = true
        Engine.SetPaused(true)
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

    local gameDelta = math.min(Engine.GetGameDeltaTime(), 0.05)

    self:UpdateFallingStones(gameDelta)
    self:UpdateDrawerPhysics(gameDelta)
    self:UpdatePlayback(gameDelta)

    if not self.gameComplete then
        if Input.IsPointerPressed(self.pointerIndex) then
            local x, y = Input.GetPointerPosition(self.pointerIndex)
            if x then
                self:UpdateMarker(x, y)
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
                self:UpdateMarker(x, y)
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

            self.lastMarkerX = -1
            self.lastMarkerY = -1
        end
    else
        if self.markerVisible then
            self.markerVisible = false
            self.marker:SetVisible(false)
        end
    end
end

function BottomScreenUI:Stop()
    if self.subscribedNote then
        SignalBus.Unsubscribe("NoteCollected", self)
        self.subscribedNote = false
    end

    if self.pausedByGame then
        Engine.SetPaused(false)
        self.pausedByGame = false
    end

    self.canvas = nil
    self.marker = nil
    self.dragGhost = nil
    self.motion = nil
    self.drawer = nil
    self.stones = {}
    self.songSlots = {}
    self.runeTextures = {}
    self.song = {}
    self.songSfx = {}
    self.dragStone = nil
    self.playback = nil
    self.gameComplete = false
    self.ready = false
end
