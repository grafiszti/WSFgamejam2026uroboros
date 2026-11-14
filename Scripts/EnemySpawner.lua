EnemySpawner = {}

function EnemySpawner:Create()
    self.EnemyScene = nil
    self.EnemyCount = 3
    self.SpawnForward = 4.0
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
    self.EnemyCount = math.max(1, math.floor(self.EnemyCount or 3))
    self.SpawnForward = math.max(0.5, self.SpawnForward or 4.0)
    self.SpawnHeight = math.max(0.5, self.SpawnHeight or 4.0)

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
    local right = Vec(1, 0, 0)
    local up = Vec(0, 1, 0)
    local rotation = Vec(0, 0, 0)

    if player then
        basePos = player:GetWorldPosition()
        forward = player:GetForwardVector()
        right = player:GetRightVector()
        up = player:GetUpVector()
        rotation = player:GetWorldRotation()
    end

    local step = 6.2831853 / self.EnemyCount
    for i = 1, self.EnemyCount, 1 do
        local angle = (i - 1) * step
        local direction = forward * math.cos(angle) + right * math.sin(angle)
        local spawnPos = basePos + direction * self.SpawnForward + up * self.SpawnHeight
        local root = world:SpawnScene(scene, spawnPos)
        if root then
            root:SetWorldRotation(rotation)
        else
            Log.Warning("EnemySpawner: failed to spawn SC_Enemy")
        end
    end
end
