toTutorialScene = {}

function toTutorialScene:Create()
end

function toTutorialScene:OnActivated()
    local world = Engine.GetWorld(2)
    world:LoadScene("tutorialScene")
end

