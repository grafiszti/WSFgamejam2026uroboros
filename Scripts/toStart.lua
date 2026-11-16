toStart = {}

function toStart:Create()
end

function toStart:OnActivated()
    local world = Engine.GetWorld(1)
    world:LoadScene("SC_Default")
end

