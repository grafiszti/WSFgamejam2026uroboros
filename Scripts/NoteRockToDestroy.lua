NoteRockToDestroy = {}

function NoteRockToDestroy:Create()
    self.NoteNode = nil
    self.PlayerInProx = false;
end

function NoteRockToDestroy:GatherProperties()
    return {
        { name = "NoteNode", type = DatumType.Node },
    }
end

function NoteRockToDestroy:Tick(deltaTime)
    if (self.PlayerInProx) then
        if (Input.IsKeyPressed(Key.E) or Input.IsGamepadPressed(Gamepad.A)) then
            if self.NoteNode then
                self.NoteNode:Attach(self.world:GetRootNode(), true)
                self.NoteNode:SetActive(true)
                self.NoteNode:SetVisible(true)
            end
            Node.Destruct(self)
        end
    end
end

function NoteRockToDestroy:Destroy()

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
