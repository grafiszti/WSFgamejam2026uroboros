BottomScreenUI = {}

local COLOR_PANEL = Vec(0.10, 0.22, 0.26, 1.0)
local COLOR_PANEL_ACTIVE = Vec(0.18, 0.72, 0.58, 1.0)
local COLOR_TEXT = Vec(0.92, 0.96, 0.95, 1.0)
local COLOR_PANEL_TEXT = Vec(0.04, 0.08, 0.08, 1.0)

local STATUS_DEFAULT = "TOUCH THE SCREEN"

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

    self.taps = 0
    self.panelPressed = false
    self.ready = false

    self.canvasX = 0.0
    self.canvasY = 0.0
    self.panelX = 0.0
    self.panelY = 0.0
    self.panelWidth = 0.0
    self.panelHeight = 0.0

    self.lastTouchX = -1
    self.lastTouchY = -1
    self.lastMarkerX = -1
    self.lastMarkerY = -1
    self.markerVisible = false
    self.statusTimer = 0.0
    self.markerHalfWidth = 10.0
    self.markerHalfHeight = 10.0
    self.statusDefault = STATUS_DEFAULT
    self.counterDefault = "TAPS 0"
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

    if not (self.status and self.panel and self.panelLabel and self.counter and self.marker) then
        Log.Warning("BottomScreenUI: missing authored widgets (StatusText, Panel, PanelLabel, CounterText, TouchMarker)")
        self.ready = false
        return
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

    self.statusDefault = self.status:GetText()
    self.counterDefault = self.counter:GetText()

    self.taps = 0
    self.panelPressed = false
    self.panel:SetColor(COLOR_PANEL)
    self.panelLabel:SetColor(COLOR_TEXT)
    self.status:SetText(self.statusDefault)
    self.counter:SetText(self.counterDefault)
    self.marker:SetVisible(false)

    self.lastTouchX = -1
    self.lastTouchY = -1
    self.lastMarkerX = -1
    self.lastMarkerY = -1
    self.markerVisible = false
    self.statusTimer = 0.0
    self.ready = true
end

function BottomScreenUI:IsInsidePanel(x, y)
    local left = self.canvasX + self.panelX
    local top = self.canvasY + self.panelY
    return x >= left and x <= left + self.panelWidth and
        y >= top and y <= top + self.panelHeight
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

    local ix = math.floor(x)
    local iy = math.floor(y)
    if ix ~= self.lastTouchX or iy ~= self.lastTouchY then
        if forceStatus or self.statusTimer <= 0.0 then
            self.lastTouchX = ix
            self.lastTouchY = iy
            self.statusTimer = 0.1
            self.status:SetText(string.format("TOUCH %d, %d", ix, iy))
        end
    end
end

function BottomScreenUI:Tick(deltaTime)
    if not self.ready then
        return
    end

    self.statusTimer = self.statusTimer - Engine.GetRealDeltaTime()

    if Input.IsPointerPressed(self.pointerIndex) then
        local x, y = Input.GetPointerPosition(self.pointerIndex)
        if x then
            self:UpdateMarker(x, y, true)
            if self:IsInsidePanel(x, y) then
                self.panelPressed = true
                self.panel:SetColor(COLOR_PANEL_ACTIVE)
                self.panelLabel:SetColor(COLOR_PANEL_TEXT)
            end
        end
    elseif Input.IsPointerDown(self.pointerIndex) then
        local x, y = Input.GetPointerPosition(self.pointerIndex)
        if x then
            self:UpdateMarker(x, y, false)
        end
    end

    if Input.IsPointerReleased(self.pointerIndex) then
        if self.markerVisible then
            self.markerVisible = false
            self.marker:SetVisible(false)
        end

        if self.panelPressed then
            self.panelPressed = false
            self.taps = self.taps + 1
            self.counter:SetText("TAPS " .. tostring(self.taps))
        end

        self.panel:SetColor(COLOR_PANEL)
        self.panelLabel:SetColor(COLOR_TEXT)
        self.status:SetText(self.statusDefault)
        self.lastTouchX = -1
        self.lastTouchY = -1
        self.lastMarkerX = -1
        self.lastMarkerY = -1
        self.statusTimer = 0.0
    end
end

function BottomScreenUI:Stop()
    self.canvas = nil
    self.status = nil
    self.panel = nil
    self.panelLabel = nil
    self.counter = nil
    self.marker = nil
    self.panelPressed = false
    self.ready = false
end
