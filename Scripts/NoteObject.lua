NoteObject = {}

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
    if art ~= "" then
        self.isNightRune = art:find("Mol", 1, true) ~= nil
    else
        self.isNightRune = self:GetName():find("Mol", 1, true) ~= nil
    end
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
        self.RuneArt = DeriveRuneArt(self:GetName())
    end

    self:UpdateNightRune()
    if DayNightCycle and DayNightCycle.isDay ~= nil then
        self.isDay = DayNightCycle.isDay
    end

    if self.subscribed then
        SignalBus.Unsubscribe("ShakeDetected", self)
    end
    SignalBus.Subscribe("ShakeDetected", self, NoteObject.OnShakeDetected)
    self.subscribed = true

    if self.subscribedReveal then
        SignalBus.Unsubscribe("RuneRevealed", self)
    end
    SignalBus.Subscribe("RuneRevealed", self, NoteObject.OnRuneRevealed)
    self.subscribedReveal = true

    if self.subscribedDayNight then
        SignalBus.Unsubscribe("DayNightChanged", self)
    end
    SignalBus.Subscribe("DayNightChanged", self, NoteObject.OnDayNightChanged)
    self.subscribedDayNight = true
end

function NoteObject:OnRuneRevealed(noteName, runeArt)
    if noteName ~= self:GetName() or not self:HasTag("RevealedRune") then
        return
    end

    if runeArt and runeArt ~= "" then
        self.RuneArt = runeArt
    end

    self.revealed = true
    self:UpdateNightRune()
    if DayNightCycle and DayNightCycle.isDay ~= nil then
        self.isDay = DayNightCycle.isDay
    end
    self:ApplyPhaseVisibility(self.isDay)
end

function NoteObject:ApplyPhaseVisibility(isDay)
    if not self.revealed or self.collecting then
        return
    end

    local show = (self.isNightRune and not isDay) or (not self.isNightRune and isDay)
    self.phaseVisible = show
    self:SetVisible(show)
end

function NoteObject:OnDayNightChanged(isDay)
    self.isDay = isDay
    self:ApplyPhaseVisibility(isDay)
end

function NoteObject:Tick(deltaTime)
    if self.collecting or not self.revealed then
        self.PlayerInProx = false
        return
    end

    if not self.player then
        self.PlayerInProx = false
        return
    end

    local notePos = self:GetWorldPosition()
    local playerPos = self.player:GetWorldPosition()
    local dx = notePos.x - playerPos.x
    local dy = notePos.y - playerPos.y
    local dz = notePos.z - playerPos.z
    self.PlayerInProx = (dx * dx + dy * dy + dz * dz) <= self.proximityRadiusSq
end

function NoteObject:OnShakeDetected(intensity)
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
        if (finished) then
            self.tweenID = nil
            SignalBus.Emit("NoteCollected", self.NodeType, self.RuneArt)
            self:DestroyDeferred()
        end
    end)
end

function NoteObject:BeginOverlap(me, other)
    if (other:HasTag("Controller")) then
        self.PlayerInProx = true
    end
end

function NoteObject:EndOverlap(me, other)
    if (other:HasTag("Controller")) then
        self.PlayerInProx = false
    end
end

function NoteObject:Stop()
    if self.tweenID then
        Tween.Cancel(self.tweenID)
        self.tweenID = nil
    end

    if self.subscribed then
        SignalBus.Unsubscribe("ShakeDetected", self)
        self.subscribed = false
    end

    if self.subscribedReveal then
        SignalBus.Unsubscribe("RuneRevealed", self)
        self.subscribedReveal = false
    end

    if self.subscribedDayNight then
        SignalBus.Unsubscribe("DayNightChanged", self)
        self.subscribedDayNight = false
    end

    self.PlayerInProx = false
    self.collecting = false
    self.player = nil
end
