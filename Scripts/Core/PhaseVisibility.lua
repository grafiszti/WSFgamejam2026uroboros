PhaseVisibility = {}

function PhaseVisibility.ShouldShow(isNightRune, isDay)
    return (isNightRune and not isDay) or (not isNightRune and isDay)
end

function PhaseVisibility.Apply(node, revealed, collecting, isNightRune, isDay)
    if node == nil or not revealed or collecting then
        return
    end

    node:SetVisible(PhaseVisibility.ShouldShow(isNightRune, isDay))
end
