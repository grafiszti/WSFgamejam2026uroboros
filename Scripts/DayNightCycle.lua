DayNightCycle = {}

DayNightCycle.isDay = true

local DAY_LIGHT = "DirectionalLight"
local DAY_BACKGROUND = "SM_Background_Day"
local NIGHT_BACKGROUND = "SM_Background"
local NIGHT_LIGHT = "DirectionalLight_Night"
local DAY_FRAME = "Frame_Day"
local NIGHT_FRAME = "Frame_Night"

function DayNightCycle:Create()
    self.DayDuration = 20.0
    self.NightDuration = 20.0
    self.DayAmbientColor = Vec(0.55, 0.52, 0.58, 1.0)
    self.NightAmbientColor = Vec(0.4015, 0.3061, 0.4931, 1.0)

    self.elapsed = 0.0
    self.isDay = true
    self.emitted = false
    self.world = nil
    self.dayLight = nil
    self.nightLight = nil
    self.dayBackground = nil
    self.nightBackground = nil
    self.dayFrame = nil
    self.nightFrame = nil
    self.dayLightIntensity = 1.0
    self.nightLightIntensity = 1.5
end

function DayNightCycle:GatherProperties()
    return {
        { name = "DayDuration", type = DatumType.Float },
        { name = "NightDuration", type = DatumType.Float },
        { name = "DayAmbientColor", type = DatumType.Color },
        { name = "NightAmbientColor", type = DatumType.Color },
    }
end

function DayNightCycle:Start()
    self.DayDuration = math.max(0.1, self.DayDuration or 20.0)
    self.NightDuration = math.max(0.1, self.NightDuration or 20.0)

    self.elapsed = 0.0
    self.isDay = true
    self.emitted = false
    DayNightCycle.isDay = true

    self.dayLight = nil
    self.nightLight = nil
    self.dayBackground = nil
    self.nightBackground = nil
    self.dayFrame = nil
    self.nightFrame = nil
    self.world = self:GetWorld()

    if self.world then
        self.dayLight = self.world:FindNode(DAY_LIGHT)
        self.nightLight = self.world:FindNode(NIGHT_LIGHT)
        self.dayBackground = self.world:FindNode(DAY_BACKGROUND)
        self.nightBackground = self.world:FindNode(NIGHT_BACKGROUND)
        self.dayFrame = self.world:FindNode(DAY_FRAME)
        self.nightFrame = self.world:FindNode(NIGHT_FRAME)
    end

    if self.dayLight then
        self.dayLightIntensity = self.dayLight:GetIntensity()
    else
        Log.Warning("DayNightCycle: missing light " .. DAY_LIGHT)
    end

    if self.nightLight then
        self.nightLightIntensity = self.nightLight:GetIntensity()
    else
        Log.Warning("DayNightCycle: missing light " .. NIGHT_LIGHT)
    end

    if not self.dayBackground then
        Log.Warning("DayNightCycle: missing background " .. DAY_BACKGROUND)
    end

    if not self.nightBackground then
        Log.Warning("DayNightCycle: missing background " .. NIGHT_BACKGROUND)
    end

    if not self.dayFrame then
        Log.Warning("DayNightCycle: missing frame " .. DAY_FRAME)
    end

    if not self.nightFrame then
        Log.Warning("DayNightCycle: missing frame " .. NIGHT_FRAME)
    end

    self:EnableLateTick(true)
    self:ApplyState()
end

function DayNightCycle:ApplyState()
    if self.dayLight then
        self.dayLight:SetActive(self.isDay)
        self.dayLight:SetVisible(self.isDay)
        self.dayLight:SetIntensity(self.isDay and self.dayLightIntensity or 0.0)
    end

    if self.nightLight then
        self.nightLight:SetActive(not self.isDay)
        self.nightLight:SetVisible(not self.isDay)
        self.nightLight:SetIntensity(self.isDay and 0.0 or self.nightLightIntensity)
    end

    if self.dayBackground then
        self.dayBackground:SetActive(self.isDay)
        self.dayBackground:SetVisible(self.isDay)
    end

    if self.nightBackground then
        self.nightBackground:SetActive(not self.isDay)
        self.nightBackground:SetVisible(not self.isDay)
    end

    if self.dayFrame then
        self.dayFrame:SetActive(self.isDay)
        self.dayFrame:SetVisible(self.isDay)
    end

    if self.nightFrame then
        self.nightFrame:SetActive(not self.isDay)
        self.nightFrame:SetVisible(not self.isDay)
    end

    if self.world then
        self.world:SetAmbientLightColor(self.isDay and self.DayAmbientColor or self.NightAmbientColor)
    end
end

function DayNightCycle:Tick(deltaTime)
    local dt = math.min(deltaTime, 0.5)
    if dt <= 0.0 then
        return
    end

    local total = self.DayDuration + self.NightDuration
    self.elapsed = (self.elapsed + dt) % total

    local wasDay = self.isDay
    self.isDay = self.elapsed < self.DayDuration
    DayNightCycle.isDay = self.isDay

    if self.nightLight and self.dayLight then
        self.nightLight:SetRotation(self.dayLight:GetRotation())
    end

    local changed = self.isDay ~= wasDay
    if changed then
        self:ApplyState()
    end

    if changed or not self.emitted then
        self.emitted = true
        SignalBus.Emit("DayNightChanged", self.isDay)
    end
end

function DayNightCycle:Stop()
    DayNightCycle.isDay = true
end
