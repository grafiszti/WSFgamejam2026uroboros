Script.Load("Core/GameSession")

StartingScreen = {}

local IMAGE_NODE = "StartImage"
local NEXT_SCENE = "SC_Default"
local INTRO_SOUND = "Nintrendo-Roibos-SFX"

function StartingScreen:Create()
    self.FadeInDuration = 2.0
    self.StartSound = nil
    self.StartVolume = 1.0

    self.phase = "in"
    self.timer = 0.0
    self.image = nil
    self.world = nil
    self.loaded = false
    self.touchWasDown = false
end

function StartingScreen:GatherProperties()
    return {
        { name = "FadeInDuration", type = DatumType.Float },
        { name = "StartSound", type = DatumType.Asset },
        { name = "StartVolume", type = DatumType.Float },
    }
end

function StartingScreen:Start()
    self.FadeInDuration = math.max(0.0, self.FadeInDuration or 2.0)
    self.StartVolume = math.max(0.0, self.StartVolume or 1.0)

    self.phase = "in"
    self.timer = 0.0
    self.loaded = false
    self.touchWasDown = false
    self.world = self:GetWorld()
    GameSession.SetPhase(GameSession.PHASE_INTRO)

    Renderer.EnableConsole(false)

    if self.StartSound == nil then
        self.StartSound = LoadAsset(INTRO_SOUND)
    end

    if self.StartSound then
        Audio.PlaySound2D(self.StartSound, self.StartVolume, 1.0)
    else
        Log.Warning("StartingScreen: missing sound " .. INTRO_SOUND)
    end

    self.image = self:FindChild(IMAGE_NODE)
    if self.image == nil then
        Log.Warning("StartingScreen: missing image node " .. IMAGE_NODE)
    else
        self.image:SetVisible(true)
        self.image:SetOpacityFloat(0.0)
    end
end

function StartingScreen:Tick(deltaTime)
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
            self.phase = "wait"
            self.timer = 0.0
        end
        return
    end

    local touchDown = Input.IsTouchDown(1)
    local tapped = Input.IsPointerPressed(1) or (touchDown and not self.touchWasDown)
    self.touchWasDown = touchDown

    if tapped then
        self.loaded = true
        if self.StartSound then
            Audio.StopSounds(self.StartSound)
        end
        if self.world then
            self.world:LoadScene(NEXT_SCENE, false)
        else
            Log.Warning("StartingScreen: no world, cannot load " .. NEXT_SCENE)
        end
    end
end

function StartingScreen:Stop()
    if self.StartSound then
        Audio.StopSounds(self.StartSound)
    end

    self.image = nil
    self.world = nil
    self.loaded = true
end
