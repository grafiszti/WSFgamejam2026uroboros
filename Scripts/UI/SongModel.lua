Script.Load("Core/Events")
Script.Load("Core/RuneCatalog")

SongModel = {}

local COLOR_TILE_PENDING = Vec(0.55, 0.55, 0.55, 1.0)
local COLOR_TILE_FILLED = Vec(1.0, 1.0, 1.0, 1.0)
local PENDING_OPACITY = 0.45
local SLOT_PADDING = 2.0

function SongModel.Reset(ui)
    ui.song = {}
    ui.songSfx = {}
    ui.songFilled = 0
    ui.playback = nil
    ui.gameComplete = false
    ui.endingRequested = false
end

function SongModel.Generate(ui)
    ui.song = {}
    ui.songFilled = 0

    if math.randomseed then
        local seed = math.floor((Engine.GetTime() or 0.0) * 1000000.0)
        math.randomseed(seed)
    end

    local entries = RuneCatalog.All()
    local counts = {}
    for i = 1, ui.songLength do
        local candidates = {}
        for j = 1, #entries do
            if (counts[j] or 0) < ui.maxRuneRepeats then
                candidates[#candidates + 1] = j
            end
        end

        if #candidates == 0 then
            break
        end

        local pick = candidates[math.random(1, #candidates)]
        counts[pick] = (counts[pick] or 0) + 1
        ui.song[#ui.song + 1] = entries[pick].art
    end
end

function SongModel.ApplyToSlots(ui)
    for i = 1, #ui.songSlots do
        local slot = ui.songSlots[i]
        local art = ui.song[i]
        if art then
            slot.runeArt = art
            slot.filled = false
            slot.node:SetTexture(ui:GetRuneTexture(art))
            slot.node:SetColor(COLOR_TILE_PENDING)
            slot.node:SetOpacityFloat(PENDING_OPACITY)
            slot.node:SetVisible(true)
        else
            slot.runeArt = ""
            slot.filled = true
            slot.node:SetVisible(false)
        end
    end
end

function SongModel.LoadSfx(ui)
    ui.songSfx = {}
    for i = 1, #ui.song do
        local sfxName = RuneCatalog.GetSfx(ui.song[i])
        if sfxName then
            local sound = LoadAsset(sfxName)
            if sound then
                ui.songSfx[i] = sound
            else
                Log.Warning("BottomScreenUI: missing rune SFX: " .. sfxName)
            end
        end
    end
end

function SongModel.FindSlotAt(ui, x, y)
    for i = 1, #ui.songSlots do
        local slot = ui.songSlots[i]
        local left = ui.canvasX + slot.x - SLOT_PADDING
        local top = ui.canvasY + slot.y - SLOT_PADDING
        if x >= left and x <= left + slot.width + SLOT_PADDING * 2.0 and
            y >= top and y <= top + slot.height + SLOT_PADDING * 2.0 then
            return slot
        end
    end
    return nil
end

function SongModel.BeginCompletion(ui)
    if ui.gameComplete then
        return
    end

    ui.gameComplete = true
    ui.playback = { index = 1, timer = 0.0 }
    SignalBus.Emit(Events.GAME_COMPLETED)
    Log.Debug("BottomScreenUI: song complete")
end

function SongModel.UpdatePlayback(ui, dt)
    if not ui.playback or dt <= 0.0 then
        return
    end

    local playback = ui.playback
    playback.timer = playback.timer - dt
    if playback.timer > 0.0 then
        return
    end

    if playback.index <= #ui.song then
        local sound = ui.songSfx[playback.index]
        if sound then
            Audio.PlaySound2D(sound, 1.0, 1.0)
        end
        playback.index = playback.index + 1
        playback.timer = ui.noteInterval
    else
        ui.playback = nil
        if not ui.endingRequested then
            ui.endingRequested = true
            SignalBus.Emit(Events.ENDING_REQUESTED)
            Log.Debug("BottomScreenUI: ending requested")
        end
    end
end

function SongModel.Stop(ui)
    ui.playback = nil
    ui.gameComplete = false
    ui.endingRequested = false
    ui.songFilled = 0
end
