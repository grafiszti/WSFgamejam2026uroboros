BottomScreenUI = {}

local COLOR_PANEL = Vec(0.10, 0.22, 0.26, 1.0)
local COLOR_PANEL_ACTIVE = Vec(0.18, 0.72, 0.58, 1.0)
local COLOR_TEXT = Vec(0.92, 0.96, 0.95, 1.0)
local COLOR_TEXT_DIM = Vec(0.55, 0.68, 0.66, 1.0)
local COLOR_PANEL_TEXT = Vec(0.04, 0.08, 0.08, 1.0)
local COLOR_STONE = Vec(0.56, 0.52, 0.46, 1.0)
local COLOR_GAUGE_LOW = Vec(0.25, 0.55, 0.55, 1.0)
local COLOR_GAUGE_HIGH = Vec(0.95, 0.78, 0.25, 1.0)

local STATUS_COLLECT = "SHAKE UP TO COLLECT"
local STATUS_DRAG = "DRAG A STONE TO THE BOWL"
local STATUS_FULL = "BOWL FULL"
local STATUS_TRAY_FULL = "TRAY FULL"

local STONE_COUNT = 5
local STONE_SIZE = 44.0
local PLACED_STONE_SIZE = 24.0

local function ResolveCanvas(script)
    local canvas = script:FindChild("BottomScreenCanvas")
    if canvas then
        return canvas
    end

    if script:FindChild("StatusText") then
        return script
    end

    return nil
end

function BottomScreenUI:Create()
    self.pointerIndex = 1

    self.canvas = nil
    self.status = nil
    self.panel = nil
    self.panelLabel = nil
    self.counter = nil
    self.marker = nil
    self.motionBarFill = nil
    self.motionLabel = nil
    self.dragGhost = nil
    self.motion = nil

    self.stones = {}
    self.dragStone = nil
    self.placedCount = 0

    self.ready = false
    self.subscribed = false

    self.canvasX = 0.0
    self.canvasY = 0.0
    self.panelX = 0.0
    self.panelY = 0.0
    self.panelWidth = 0.0
    self.panelHeight = 0.0
    self.bowlX = 0.0
    self.bowlY = 0.0

    self.lastTouchX = -1
    self.lastTouchY = -1
    self.lastMarkerX = -1
    self.lastMarkerY = -1
    self.markerVisible = false
    self.statusTimer = 0.0
    self.markerHalfWidth = 10.0
    self.markerHalfHeight = 10.0

    self.gaugeWidth = 96.0
    self.lastGaugeWidth = -1.0
    self.gaugeHigh = false
    self.motionFlashTimer = 0.0
    self.motionLabelDefault = "SHAKE UP"
end

function BottomScreenUI:GatherProperties()
    return
    {
        { name = "pointerIndex", type = DatumType.Integer },
    }
end

function BottomScreenUI:Start()
    self.pointerIndex = math.max(1, math.min(4, math.floor(self.pointerIndex or 1)))

    local canvas = ResolveCanvas(self)
    if not canvas then
        Log.Warning("BottomScreenUI: missing Canvas (expected BottomScreenCanvas)")
        self.ready = false
        return
    end

    self.canvas = canvas
    self.status = canvas:FindChild("StatusText")
    self.panel = canvas:FindChild("Panel")
    self.panelLabel = canvas:FindChild("PanelLabel")
    self.counter = canvas:FindChild("CounterText")
    self.marker = canvas:FindChild("TouchMarker")
    self.motionBarFill = canvas:FindChild("MotionBarFill")
    self.motionLabel = canvas:FindChild("MotionLabel")
    self.dragGhost = canvas:FindChild("DragGhost")

    if not (self.status and self.panel and self.panelLabel and self.counter and
        self.marker and self.motionBarFill and self.motionLabel and self.dragGhost) then
        Log.Warning("BottomScreenUI: missing authored widgets")
        self.ready = false
        return
    end

    local root = canvas:GetParent()
    if root then
        self.motion = root:FindChild("MotionSensor")
    end
    if not self.motion then
        local world = self:GetWorld()
        if world then
            self.motion = world:FindNode("MotionSensor")
        end
    end
    if not self.motion then
        Log.Warning("BottomScreenUI: missing MotionSensor node")
    end

    local markerSize = self.marker:GetDimensions()
    self.markerHalfWidth = markerSize.x * 0.5
    self.markerHalfHeight = markerSize.y * 0.5

    local canvasPosition = canvas:GetPosition()
    local panelPosition = self.panel:GetPosition()
    local panelSize = self.panel:GetDimensions()
    self.canvasX = canvasPosition.x
    self.canvasY = canvasPosition.y
    self.panelX = panelPosition.x
    self.panelY = panelPosition.y
    self.panelWidth = panelSize.x
    self.panelHeight = panelSize.y
    self.bowlX = self.canvasX + self.panelX
    self.bowlY = self.canvasY + self.panelY

    local gaugeSize = canvas:FindChild("MotionBarBack")
    if gaugeSize then
        self.gaugeWidth = gaugeSize:GetDimensions().x
    end

    self.stones = {}
    for i = 1, STONE_COUNT do
        local stoneNode = canvas:FindChild("Stone_" .. tostring(i))
        if stoneNode then
            local stonePosition = stoneNode:GetPosition()
            stoneNode:SetDimensions(STONE_SIZE, STONE_SIZE)
            stoneNode:SetVisible(false)
            self.stones[#self.stones + 1] = {
                node = stoneNode,
                homeX = stonePosition.x,
                homeY = stonePosition.y,
                available = false,
                placed = false,
            }
        end
    end
    if #self.stones == 0 then
        Log.Warning("BottomScreenUI: no Stone_1..Stone_5 widgets found")
    end

    self.dragGhost:SetDimensions(STONE_SIZE, STONE_SIZE)
    self.dragGhost:SetColor(COLOR_STONE)
    self.dragGhost:SetVisible(false)

    self.motionBarFill:SetWidth(0.0)
    self.motionBarFill:SetColor(COLOR_GAUGE_LOW)
    self.motionLabelDefault = "SHAKE UP"
    self.motionLabel:SetText(self.motionLabelDefault)
    self.motionLabel:SetColor(COLOR_TEXT_DIM)
    self.panel:SetColor(COLOR_PANEL)
    self.panelLabel:SetColor(COLOR_TEXT)
    self.status:SetText(STATUS_COLLECT)
    self.counter:SetText("STONES 0")
    self.marker:SetVisible(false)

    self.dragStone = nil
    self.placedCount = 0
    self.gaugeHigh = false
    self.lastGaugeWidth = -1.0
    self.motionFlashTimer = 0.0
    self.statusTimer = 0.0
    self.lastTouchX = -1
    self.lastTouchY = -1
    self.lastMarkerX = -1
    self.lastMarkerY = -1
    self.markerVisible = false

    if self.subscribed then
        SignalBus.Unsubscribe("ShakeDetected", self)
    end
    SignalBus.Subscribe("ShakeDetected", self, BottomScreenUI.OnShakeDetected)
    self.subscribed = true

    self.ready = true
    Log.Debug("BottomScreenUI: ready")
