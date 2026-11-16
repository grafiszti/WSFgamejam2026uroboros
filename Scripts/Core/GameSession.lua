GameSession = {}

GameSession.PHASE_INTRO = "Intro"
GameSession.PHASE_PLAYING = "Playing"
GameSession.PHASE_ENDING = "Ending"

GameSession.phase = GameSession.PHASE_PLAYING
GameSession.isDay = true

function GameSession.Reset()
    GameSession.phase = GameSession.PHASE_PLAYING
    GameSession.isDay = true
end

function GameSession.SetPhase(phase)
    GameSession.phase = phase or GameSession.PHASE_PLAYING
end

function GameSession.GetPhase()
    return GameSession.phase
end

function GameSession.SetDay(isDay)
    GameSession.isDay = isDay == true
end

function GameSession.IsDay()
    return GameSession.isDay
end

function GameSession.IsPlaying()
    return GameSession.phase == GameSession.PHASE_PLAYING
end
