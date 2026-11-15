NoteRockToDestroy = {}

local STONE_COLLISION_GROUP = 8

local function ApplyStoneCollisionGroup(node)
    if node == nil then
        return
    end

    if node:IsA("Primitive3D") then
        node:SetCollisionGroup(STONE_COLLISION_GROUP)
        node:EnableOverlaps(false)
    end

    local childCount = node:GetNumChildren()
    for i = 1, childCount do
        ApplyStoneCollisionGroup(node:GetChild(i))
    end
end

local function DeriveRuneArt(nodeName)
    if nodeName == nil then
        return ""
    end

    local suffix = nil
    if nodeName:sub(1, 4) == "Rock" then
        suffix = nodeName:sub(5)
    elseif nodeName:sub(1, 3) == "SM_" then
        local candidate = nodeName:sub(4)
        if candidate:sub(1, 7) == "Tile - " then
            suffix = candidate:sub(8)
        end
    end

    if suffix then
        local base = suffix:match("^(Dur[1-6])") or suffix:match("^(Mol[1-4])")
        if base then
            return "Tile - " .. base
        end
    end
    return ""
end

function NoteRockToDestroy:Create()
    self.NoteNode = nil
    self.PlayerInProx = false
    local myPos = self:GetWorldPosition()
    myPos.y = 0
    myPos.z = 0
    self.hiddenPos = self:GetPosition() + (myPos - self:GetWorldPosition()):Normalize3() * 2;
    self.showPos = self:GetPosition()
    self.HitsRequired = 1
    self.ProximityRadius = 3.5
    self.RuneArt = ""
    self.proximityRadiusSq = 12.25
    self.player = nil
    self.hitsRemaining = 1
    self.baseScale = nil
    self.punchTween = nil
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
        { name = "RuneArt",        type = DatumType.String },
    }
end

function NoteRockToDestroy:Start()
    ApplyStoneCollisionGroup(self)

    self.hitsRemaining = math.max(1, math.floor(self.HitsRequired or 1))
    self.ProximityRadius = math.max(0.5, self.ProximityRadius or 3.5)
    self.proximityRadiusSq = self.ProximityRadius * self.ProximityRadius
    self.baseScale = self:GetScale()
    self.punchTween = nil
    self.revealed = false

    if self.RuneArt == nil or self.RuneArt == "" then
        self.RuneArt = DeriveRuneArt(self:GetName())
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
    self.hiddenPos = self.showPos - self:GetUpVector() * 2.0

    self.isNightStone = self:GetName():find("Mol", 1, true) ~= nil
    self.phaseVisible = true

    if self.subscribedDayNight then
        SignalBus.Unsubscribe("DayNightChanged", self)
    end
    SignalBus.Subscribe("DayNightChanged", self, NoteRockToDestroy.OnDayNightChanged)
    self.subscribedDayNight = true

    local isDay = true
    if DayNightCycle and DayNightCycle.isDay ~= nil then
        isDay = DayNightCycle.isDay
    end
    local show = (self.isNightStone and not isDay) or (not self.isNightStone and isDay)
    self:SetPhaseVisible(show, true)
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

    local rockPos = self:GetWorldPosition()
    local playerPos = self.player:GetWorldPosition()
    local dx = rockPos.x - playerPos.x
    local dy = rockPos.y - playerPos.y
    local dz = rockPos.z - playerPos.z
    self.PlayerInProx = (dx * dx + dy * dy + dz * dz) <= self.proximityRadiusSq
end

function NoteRockToDestroy:Tick(deltaTime)
    if self.revealed or not self.phaseVisible then
        self.PlayerInProx = false
        return
    end

    self:UpdatePlayerProximity()

    if (self.PlayerInProx) then
        if (Input.IsKeyPressed(Key.E) or Input.IsGamepadPressed(Gamepad.A)) then
            self:Hide()
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
                SignalBus.Emit("RuneMined", self.hitsRemaining)
                return
            end

            self.revealed = true
            self.NoteNode:Attach(world:GetRootNode(), true)
            self.NoteNode:SetActive(true)
            self.NoteNode:SetVisible(true)
            self.NoteNode:Start()
            self.NoteNode:AddTag("RevealedRune")
            SignalBus.Emit("RuneMined", 0)
            SignalBus.Emit("RuneRevealed", self.NoteNode:GetName(), self.RuneArt)
            self:Hide(true)
        end
    end
end

function NoteRockToDestroy:Hide(fast)
    local dur = 1.0
    if (fast) then
        dur = 0.24
    end
    Tween.Position(self, Easing.OutExpo, self.hiddenPos, dur, function()
        self:SetActive(false)
        self:SetVisible(false)
    end)
end

function NoteRockToDestroy:Show()
    self.revealed = false
    self:SetActive(true)
    self:SetVisible(true)
    Tween.Position(self, Easing.OutExpo, self.showPos, 1.0)
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
            self:SetPosition(self.showPos)
            self:SetActive(true)
            self:SetVisible(true)
        else
            self:Show()
        end
    else
        self.PlayerInProx = false
        if instant then
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

    local show = (self.isNightStone and not isDay) or (not self.isNightStone and isDay)
    self:SetPhaseVisible(show, false)
end

function NoteRockToDestroy:BeginOverlap(me, other)
    if (other:HasTag("Controller") and self.phaseVisible) then
        self.PlayerInProx = true
    end
end

function NoteRockToDestroy:EndOverlap(me, other)
    if (other:HasTag("Controller")) then
        self.PlayerInProx = false
    end
end

function NoteRockToDestroy:Stop()
    if self.punchTween then
        Tween.Cancel(self.punchTween)
        self.punchTween = nil
    end

    if self.subscribedDayNight then
        SignalBus.Unsubscribe("DayNightChanged", self)
        self.subscribedDayNight = false
    end

    self.PlayerInProx = false
end
