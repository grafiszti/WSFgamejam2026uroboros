Script.Load("Core/GameSession")
Script.Load("Systems/PlayerFootsteps")

EndingSequence = {}

local kScene = "SC_Title"
local kAnimationTimeout = 2.0
local kFreezeHold = 0.25
local kFadeDuration = 1.2
local kHoldDuration = 0.2

local function FindOrCreateOverlay(canvas, name, fallbackWidth, fallbackHeight)
    if canvas == nil then
        return nil
    end

    local overlay = canvas:FindChild(name)
    if overlay == nil then
        overlay = canvas:CreateChild("Quad")
        if overlay == nil then
            return nil
        end
        overlay:SetName(name)
    end

    local resolution = canvas:GetScreenResolution()
    local width = fallbackWidth
    local height = fallbackHeight
    if resolution ~= nil and resolution.x > 0.0 and resolution.y > 0.0 then
        width = resolution.x
        height = resolution.y
    end

    overlay:SetPosition(0.0, 0.0)
    overlay:SetDimensions(width, height)
    overlay:SetTexture(nil)
    overlay:SetColor(Vec(1.0, 1.0, 1.0, 1.0))
    overlay:SetOpacityFloat(0.0)
    overlay:SetVisible(true)
    return overlay
end

function EndingSequence.Begin(ctrl)
    if ctrl.ending then
        return
    end

    ctrl.ending = true
    GameSession.SetPhase(GameSession.PHASE_ENDING)
    ctrl.enableControl = false
    ctrl.moveDir.x = 0.0
    ctrl.moveDir.y = 0.0
    ctrl.moveDir.z = 0.0
    ctrl.stunTimer = 0.0
    ctrl.endingAnimTimer = 0.0
    ctrl.endingFreezeTimer = 0.0
    ctrl.endingFadeStarted = false
    ctrl.endingFadeTimer = 0.0
    ctrl.endingHoldTimer = 0.0
    ctrl.endingRedirected = false

    PlayerFootsteps.Stop(ctrl)

    if ctrl.tweenID then
        Tween.Cancel(ctrl.tweenID)
        ctrl.tweenID = nil
    end

    if ctrl.Music then
        Audio.StopSounds(ctrl.Music)
    end

    local world = ctrl:GetWorld()
    if world == nil then
        return
    end

    ctrl.endingSprite = ctrl.AnimatedSprite
    if ctrl.endingSprite == nil then
        ctrl.endingSprite = world:FindNode("AnimatedSprite3D")
    end
    if ctrl.endingSprite then
        ctrl.endingSprite:PlayAnimation(ctrl.EndingAnimation)
    end

    ctrl.endingTopOverlay = FindOrCreateOverlay(world:FindNode("Canvas_UI"),
        "EndingWhiteOut_Top", 400.0, 240.0)
    ctrl.endingBottomOverlay = FindOrCreateOverlay(world:FindNode("BottomScreenCanvas"),
        "EndingWhiteOut_Bottom", 320.0, 240.0)
    Log.Debug("EndingSequence: started")
end

function EndingSequence.SetOpacity(ctrl, opacity)
    if ctrl.endingTopOverlay then
        ctrl.endingTopOverlay:SetOpacityFloat(opacity)
    end
    if ctrl.endingBottomOverlay then
        ctrl.endingBottomOverlay:SetOpacityFloat(opacity)
    end
end

function EndingSequence.Update(ctrl, deltaTime)
    local dt = math.min(Engine.GetRealDeltaTime(), 0.1)
    if dt <= 0.0 then
        dt = math.min(deltaTime, 0.1)
    end
    if dt <= 0.0 then
        return
    end

    ctrl.endingAnimTimer = ctrl.endingAnimTimer + dt

    if not ctrl.endingFadeStarted then
        local waiting = false
        if ctrl.endingSprite and ctrl.endingSprite.IsPlaying then
            local animName = nil
            if ctrl.endingSprite.GetCurrentAnimationName then
                animName = ctrl.endingSprite:GetCurrentAnimationName()
            end
            waiting = (animName == ctrl.EndingAnimation) and ctrl.endingSprite:IsPlaying()
        end

        if waiting and ctrl.endingAnimTimer < kAnimationTimeout then
            return
        end

        ctrl.endingFreezeTimer = ctrl.endingFreezeTimer + dt
        if ctrl.endingFreezeTimer < kFreezeHold then
            return
        end

        ctrl.endingFadeStarted = true
        ctrl.endingFadeTimer = 0.0
        EndingSequence.SetOpacity(ctrl, 0.0)
    end

    ctrl.endingFadeTimer = ctrl.endingFadeTimer + dt
    local t = math.min(1.0, ctrl.endingFadeTimer / kFadeDuration)
    EndingSequence.SetOpacity(ctrl, t)

    if t >= 1.0 then
        ctrl.endingHoldTimer = ctrl.endingHoldTimer + dt
        if ctrl.endingHoldTimer >= kHoldDuration and not ctrl.endingRedirected then
            ctrl.endingRedirected = true
            local world = ctrl:GetWorld()
            if world then
                world:LoadScene(kScene, false)
            end
        end
    end
end

function EndingSequence.Stop(ctrl)
    ctrl.ending = false
    ctrl.endingSprite = nil
    ctrl.endingTopOverlay = nil
    ctrl.endingBottomOverlay = nil
    ctrl.endingRedirected = false
end