end

function BottomScreenUI:IsInsidePanel(x, y)
    return x >= self.bowlX and x <= self.bowlX + self.panelWidth and
        y >= self.bowlY and y <= self.bowlY + self.panelHeight
end

function BottomScreenUI:FindStoneAt(x, y)
    for i = 1, #self.stones do
        local stone = self.stones[i]
        if stone.available and not stone.placed then
            local stoneX = self.canvasX + stone.homeX
            local stoneY = self.canvasY + stone.homeY
            if x >= stoneX and x <= stoneX + STONE_SIZE and
                y >= stoneY and y <= stoneY + STONE_SIZE then
                return stone
            end
        end
    end
    return nil
end

function BottomScreenUI:UpdateMarker(x, y, forceStatus)
    local markerX = x - self.canvasX - self.markerHalfWidth
    local markerY = y - self.canvasY - self.markerHalfHeight
    if markerX ~= self.lastMarkerX or markerY ~= self.lastMarkerY then
        self.lastMarkerX = markerX
        self.lastMarkerY = markerY
        self.marker:SetPosition(markerX, markerY)
    end
    if not self.markerVisible then
        self.markerVisible = true
        self.marker:SetVisible(true)
    end

    if forceStatus then
        self.lastTouchX = math.floor(x)
        self.lastTouchY = math.floor(y)
        self.statusTimer = 0.1
    end
end

function BottomScreenUI:OnShakeDetected(intensity)
    if not self.ready then
        return
    end

    self.motionFlashTimer = 0.35
    self.motionLabel:SetText("DETECTED")
    self.motionLabel:SetColor(COLOR_GAUGE_HIGH)
    self:ShowNextStone()
end

function BottomScreenUI:ShowNextStone()
    for i = 1, #self.stones do
        local stone = self.stones[i]
        if not stone.placed and not stone.available then
            stone.available = true
            stone.node:SetDimensions(STONE_SIZE, STONE_SIZE)
            stone.node:SetPosition(stone.homeX, stone.homeY)
            stone.node:SetColor(COLOR_STONE)
            stone.node:SetVisible(true)
            self.status:SetText(STATUS_DRAG)
            Log.Debug("BottomScreenUI: stone revealed")
            return
        end
    end

    if self.placedCount >= #self.stones then
        self.status:SetText(STATUS_FULL)
    else
        self.status:SetText(STATUS_TRAY_FULL)
    end
end

function BottomScreenUI:StartDrag(stone, x, y)
    self.dragStone = stone
    stone.available = false
    stone.node:SetVisible(false)

    self.dragGhost:SetDimensions(STONE_SIZE, STONE_SIZE)
    self.dragGhost:SetColor(COLOR_STONE)
    self.dragGhost:SetPosition(x - self.canvasX - STONE_SIZE * 0.5, y - self.canvasY - STONE_SIZE * 0.5)
    self.dragGhost:SetVisible(true)
    self.status:SetText(STATUS_DRAG)
    self:UpdateBowlHighlight(x, y)
