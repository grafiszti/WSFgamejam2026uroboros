Script.Load("Core/Events")
Script.Load("Core/CollisionLayers")
Script.Load("Core/RuneCatalog")
Script.Load("Core/GameSession")
Script.Load("Core/GameActions")
Script.Load("Core/PhaseVisibility")
Script.Load("Core/SurfaceMath")

NoteRockToDestroy = {}

local SURFACE_COLLISION_MASK = CollisionLayers.Environment
local REVEAL_SOUND = "Magic-spell-SFF"
local ROCK_PARTICLE = "RockDestroyParticle"
local REVEAL_PARTICLE = "StarsDestroyParticle"
local sRevealSoundWarned = false
local sRockParticleWarned = false
local sRevealParticleWarned = false

local function SetCollisionRecursive(node, enabled)
    if node == nil then
        return
    end

    if node:IsA("Primitive3D") then
        node:EnableCollision(enabled)
    end

    for i = 1, node:GetNumChildren() do
        SetCollisionRecursive(node:GetChild(i), enabled)
    end
end

local function ApplyStoneCollisionGroup(node)
    if node == nil then
        return
    end

    if node:IsA("Primitive3D") then
        node:SetCollisionGroup(CollisionLayers.Stone)
        node:EnableOverlaps(false)
    end

    local childCount = node:GetNumChildren()
    for i = 1, childCount do
        ApplyStoneCollisionGroup(node:GetChild(i))
    end
end

function NoteRockToDestroy:Create()
    self.NoteNode = nil
    self.PlayerInProx = false
    self.hiddenPos = Vec()
    self.showPos = Vec()
    self.HitsRequired = 1
    self.ProximityRadius = 3.5
    self.SurfaceClearance = 1.25
    self.SnapDistance = 12.0
    self.RuneArt = ""
    self.RevealSound = nil
    self.RevealVolume = 0.5
    self.HitParticle = nil
    self.RevealParticle = nil
    self.hitParticle = nil
    self.revealParticle = nil
    self.particleVelocity = Vec(0.0, 1.5, 0.0)
    self.proximityRadiusSq = 12.25
    self.player = nil
    self.hitsRemaining = 1
    self.baseScale = nil
    self.punchTween = nil
    self.moveTween = nil
    self.revealed = false
    self.isNightStone = false
    self.phaseVisible = true
    self.subscribedDayNight = false
end

function NoteRockToDestroy:GatherProperties()
    return {
        { name = "NoteNode",       type = DatumType.Node },
        { name = "HitsRequired",   type = DatumType.Integer },
        { name = "ProximityRadius", type = DatumType.Float },
        { name = "SurfaceClearance", type = DatumType.Float },
        { name = "SnapDistance",    type = DatumType.Float },
        { name = "RuneArt",        type = DatumType.String },
        { name = "RevealSound",    type = DatumType.Asset },
        { name = "RevealVolume",   type = DatumType.Float },
        { name = "HitParticle",    type = DatumType.Asset },
        { name = "RevealParticle", type = DatumType.Asset },
    }
end

