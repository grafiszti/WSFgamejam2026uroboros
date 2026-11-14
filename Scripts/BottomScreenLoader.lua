BottomScreenLoader = {}

local SCENE_NAME = "SC_BottomUI"
local ROOT_NAME = "SC_BottomUI_Root"

function BottomScreenLoader:Create()
    self.sceneName = SCENE_NAME
    self.pending = false
    self.pendingFrames = 0
end

function BottomScreenLoader:GatherProperties()
    return
    {
        { name = "sceneName", type = DatumType.String },
    }
end

function BottomScreenLoader:Start()
    self.pending = false
    self.pendingFrames = 0

    local sceneName = self.sceneName
    if sceneName == nil or sceneName == "" then
        sceneName = SCENE_NAME
        self.sceneName = sceneName
    end

    if Engine.GetPlatform() == "3DS" then
        local bottomWorld = Engine.GetWorld(2)
        if bottomWorld == nil then
            Log.Warning("BottomScreenLoader: Engine.GetWorld(2) unavailable")
            return
        end

        if bottomWorld:FindNode(ROOT_NAME) ~= nil or bottomWorld:GetLoadedSceneName() == sceneName then
            self.pending = true
            self.pendingFrames = 5
            return
        end

        if LoadAsset(sceneName) == nil then
            Log.Warning("BottomScreenLoader: missing scene asset " .. sceneName)
            return
        end

        bottomWorld:LoadScene(sceneName)
        self.pending = true
        self.pendingFrames = 30
        return
    end

    if not Engine.IsEditor() then
        return
    end

    local world = self:GetWorld()
    if world == nil then
        Log.Warning("BottomScreenLoader: could not resolve world")
        return
    end

    if world:FindNode(ROOT_NAME) ~= nil then
        return
    end

    local scene = LoadAsset(sceneName)
    if scene == nil then
        Log.Warning("BottomScreenLoader: missing scene asset " .. sceneName)
        return
    end

    local root = world:SpawnScene(scene)
    if root == nil then
        Log.Warning("BottomScreenLoader: failed to spawn " .. sceneName)
        return
    end

    root:SetTargetScreen(TargetScreen.Bottom)
end

function BottomScreenLoader:Tick(deltaTime)
    if not self.pending then
        return
    end

    local bottomWorld = Engine.GetWorld(2)
    if bottomWorld == nil then
        return
    end

    local root = bottomWorld:FindNode(ROOT_NAME)
    if root == nil then
        self.pendingFrames = self.pendingFrames - 1
        if self.pendingFrames <= 0 then
            Log.Warning("BottomScreenLoader: SC_BottomUI did not load into world 2")
            self.pending = false
        end
        return
    end

    local canvas = root:FindChild("BottomScreenCanvas")
    if canvas ~= nil then
        canvas:SetTargetScreen(TargetScreen.Bottom)
    else
        Log.Warning("BottomScreenLoader: SC_BottomUI is missing BottomScreenCanvas")
    end

    self.pending = false
end
