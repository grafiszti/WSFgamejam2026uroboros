TitleScreen = {}

local IMAGE_NODE = "TitleImage"
local NEXT_SCENE = "SC_Starting"

function TitleScreen:Create()
    self.FadeInDuration = 2.0
    self.FadeOutDuration = 2.0

    self.phase = "in"
    self.timer = 0.0
    self.image = nil
    self.world = nil
    self.loaded = false
end

function TitleScreen:GatherProperties()
    return {
        { name = "FadeInDuration", type = DatumType.Float },
        { name = "FadeOutDuration", type = DatumType.Float },
    }
end

function TitleScreen:Start()
    self.FadeInDuration = math.max(0.0, self.FadeInDuration or 2.0)
    self.FadeOutDuration = math.max(0.0, self.FadeOutDuration or 2.0)

    self.phase = "in"
    self.timer = 0.0
    self.loaded = false
    self.world = self:GetWorld()

    Renderer.EnableConsole(false)

    self.image = self:FindChild(IMAGE_NODE)
    if self.image == nil then
        Log.Warning("TitleScreen: missing image node " .. IMAGE_NODE)
    else
        self.image:SetVisible(true)
        self.image:SetOpacityFloat(0.0)
    end
end

function TitleScreen:Tick(deltaTime)
    if self.loaded then
        return
    end

    local dt = math.min(deltaTime, 0.05)
    self.timer = self.timer + dt

    if self.phase == "in" then
        local t = 1.0
        if self.FadeInDuration > 0.0 then
            t = math.min(1.0, self.timer / self.FadeInDuration)
        end
        if self.image then
            self.image:SetOpacityFloat(t)
        end

        if self.timer >= self.FadeInDuration then
            self.phase = "out"
            self.timer = 0.0
        end
    elseif self.phase == "out" then
        local t = 1.0
        if self.FadeOutDuration > 0.0 then
            t = math.min(1.0, self.timer / self.FadeOutDuration)
        end
        if self.image then
            self.image:SetOpacityFloat(1.0 - t)
        end

        if self.timer >= self.FadeOutDuration then
            self.loaded = true
            if self.world then
                self.world:LoadScene(NEXT_SCENE, false)
            else
                Log.Warning("TitleScreen: no world, cannot load " .. NEXT_SCENE)
            end
        end
    end
end