function NoteRockToDestroy:Start()
    ApplyStoneCollisionGroup(self)

    self.hitsRemaining = math.max(1, math.floor(self.HitsRequired or 1))
    self.ProximityRadius = math.max(0.5, self.ProximityRadius or 3.5)
    self.proximityRadiusSq = self.ProximityRadius * self.ProximityRadius
    self.SurfaceClearance = math.max(0.0, self.SurfaceClearance or 1.25)
    self.SnapDistance = math.max(0.5, self.SnapDistance or 12.0)
    self.baseScale = self:GetScale()
    self.punchTween = nil
    self.moveTween = nil
    self.revealed = false

    if self.RuneArt == nil or self.RuneArt == "" then
        self.RuneArt = RuneCatalog.ArtForNode(self:GetName())
    end

    self.RevealVolume = math.max(0.0, self.RevealVolume or 0.5)
    if self.RevealSound == nil then
        self.RevealSound = LoadAsset(REVEAL_SOUND)
    end
    if self.RevealSound == nil and not sRevealSoundWarned then
        sRevealSoundWarned = true
        Log.Warning("NoteRockToDestroy: missing sound " .. REVEAL_SOUND)
    end

    self.hitParticle = self.HitParticle
    if self.hitParticle == nil then
        self.hitParticle = LoadAsset(ROCK_PARTICLE)
    end
    if self.hitParticle == nil and not sRockParticleWarned then
        sRockParticleWarned = true
        Log.Warning("NoteRockToDestroy: missing particle " .. ROCK_PARTICLE)
    end

    self.revealParticle = self.RevealParticle
    if self.revealParticle == nil then
        self.revealParticle = LoadAsset(REVEAL_PARTICLE)
    end
    if self.revealParticle == nil and not sRevealParticleWarned then
        sRevealParticleWarned = true
        Log.Warning("NoteRockToDestroy: missing particle " .. REVEAL_PARTICLE)
    end

    if not self.NoteNode then
        local childCount = self:GetNumChildren()
        for i = 1, childCount do
            local child = self:GetChild(i)
            local childName = child and child:GetName() or ""
            if childName:sub(1, 10) == "SM_Tile - " then
                self.NoteNode = child
                break
            end
        end
    end

    if not self.NoteNode then
        Log.Warning("NoteRockToDestroy: missing NoteNode on " .. self:GetName())
    end

    local world = self:GetWorld()
    self.player = world and world:FindNode("ThirdPersonPlayer") or nil

    self.showPos = self:GetPosition()
    local up = SurfaceMath.SafeNormalize(self:GetUpVector(), Vec(0.0, 1.0, 0.0))
    self.hiddenPos = self.showPos - up * 2.0

    self.isNightStone = RuneCatalog.IsNight(self.RuneArt)
    self.phaseVisible = true

    if self.subscribedDayNight then
        SignalBus.Unsubscribe(Events.DAY_NIGHT_CHANGED, self)
    end
    SignalBus.Subscribe(Events.DAY_NIGHT_CHANGED, self, NoteRockToDestroy.OnDayNightChanged)
    self.subscribedDayNight = true

    local isDay = GameSession.IsDay()
    if DayNightCycle and DayNightCycle.isDay ~= nil then
        isDay = DayNightCycle.isDay
        GameSession.SetDay(isDay)
    end
    local show = PhaseVisibility.ShouldShow(self.isNightStone, isDay)
    self:SetPhaseVisible(show, true)
end

function NoteRockToDestroy:SpawnParticleBurst(system, position)
    if system == nil then
        return
    end

    local world = self:GetWorld()
    if not world then
        return
    end

    local particle = world:SpawnParticle(system, position, self.particleVelocity)
    if particle and TargetScreen then
        particle:SetTargetScreen(TargetScreen.Top)
    end
end

function NoteRockToDestroy:PlayHitFeedback()
    if not self.baseScale then
        return
    end

    if self.punchTween then
        Tween.Cancel(self.punchTween)
        self.punchTween = nil
    end

    local punch = Vec(self.baseScale.x * 0.9, self.baseScale.y * 0.9, self.baseScale.z * 0.9)
    self.punchTween = Tween.Scale(self, Easing.OutQuad, punch, 0.06, function()
        self.punchTween = Tween.Scale(self, Easing.OutBack, self.baseScale, 0.12)
    end)
end

function NoteRockToDestroy:UpdatePlayerProximity()
    if not self.player then
        self.PlayerInProx = false
        return
    end

    self.PlayerInProx = SurfaceMath.SquaredDistance(self:GetWorldPosition(),
        self.player:GetWorldPosition()) <= self.proximityRadiusSq
end

function NoteRockToDestroy:GetSurfaceUp()
    local up = nil
    if self.player then
        up = self.player:GetUpVector()
    end

    if up == nil then
        up = self:GetUpVector()
    end

    return SurfaceMath.SafeNormalize(up, Vec(0.0, 1.0, 0.0))
end

function NoteRockToDestroy:SnapNoteAboveSurface()
    if not self.NoteNode then
        return
    end

    local world = self:GetWorld()
    if not world then
        return
    end

    local up = self:GetSurfaceUp()
    local notePos = self.NoteNode:GetWorldPosition()
    local startPos = notePos + up * self.SnapDistance
    local endPos = notePos - up * self.SnapDistance
    local ignore = { self, self.NoteNode }
    local result = world:RayTest(startPos, endPos, SURFACE_COLLISION_MASK, ignore)

    if result and result.hitNode then
        local height = Vector.Dot(notePos - result.hitPosition, up)
        if height < self.SurfaceClearance then
            local normal = SurfaceMath.SafeNormalize(result.hitNormal, up)
            if Vector.Dot(normal, up) < 0.0 then
                normal = normal * -1.0
            end
            self.NoteNode:SetWorldPosition(result.hitPosition + normal * self.SurfaceClearance)
        end
    end
