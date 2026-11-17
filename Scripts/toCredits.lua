toCredits = {}

function toCredits:Create()
end

function toCredits:OnActivated()
    local world = Engine.GetWorld(1)
    world:LoadScene("Credits")
end

