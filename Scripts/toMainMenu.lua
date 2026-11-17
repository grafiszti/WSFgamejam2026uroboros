toMainMenu = {}

function toMainMenu:Create()
end

function toMainMenu:OnActivated()
    local world = Engine.GetWorld(1)
    world:LoadScene("StartMenu")
end

