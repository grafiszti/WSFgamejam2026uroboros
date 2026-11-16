ClickSparkEffect = {}

local CLICK_SPARK_COUNT = 6
local CLICK_SPARK_TEXTURE = "Particle"
local CLICK_SPARK_SIZE = 8.0
local CLICK_SPARK_LIFETIME = 0.35
local CLICK_SPARK_SPEED = 90.0
local CLICK_SPARK_DAMPING = 6.0
local CLICK_SPARK_COLOR = Vec(1.0, 1.0, 1.0, 1.0)
local CLICK_SPARK_FALLBACK_COLOR = Vec(1.0, 0.82, 0.28, 1.0)
local CLICK_SPARK_DIRECTIONS =
{
    {  1.0,  0.0 },
    {  0.5, -0.866 },
    { -0.5, -0.866 },
    { -1.0,  0.0 },
    { -0.5,  0.866 },
    {  0.5,  0.866 },
}

local function LoadTextureAsset(name)
    if not name or name == "" then
        return nil
    end

    local asset = LoadAsset(name)
    if asset and asset.GetTypeName and asset:GetTypeName() == "Texture" then
        return asset
    end

    return nil
end

function ClickSparkEffect.Init(ui)
    ui.sparkTexture = LoadTextureAsset(CLICK_SPARK_TEXTURE)
    if ui.sparkTexture == nil then
        Log.Warning("BottomScreenUI: missing spark texture " .. CLICK_SPARK_TEXTURE)
    end

    ui.clickSparks = {}
    for i = 1, CLICK_SPARK_COUNT do
        local name = "ClickSpark_" .. tostring(i)
        local node = ui.canvas and ui.canvas:FindChild(name) or nil
        if node == nil and ui.canvas then
            node = ui.canvas:CreateChild("Quad")
            if node then
                node:SetName(name)
            end
        end

        if node then
            node:SetDimensions(CLICK_SPARK_SIZE, CLICK_SPARK_SIZE)
            node:SetTexture(ui.sparkTexture)
            if ui.sparkTexture then
                node:SetColor(CLICK_SPARK_COLOR)
            else
                node:SetColor(CLICK_SPARK_FALLBACK_COLOR)
            end
            node:SetOpacityFloat(1.0)
            node:SetVisible(false)
            ui.clickSparks[#ui.clickSparks + 1] =
            {
                node = node,
                x = 0.0,
                y = 0.0,
                vx = 0.0,
                vy = 0.0,
                life = 0.0,
                active = false,
            }
        end
    end
end

function ClickSparkEffect.Spawn(ui, x, y)
    if #ui.clickSparks == 0 then
        return
    end

    local localX = x - ui.canvasX
    local localY = y - ui.canvasY

    for i = 1, #ui.clickSparks do
        local spark = ui.clickSparks[i]
        local direction = CLICK_SPARK_DIRECTIONS[i]
        if direction then
            spark.active = true
            spark.life = CLICK_SPARK_LIFETIME
            spark.x = localX
            spark.y = localY
            spark.vx = direction[1] * CLICK_SPARK_SPEED
            spark.vy = direction[2] * CLICK_SPARK_SPEED
            spark.node:SetDimensions(CLICK_SPARK_SIZE, CLICK_SPARK_SIZE)
            spark.node:SetPosition(localX - CLICK_SPARK_SIZE * 0.5,
                localY - CLICK_SPARK_SIZE * 0.5)
            spark.node:SetOpacityFloat(1.0)
            spark.node:SetVisible(true)
        end
    end
end

function ClickSparkEffect.Update(ui, dt)
    if dt <= 0.0 then
        return
    end

    for i = 1, #ui.clickSparks do
        local spark = ui.clickSparks[i]
        if spark.active then
            spark.life = spark.life - dt
            if spark.life <= 0.0 then
                spark.active = false
                spark.node:SetVisible(false)
            else
                local damping = 1.0 - CLICK_SPARK_DAMPING * dt
                if damping < 0.0 then
                    damping = 0.0
                end

                spark.vx = spark.vx * damping
                spark.vy = spark.vy * damping
                spark.x = spark.x + spark.vx * dt
                spark.y = spark.y + spark.vy * dt

                local t = spark.life / CLICK_SPARK_LIFETIME
                local size = CLICK_SPARK_SIZE * (0.5 + 0.5 * t)
                spark.node:SetDimensions(size, size)
                spark.node:SetPosition(spark.x - size * 0.5, spark.y - size * 0.5)
                spark.node:SetOpacityFloat(t)
            end
        end
    end
end

function ClickSparkEffect.Stop(ui)
    for i = 1, #ui.clickSparks do
        local spark = ui.clickSparks[i]
        spark.active = false
        if spark.node then
            spark.node:SetVisible(false)
        end
    end
    ui.clickSparks = {}
    ui.sparkTexture = nil
end
