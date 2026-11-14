NoteRockToDestroy = {}

function NoteRockToDestroy:Create()
    self.NoteNode = nil
    self.PlayerInProx = false
    self.HitsRequired = 1
    self.hitsRemaining = 1
    self.baseScale = nil
    self.punchTween = nil
end

function NoteRockToDestroy:GatherProperties()
    return {
        { name = "NoteNode", type = DatumType.Node },
        { name = "HitsRequired", type = DatumType.Integer },
    }
end

function NoteRockToDestroy:Start()
    self.hitsRemaining = math.max(1, math.floor(self.HitsRequired or 1))
    self.baseScale = self:GetScale()
    self.punchTween = nil
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

function NoteRockToDestroy:Tick(deltaTime)
    if (self.PlayerInProx) then
        if (Input.IsKeyPressed(Key.E) or Input.IsGamepadPressed(Gamepad.A)) then
            if not self.NoteNode then
                Log.Warning("NoteRockToDestroy: missing NoteNode")
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

            self.NoteNode:Attach(world:GetRootNode(), true)
            self.NoteNode:SetActive(true)
            self.NoteNode:SetVisible(true)
            self.NoteNode:Start()
            SignalBus.Emit("RuneMined", 0)
            SignalBus.Emit("RuneRevealed", self.NoteNode)
            self:DestroyDeferred()
        end
    end
end

function NoteRockToDestroy:BeginOverlap(me, other)
    if (other:HasTag("Controller")) then
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

    self.PlayerInProx = false
end
