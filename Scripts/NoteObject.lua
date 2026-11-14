NoteObject = {}

function NoteObject:Create()
    if self.NodeType == nil then self.NodeType = 0 end
    self.PlayerInProx = false
    self.collecting = false
    self.tweenID = nil
    self.subscribed = false
end

function NoteObject:GatherProperties()
    return {
        { name = "NodeType", type = DatumType.Integer },
    }
end

function NoteObject:Start()
    self.PlayerInProx = false
    self.collecting = false

    if self.subscribed then
        SignalBus.Unsubscribe("ShakeDetected", self)
    end
    SignalBus.Subscribe("ShakeDetected", self, NoteObject.OnShakeDetected)
    self.subscribed = true
end

function NoteObject:OnShakeDetected(intensity)
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
            SignalBus.Emit("NoteCollected", self.NodeType)
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

    self.PlayerInProx = false
    self.collecting = false
end
