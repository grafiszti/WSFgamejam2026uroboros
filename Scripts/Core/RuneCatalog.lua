RuneCatalog = {}

local kEntries =
{
    { art = "Tile - Mol1", sfx = "C-Mol1-SFX", night = true },
    { art = "Tile - Mol2", sfx = "D-Mol2-SFX", night = true },
    { art = "Tile - Mol3", sfx = "F-Mol3-SFX", night = true },
    { art = "Tile - Mol4", sfx = "G-Mol4-SFX", night = true },
    { art = "Tile - Dur1", sfx = "C-Dur1-SFX", night = false },
    { art = "Tile - Dur2", sfx = "D-Dur2-SFX", night = false },
    { art = "Tile - Dur3", sfx = "E-Dur3-SFX", night = false },
    { art = "Tile - Dur4", sfx = "F-Dur4-SFX", night = false },
    { art = "Tile - Dur5", sfx = "G-Dur5-SFX", night = false },
    { art = "Tile - Dur6", sfx = "A-Dur6-SFX", night = false },
}

local sByArt = {}

for i = 1, #kEntries do
    local entry = kEntries[i]
    sByArt[entry.art] = entry
end

function RuneCatalog.All()
    return kEntries
end

function RuneCatalog.Get(art)
    if art == nil or art == "" then
        return nil
    end
    return sByArt[art]
end

function RuneCatalog.GetSfx(art)
    local entry = RuneCatalog.Get(art)
    return entry and entry.sfx or nil
end

function RuneCatalog.IsNight(art)
    local entry = RuneCatalog.Get(art)
    if entry then
        return entry.night
    end

    return art ~= nil and art:find("Mol", 1, true) ~= nil
end

function RuneCatalog.ArtForNode(nodeName)
    if nodeName == nil then
        return ""
    end

    local suffix = nil
    if nodeName:sub(1, 4) == "Rock" then
        suffix = nodeName:sub(5)
    elseif nodeName:sub(1, 3) == "SM_" then
        local candidate = nodeName:sub(4)
        if candidate:sub(1, 7) == "Tile - " then
            suffix = candidate:sub(8)
        end
    elseif nodeName:sub(1, 7) == "Tile - " then
        suffix = nodeName:sub(8)
    end

    if suffix then
        local base = suffix:match("^(Dur[1-6])") or suffix:match("^(Mol[1-4])")
        if base then
            return "Tile - " .. base
        end
    end

    return ""
end
