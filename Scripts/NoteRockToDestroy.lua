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
    self.hiddenPos = self:GetPosition() - self:GetUpVector() * 2;
    self.showPos = self:GetPosition()
end

function NoteRockToDestroy:GatherProperties()
    return {
        { name = "NoteNode", type = DatumType.Node },
    }
end

function NoteRockToDestroy:Tick(deltaTime)
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

            self.NoteNode:Attach(world:GetRootNode(), true)
            self.NoteNode:SetActive(true)
            self.NoteNode:SetVisible(true)
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
    Tween.Position(self, Easing.OutExpo, self.showPos, 1, function()
        self:SetActive(false)
        self:SetVisible(false)
    end)
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
