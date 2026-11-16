toCredits = {}

function toCredits:Create()
end

function toCredits:OnActivated()
    local world = Engine.GetWorld(2)
    world:LoadScene("creditsScene")
end

