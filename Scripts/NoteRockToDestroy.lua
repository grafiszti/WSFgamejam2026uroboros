NoteRockToDestroy = {}

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

            local world = self:GetWorld()
            if not world then
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
