Script.Load("Core/Events")
Script.Load("Core/RuneCatalog")
Script.Load("Core/GameSession")
Script.Load("UI/PointerInput")
Script.Load("UI/SongModel")
Script.Load("UI/StoneTray")
Script.Load("UI/StoneDragController")
Script.Load("UI/ClickSparkEffect")

BottomScreenUI = {}

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
    self.doubleTapTime = 0.35
    self.doubleTapDragThreshold = 10.0
    self.songFilled = 0
    self.playback = nil
    self.gameComplete = false
    self.endingRequested = false
    self.trayFullWarned = false
    self.lastTapStone = nil
    self.lastTapTime = -1.0
    self.dragStartX = 0.0
    self.dragStartY = 0.0

    self.drawer = nil
    self.drawerX = 0.0
    self.drawerY = 0.0
    self.drawerWidth = 0.0
    self.drawerHeight = 0.0
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
    self.stoneSize = 30.0
    self.stoneRadius = 15.0

    self.ready = false
    self.subscribedNote = false

    self.canvasX = 0.0
    self.canvasY = 0.0

    self.clickSparks = {}
    self.sparkTexture = nil
end

function BottomScreenUI:GatherProperties()
    return
    {
        { name = "pointerIndex", type = DatumType.Integer },
        { name = "songLength", type = DatumType.Integer },
        { name = "maxRuneRepeats", type = DatumType.Integer },
        { name = "noteInterval", type = DatumType.Float },
        { name = "doubleTapTime", type = DatumType.Float },
        { name = "doubleTapDragThreshold", type = DatumType.Float },
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
    self.doubleTapTime = math.max(0.15, self.doubleTapTime or 0.35)
    self.doubleTapDragThreshold = math.max(1.0, self.doubleTapDragThreshold or 10.0)
    self.drawerFriction = math.max(0.0, self.drawerFriction or 0.0)
    self.drawerRestitution = math.max(0.0, self.drawerRestitution or 0.55)
    self.drawerMaxSpeed = math.max(1.0, self.drawerMaxSpeed or 650.0)
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

    if self.marker then
        self.marker:SetVisible(false)
    end

    if not (self.dragGhost and self.drawer) then
        Log.Warning("BottomScreenUI: missing Drawer or DragGhost")
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

    local canvasPosition = canvas:GetPosition()
    self.canvasX = canvasPosition.x
    self.canvasY = canvasPosition.y

    ClickSparkEffect.Init(self)
    StoneTray.Init(self)

    self.songSlots = {}
    for i = 1, 7 do
        local slotNode = canvas:FindChild("SongSlot_" .. tostring(i))
        if slotNode then
            local slotPosition = slotNode:GetPosition()
            local slotSize = slotNode:GetDimensions()
            slotNode:SetVisible(true)
            self.songSlots[#self.songSlots + 1] =
            {
                node = slotNode,
                index = i,
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

    local runeEntries = RuneCatalog.All()
    self.songLength = math.min(self.songLength, #self.songSlots, #runeEntries)
    self.maxRuneRepeats = math.min(self.maxRuneRepeats, self.songLength)

    self.runeTextures = {}
    for i = 1, #runeEntries do
        local art = runeEntries[i].art
        local texture = LoadTextureAsset(art)
        if texture then
            self.runeTextures[art] = texture
        else
            self.runeTextures[art] = false
            Log.Warning("BottomScreenUI: missing rune texture: " .. art)
        end
    end

    SongModel.Reset(self)
    SongModel.Generate(self)
    SongModel.ApplyToSlots(self)
    SongModel.LoadSfx(self)

    local stoneSize = self.stoneSize or 30.0
    self.dragGhost:SetDimensions(stoneSize, stoneSize)
    self.dragGhost:SetColor(Vec(0.56, 0.52, 0.46, 1.0))
    self.dragGhost:SetTexture(nil)
    self.dragGhost:SetVisible(false)

    if self.marker then
        self.marker:SetVisible(false)
    end

    StoneDragController.Stop(self)
    self.trayFullWarned = false

    if self.subscribedNote then
        SignalBus.Unsubscribe(Events.NOTE_COLLECTED, self)
    end
    SignalBus.Subscribe(Events.NOTE_COLLECTED, self, BottomScreenUI.OnNoteCollected)
    self.subscribedNote = true

    GameSession.SetPhase(GameSession.PHASE_PLAYING)
    Engine.SetPaused(false)
    self.ready = true
    Log.Debug("BottomScreenUI: ready with " .. tostring(#self.song) .. " song tiles")
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

function BottomScreenUI:OnNoteCollected(nodeType, runeArt)
    if not self.ready or self.gameComplete or not GameSession.IsPlaying() then
        return
    end

    StoneTray.SpawnNext(self, runeArt)
end

function BottomScreenUI:Tick(deltaTime)
    if not self.ready then
        return
    end

    local gameDelta = math.min(Engine.GetGameDeltaTime(), 0.05)

    StoneTray.UpdateFalling(self, gameDelta)
    StoneTray.UpdatePhysics(self, gameDelta)
    SongModel.UpdatePlayback(self, gameDelta)
    ClickSparkEffect.Update(self, gameDelta)
    StoneDragController.UpdateInput(self)
end

function BottomScreenUI:Stop()
    if self.subscribedNote then
        SignalBus.Unsubscribe(Events.NOTE_COLLECTED, self)
        self.subscribedNote = false
    end

    SongModel.Stop(self)
    StoneTray.Stop(self)
    StoneDragController.Stop(self)
    ClickSparkEffect.Stop(self)

    self.canvas = nil
    self.marker = nil
    self.dragGhost = nil
    self.motion = nil
    self.drawer = nil
    self.songSlots = {}
    self.runeTextures = {}
    self.song = {}
    self.songSfx = {}
    self.ready = false
end
