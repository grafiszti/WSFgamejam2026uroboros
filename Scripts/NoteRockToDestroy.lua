NoteRockToDestroy = {}

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

    if suffix and (suffix:match("^Dur[1-6]$") or suffix:match("^Mol[1-4]$")) then
        return "Tile - " .. suffix
    end
    return ""
end

function NoteRockToDestroy:Create()
    self.NoteNode = nil
    self.PlayerInProx = false
    self.HitsRequired = 1
    self.RuneArt = ""
    self.hitsRemaining = 1
    self.baseScale = nil
    self.punchTween = nil
    self.hiddenPos = Vec()
    self.showPos = Vec()
    self.revealed = false
end

function NoteRockToDestroy:GatherProperties()
    return {
        { name = "NoteNode", type = DatumType.Node },
        { name = "HitsRequired", type = DatumType.Integer },
        { name = "RuneArt", type = DatumType.String },
    }
end

function NoteRockToDestroy:Start()
    self.hitsRemaining = math.max(1, math.floor(self.HitsRequired or 1))
    self.baseScale = self:GetScale()
    self.punchTween = nil
    self.revealed = false

    if self.RuneArt == nil or self.RuneArt == "" then
        self.RuneArt = DeriveRuneArt(self:GetName())
    end

    self.showPos = self:GetPosition()
    self.hiddenPos = self.showPos - self:GetUpVector() * 2.0
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
    if self.revealed then
        return
    end

    if (self.PlayerInProx) then
        if (Input.IsKeyPressed(Key.E) or Input.IsGamepadPressed(Gamepad.A)) then
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
