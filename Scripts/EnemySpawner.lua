EnemySpawner = {}

function EnemySpawner:Create()
    self.EnemyScene = nil
    self.EnemyCount = 1
    self.SpawnForward = 6.0
    self.SpawnHeight = 4.0
end

function EnemySpawner:GatherProperties()
    return {
        { name = "EnemyScene", type = DatumType.Asset },
        { name = "EnemyCount", type = DatumType.Integer },
        { name = "SpawnForward", type = DatumType.Float },
        { name = "SpawnHeight", type = DatumType.Float },
    }
end

function EnemySpawner:Start()
    self.EnemyCount = math.max(1, math.floor(self.EnemyCount or 1))
    self.SpawnForward = self.SpawnForward or 6.0
    self.SpawnHeight = self.SpawnHeight or 4.0

    local world = self:GetWorld()
    if not world then
        Log.Warning("EnemySpawner: no world")
        return
    end

    local scene = self.EnemyScene
    if not scene then
        scene = LoadAsset("SC_Enemy")
    end
    if not scene then
        Log.Warning("EnemySpawner: missing SC_Enemy scene")
        return
    end

    local player = world:FindNode("ThirdPersonPlayer")
    local basePos = Vec(0, 10, 0)
    local forward = Vec(0, 0, -1)
    local up = Vec(0, 1, 0)
    local rotation = Vec(0, 0, 0)

    if player then
        basePos = player:GetWorldPosition()
        forward = player:GetForwardVector()
        up = player:GetUpVector()
        rotation = player:GetWorldRotation()
    end

    for i = 1, self.EnemyCount do
        local offset = forward * (self.SpawnForward + (i - 1) * 2.0)
        local spawnPos = basePos + offset + up * self.SpawnHeight
        local root = world:SpawnScene(scene, spawnPos)
        if root then
            root:SetWorldRotation(rotation)
        else
            Log.Warning("EnemySpawner: failed to spawn SC_Enemy")
        end
    end
end