end

function NoteRockToDestroy:Tick(deltaTime)
    if self.revealed or not self.phaseVisible then
        self.PlayerInProx = false
        return
    end

    if not GameSession.IsPlaying() then
        self.PlayerInProx = false
        return
    end

    self:UpdatePlayerProximity()

    if not self.PlayerInProx or not GameActions.MinePressed() then
        return
    end

    if not self.NoteNode then
        Log.Warning("NoteRockToDestroy: missing NoteNode")
        return
    end

    if self.NoteNode:IsDestroyed() or self.NoteNode:IsPendingDestroy() then
        Log.Warning("NoteRockToDestroy: NoteNode is no longer valid; removing rock")
        self:DestroyDeferred()
        return
    end

    local world = self:GetWorld()
    if not world then
        return
    end

    self.hitsRemaining = self.hitsRemaining - 1

    if self.hitsRemaining > 0 then
        self:PlayHitFeedback()
        self:SpawnParticleBurst(self.hitParticle, self:GetWorldPosition())
        SignalBus.Emit(Events.RUNE_MINED, self.hitsRemaining)
        return
    end

    self.revealed = true
    self.NoteNode:Attach(world:GetRootNode(), true)
    self:SnapNoteAboveSurface()
    self.NoteNode:SetActive(true)
    self.NoteNode:SetVisible(true)
    self.NoteNode:AddTag("RevealedRune")

    local revealTag = "RevealedBy_" .. self:GetName()
    self.NoteNode:AddTag(revealTag)

    self:SpawnParticleBurst(self.hitParticle, self:GetWorldPosition())
    self:SpawnParticleBurst(self.revealParticle, self.NoteNode:GetWorldPosition())
    SignalBus.Emit(Events.RUNE_MINED, 0)
    SignalBus.Emit(Events.RUNE_REVEALED, self.NoteNode:GetName(), self.RuneArt, revealTag)

    if self.RevealSound then
        Audio.StopSounds(self.RevealSound)
        Audio.PlaySound2D(self.RevealSound, self.RevealVolume, 1.0)
    end

    self:Hide(true)
end

function NoteRockToDestroy:CancelMoveTween()
    if self.moveTween then
        Tween.Cancel(self.moveTween)
        self.moveTween = nil
    end
end

function NoteRockToDestroy:Hide(fast)
    self:CancelMoveTween()
    SetCollisionRecursive(self, false)

    local duration = 1.0
    if fast then
        duration = 0.24
    end

    self.moveTween = Tween.Position(self, Easing.OutExpo, self.hiddenPos, duration, function()
        self.moveTween = nil
        self:SetActive(false)
        self:SetVisible(false)
    end)
end

function NoteRockToDestroy:Show()
    self.revealed = false
    self:CancelMoveTween()
    SetCollisionRecursive(self, true)
    self:SetActive(true)
    self:SetVisible(true)
    self.moveTween = Tween.Position(self, Easing.OutExpo, self.showPos, 1.0, function()
        self.moveTween = nil
    end)
end

function NoteRockToDestroy:SetPhaseVisible(show, instant)
    if self.revealed then
        return
    end

    if self.phaseVisible == show and not instant then
        return
    end

    self.phaseVisible = show
    if show then
        if instant then
            self:CancelMoveTween()
            SetCollisionRecursive(self, true)
            self:SetPosition(self.showPos)
            self:SetActive(true)
            self:SetVisible(true)
        else
            self:Show()
        end
    else
        self.PlayerInProx = false
        if instant then
            self:CancelMoveTween()
            SetCollisionRecursive(self, false)
            self:SetPosition(self.hiddenPos)
            self:SetActive(false)
            self:SetVisible(false)
        else
            self:Hide(true)
        end
    end
end

function NoteRockToDestroy:OnDayNightChanged(isDay)
    if self.revealed then
        return
    end

    local show = PhaseVisibility.ShouldShow(self.isNightStone, isDay)
    self:SetPhaseVisible(show, false)
end

function NoteRockToDestroy:Stop()
    if self.punchTween then
        Tween.Cancel(self.punchTween)
        self.punchTween = nil
    end
    self:CancelMoveTween()

    if self.subscribedDayNight then
        SignalBus.Unsubscribe(Events.DAY_NIGHT_CHANGED, self)
        self.subscribedDayNight = false
    end

    self.PlayerInProx = false
end
