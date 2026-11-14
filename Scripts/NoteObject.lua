NoteObject = {}

function NoteObject:Create()
    if self.NodeType == nil then self.NodeType = 0 end
    self.PlayerInProx = false
end

function NoteObject:GatherProperties()
    return {
        { name = "NodeType", type = DatumType.Integer },
    }
end

function NoteObject:Tick(deltaTime)
    if (self.PlayerInProx) then
        if (Input.IsKeyPressed(Key.E) or Input.IsGamepadPressed(Gamepad.A)) then
            local cam = self:GetWorld():GetActiveCamera()
            self.PlayerInProx = false
            self:EnableOverlaps(false)
            local startPos = self:GetWorldPosition()
            Tween.Value(Easing.OutExpo, 0.0, 1.0, 0.36, function(value, pct, finished)
                local lerped = Vector.Lerp(startPos, cam:GetWorldPosition(), value)
                self:SetWorldPosition(lerped)
                if (finished) then
                    SignalBus.Emit("NoteCollected", self.NodeType)
                    Node.Destruct(self)
                end
            end)
        end
    end
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
