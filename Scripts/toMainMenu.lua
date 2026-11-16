toMainMenu = {}

function toMainMenu:Create()
end

function toMainMenu:OnActivated()
    local world = Engine.GetWorld(2)
    world:LoadScene("StartScene")
end

