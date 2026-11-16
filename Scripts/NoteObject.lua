Script.Load("Core/Events")
Script.Load("Core/RuneCatalog")
Script.Load("Core/GameSession")
Script.Load("Core/PhaseVisibility")
Script.Load("Core/SurfaceMath")

NoteObject = {}

function NoteObject:Create()
    if self.NodeType == nil then self.NodeType = 0 end
    if self.RuneArt == nil then self.RuneArt = "" end
    self.PlayerInProx = false
    self.ProximityRadius = 3.0
    self.proximityRadiusSq = 9.0
    self.player = nil
    self.collecting = false
    self.tweenID = nil
    self.subscribed = false
    self.subscribedReveal = false
    self.subscribedDayNight = false
    self.revealed = false
    self.isNightRune = false
    self.isDay = true
    self.phaseVisible = true
end

function NoteObject:GatherProperties()
    return {
        { name = "NodeType", type = DatumType.Integer },
        { name = "ProximityRadius", type = DatumType.Float },
        { name = "RuneArt", type = DatumType.String },
    }
end

function NoteObject:UpdateNightRune()
    local art = self.RuneArt or ""
    if art == "" then
        art = RuneCatalog.ArtForNode(self:GetName())
    end
    self.isNightRune = RuneCatalog.IsNight(art)
end

function NoteObject:Start()
    self.PlayerInProx = false
    self.ProximityRadius = math.max(0.5, self.ProximityRadius or 3.0)
    self.proximityRadiusSq = self.ProximityRadius * self.ProximityRadius
    self.collecting = false

    local world = self:GetWorld()
    self.player = world and world:FindNode("ThirdPersonPlayer") or nil

    local function disableOverlaps(node)
        if node:IsA("Primitive3D") then
            node:EnableOverlaps(false)
        end
        for i = 1, node:GetNumChildren() do
            disableOverlaps(node:GetChild(i))
        end
    end
    disableOverlaps(self)

    if self.RuneArt == nil or self.RuneArt == "" then
        self.RuneArt = RuneCatalog.ArtForNode(self:GetName())
    end

    self:UpdateNightRune()
    self.isDay = GameSession.IsDay()
    if DayNightCycle and DayNightCycle.isDay ~= nil then
        self.isDay = DayNightCycle.isDay
        GameSession.SetDay(self.isDay)
    end

    if self.subscribed then
        SignalBus.Unsubscribe(Events.SHAKE_DETECTED, self)
    end
    SignalBus.Subscribe(Events.SHAKE_DETECTED, self, NoteObject.OnShakeDetected)
    self.subscribed = true

    if self.subscribedReveal then
        SignalBus.Unsubscribe(Events.RUNE_REVEALED, self)
    end
    SignalBus.Subscribe(Events.RUNE_REVEALED, self, NoteObject.OnRuneRevealed)
    self.subscribedReveal = true

    if self.subscribedDayNight then
        SignalBus.Unsubscribe(Events.DAY_NIGHT_CHANGED, self)
    end
    SignalBus.Subscribe(Events.DAY_NIGHT_CHANGED, self, NoteObject.OnDayNightChanged)
    self.subscribedDayNight = true
end

function NoteObject:OnRuneRevealed(noteName, runeArt, revealTag)
    if revealTag ~= nil and revealTag ~= "" then
        if not self:HasTag(revealTag) then
            return
        end
    elseif noteName ~= self:GetName() or not self:HasTag("RevealedRune") then
        return
    end

    if runeArt and runeArt ~= "" then
        self.RuneArt = runeArt
    end

    self.revealed = true
    self:UpdateNightRune()
    self.isDay = GameSession.IsDay()
    if DayNightCycle and DayNightCycle.isDay ~= nil then
        self.isDay = DayNightCycle.isDay
        GameSession.SetDay(self.isDay)
    end
    self:ApplyPhaseVisibility(self.isDay)
end

function NoteObject:ApplyPhaseVisibility(isDay)
    if not self.revealed or self.collecting then
        return
    end

    local show = PhaseVisibility.ShouldShow(self.isNightRune, isDay)
    self.phaseVisible = show
    self:SetVisible(show)
end

function NoteObject:OnDayNightChanged(isDay)
    self.isDay = isDay
    GameSession.SetDay(isDay)
    self:ApplyPhaseVisibility(isDay)
end

function NoteObject:Tick(deltaTime)
    if self.collecting or not self.revealed then
        self.PlayerInProx = false
        return
    end

    if not self.player then
        local world = self:GetWorld()
        self.player = world and world:FindNode("ThirdPersonPlayer") or nil
    end

    if not self.player then
        self.PlayerInProx = false
        return
    end

    self.PlayerInProx = SurfaceMath.SquaredDistance(self:GetWorldPosition(),
        self.player:GetWorldPosition()) <= self.proximityRadiusSq
end

function NoteObject:OnShakeDetected(intensity)
    if not GameSession.IsPlaying() then
        return
    end

    if not self:IsActive(true) or not self:IsVisible(true) then
        return
    end

    if not self.PlayerInProx or self.collecting then
        return
    end

    local world = self:GetWorld()
    if not world then
        return
    end

    local cam = world:GetActiveCamera()
    if not cam then
        return
    end

    self.collecting = true
    self.PlayerInProx = false
    self:EnableOverlaps(false)

    local startPos = self:GetWorldPosition()
    self.tweenID = Tween.Value(Easing.OutExpo, 0.0, 1.0, 0.36, function(value, pct, finished)
        local lerped = Vector.Lerp(startPos, cam:GetWorldPosition(), value)
        self:SetWorldPosition(lerped)
        if finished then
            self.tweenID = nil
            SignalBus.Emit(Events.NOTE_COLLECTED, self.NodeType, self.RuneArt)
            self:DestroyDeferred()
        end
    end)
end

function NoteObject:Stop()
    if self.tweenID then
        Tween.Cancel(self.tweenID)
        self.tweenID = nil
    end

    if self.subscribed then
        SignalBus.Unsubscribe(Events.SHAKE_DETECTED, self)
        self.subscribed = false
    end

    if self.subscribedReveal then
        SignalBus.Unsubscribe(Events.RUNE_REVEALED, self)
        self.subscribedReveal = false
    end

    if self.subscribedDayNight then
        SignalBus.Unsubscribe(Events.DAY_NIGHT_CHANGED, self)
        self.subscribedDayNight = false
    end

    self.PlayerInProx = false
    self.collecting = false
    self.player = nil
end