end

function BottomScreenUI:UpdateBowlHighlight(x, y)
    local inside = self:IsInsidePanel(x, y)
    self.panel:SetColor(inside and COLOR_PANEL_ACTIVE or COLOR_PANEL)
    self.panelLabel:SetColor(inside and COLOR_PANEL_TEXT or COLOR_TEXT)
end

function BottomScreenUI:UpdateDrag(x, y)
    self.dragGhost:SetPosition(x - self.canvasX - STONE_SIZE * 0.5, y - self.canvasY - STONE_SIZE * 0.5)
    self:UpdateBowlHighlight(x, y)
end

function BottomScreenUI:DropStone(x, y)
    local stone = self.dragStone
    if not stone then
        return
    end

    self.dragStone = nil
    self.dragGhost:SetVisible(false)
    self.panel:SetColor(COLOR_PANEL)
    self.panelLabel:SetColor(COLOR_TEXT)

    if self:IsInsidePanel(x, y) then
        self.placedCount = self.placedCount + 1
        stone.placed = true
        stone.available = false
        stone.node:SetDimensions(PLACED_STONE_SIZE, PLACED_STONE_SIZE)
        stone.node:SetPosition(
            self.panelX + 12.0 + (self.placedCount - 1) * 28.0,
            self.panelY + 28.0)
        stone.node:SetVisible(true)
        self.counter:SetText("STONES " .. tostring(self.placedCount))
        Log.Debug("BottomScreenUI: stone placed")
        if self.placedCount >= #self.stones then
            self.status:SetText(STATUS_FULL)
        else
            self.status:SetText(STATUS_DRAG)
        end
    else
        stone.available = true
        stone.node:SetDimensions(STONE_SIZE, STONE_SIZE)
        stone.node:SetPosition(stone.homeX, stone.homeY)
        stone.node:SetVisible(true)
        self.status:SetText(STATUS_DRAG)
    end
end

function BottomScreenUI:UpdateMotionIndicator(dt)
    local intensity = 0.0
    if self.motion then
        intensity = self.motion:GetIntensity() or 0.0
    end

    local width = math.max(0.0, math.min(1.0, intensity)) * self.gaugeWidth
    if math.abs(width - self.lastGaugeWidth) >= 1.0 then
        self.lastGaugeWidth = width
        self.motionBarFill:SetWidth(width)
    end

    local high = intensity >= 0.7
    if high ~= self.gaugeHigh then
        self.gaugeHigh = high
        self.motionBarFill:SetColor(high and COLOR_GAUGE_HIGH or COLOR_GAUGE_LOW)
    end

    if self.motionFlashTimer > 0.0 then
        self.motionFlashTimer = self.motionFlashTimer - dt
        if self.motionFlashTimer <= 0.0 then
            self.motionLabel:SetText(self.motionLabelDefault)
            self.motionLabel:SetColor(COLOR_TEXT_DIM)
        end
    end
end

function BottomScreenUI:Tick(deltaTime)
    if not self.ready then
        return
    end

    local realDelta = Engine.GetRealDeltaTime()
    self.statusTimer = self.statusTimer - realDelta
    self:UpdateMotionIndicator(realDelta)

    if Input.IsPointerPressed(self.pointerIndex) then
        local x, y = Input.GetPointerPosition(self.pointerIndex)
        if x then
            self:UpdateMarker(x, y, true)
            if not self.dragStone then
                local stone = self:FindStoneAt(x, y)
                if stone then
                    self:StartDrag(stone, x, y)
                end
            end
        end
    elseif Input.IsPointerDown(self.pointerIndex) then
        local x, y = Input.GetPointerPosition(self.pointerIndex)
        if x then
            self:UpdateMarker(x, y, false)
            if self.dragStone then
                self:UpdateDrag(x, y)
            end
        end
    end

    if Input.IsPointerReleased(self.pointerIndex) then
        local x, y = Input.GetPointerPosition(self.pointerIndex)
        if self.dragStone then
            if x then
                self:DropStone(x, y)
            else
                self:DropStone(-1.0, -1.0)
            end
        end

        if self.markerVisible then
            self.markerVisible = false
            self.marker:SetVisible(false)
        end

        self.lastTouchX = -1
        self.lastTouchY = -1
        self.lastMarkerX = -1
        self.lastMarkerY = -1
        self.statusTimer = 0.0
    end
end

function BottomScreenUI:Stop()
    if self.subscribed then
        SignalBus.Unsubscribe("ShakeDetected", self)
        self.subscribed = false
    end

    self.canvas = nil
    self.status = nil
    self.panel = nil
    self.panelLabel = nil
    self.counter = nil
    self.marker = nil
    self.motionBarFill = nil
    self.motionLabel = nil
    self.dragGhost = nil
    self.motion = nil
    self.stones = {}
    self.dragStone = nil
    self.ready = false
end
