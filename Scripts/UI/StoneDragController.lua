Script.Load("UI/PointerInput")
Script.Load("UI/SongModel")
Script.Load("UI/StoneTray")

StoneDragController = {}

local COLOR_STONE = Vec(0.56, 0.52, 0.46, 1.0)

function StoneDragController.ClearTapRecord(ui)
    ui.lastTapStone = nil
    ui.lastTapTime = -1.0
end

function StoneDragController.StartDrag(ui, stone, x, y)
    ui.dragStone = stone
    ui.dragStartX = x
    ui.dragStartY = y
    stone.available = false
    stone.vx = 0.0
    stone.vy = 0.0

    local texture = stone.node:GetTexture()
    stone.node:SetVisible(false)

    local stoneSize = ui.stoneSize or 30.0
    ui.dragGhost:SetDimensions(stoneSize, stoneSize)
    ui.dragGhost:SetTexture(texture)
    ui.dragGhost:SetColor(texture and Vec(1.0, 1.0, 1.0, 1.0) or COLOR_STONE)
    ui.dragGhost:SetPosition(x - ui.canvasX - stoneSize * 0.5,
        y - ui.canvasY - stoneSize * 0.5)
    ui.dragGhost:SetVisible(true)
end

function StoneDragController.UpdateDrag(ui, x, y)
    local stoneSize = ui.stoneSize or 30.0
    ui.dragGhost:SetPosition(x - ui.canvasX - stoneSize * 0.5,
        y - ui.canvasY - stoneSize * 0.5)
end

function StoneDragController.Drop(ui, x, y)
    local stone = ui.dragStone
    if not stone then
        return
    end

    ui.dragStone = nil
    ui.dragGhost:SetVisible(false)

    local moved = true
    local slot = nil
    if x and y and x >= 0.0 and y >= 0.0 then
        local dx = x - ui.dragStartX
        local dy = y - ui.dragStartY
        moved = (dx * dx + dy * dy) > (ui.doubleTapDragThreshold * ui.doubleTapDragThreshold)
        slot = SongModel.FindSlotAt(ui, x, y)
    end

    if slot and not slot.filled and slot.runeArt ~= "" and slot.runeArt == stone.runeArt then
        stone.placed = true
        stone.available = false
        stone.falling = false
        stone.vx = 0.0
        stone.vy = 0.0
        stone.runeArt = ""
        stone.node:SetVisible(false)

        slot.filled = true
        slot.node:SetColor(Vec(1.0, 1.0, 1.0, 1.0))
        slot.node:SetOpacityFloat(1.0)

        local completesSong = (ui.songFilled + 1 >= #ui.song)

        ui.songFilled = ui.songFilled + 1
        ui.trayFullWarned = false
        StoneDragController.ClearTapRecord(ui)
        Log.Debug("BottomScreenUI: song tile filled")

        if not completesSong then
            local sound = ui.songSfx[slot.index]
            if sound then
                Audio.StopSounds(sound)
                Audio.PlaySound2D(sound, 1.0, 1.0)
            end
        end

        if ui.songFilled >= #ui.song then
            SongModel.BeginCompletion(ui)
        end
        return
    end

    StoneTray.RestoreFromDrag(ui, stone, x, y)
    if moved then
        StoneDragController.ClearTapRecord(ui)
    end
end

function StoneDragController.UpdateInput(ui)
    if ui.gameComplete then
        return
    end

    local pointerIndex = ui.pointerIndex

    if PointerInput.IsPressed(pointerIndex) then
        local x, y = PointerInput.GetPosition(pointerIndex)
        if x then
            ClickSparkEffect.Spawn(ui, x, y)
            if not ui.dragStone then
                local stone = StoneTray.FindStoneAt(ui, x, y)
                if stone then
                    local now = Engine.GetTime() or 0.0
                    if stone == ui.lastTapStone and ui.lastTapTime >= 0.0 and
                        (now - ui.lastTapTime) <= ui.doubleTapTime then
                        StoneTray.Discard(ui, stone)
                        StoneDragController.ClearTapRecord(ui)
                    else
                        ui.lastTapStone = stone
                        ui.lastTapTime = now
                        StoneDragController.StartDrag(ui, stone, x, y)
                    end
                else
                    StoneDragController.ClearTapRecord(ui)
                end
            end
        end
    elseif PointerInput.IsDown(pointerIndex) then
        local x, y = PointerInput.GetPosition(pointerIndex)
        if x and ui.dragStone then
            StoneDragController.UpdateDrag(ui, x, y)
        end
    end

    if PointerInput.IsReleased(pointerIndex) and ui.dragStone then
        local x, y = PointerInput.GetPosition(pointerIndex)
        if x then
            StoneDragController.Drop(ui, x, y)
        else
            StoneDragController.Drop(ui, -1.0, -1.0)
        end
    end
end

function StoneDragController.Stop(ui)
    if ui.dragGhost then
        ui.dragGhost:SetVisible(false)
    end
    ui.dragStone = nil
    StoneDragController.ClearTapRecord(ui)
end
