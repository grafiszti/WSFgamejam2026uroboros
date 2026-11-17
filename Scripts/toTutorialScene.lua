toTutorialScene = {}

function toTutorialScene:Create()
end

function toTutorialScene:OnActivated()
    local world = Engine.GetWorld(1)
    world:LoadScene("Tutorial")
end

