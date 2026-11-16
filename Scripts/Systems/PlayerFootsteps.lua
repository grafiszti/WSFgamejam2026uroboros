PlayerFootsteps = {}

function PlayerFootsteps.Build(ctrl)
    local sounds = {}
    local candidates =
    {
        ctrl.footstepSounds1,
        ctrl.footstepSounds2,
        ctrl.footstepSounds3,
        ctrl.footstepSounds4,
    }

    for i = 1, #candidates do
        if candidates[i] ~= nil then
            sounds[#sounds + 1] = candidates[i]
        end
    end

    ctrl.footstepSounds = sounds
    ctrl.footstepIndex = 1
    ctrl.footstepTimer = 0.0
    ctrl.currentFootstep = nil
end

function PlayerFootsteps.Update(ctrl, deltaTime)
    local isWalking = ctrl.currentAnimation == "WalkFront" or
        ctrl.currentAnimation == "WalkSide"
    if not isWalking or #ctrl.footstepSounds == 0 then
        PlayerFootsteps.Stop(ctrl)
        return
    end

    ctrl.footstepTimer = ctrl.footstepTimer - deltaTime
    if ctrl.footstepTimer > 0.0 then
        return
    end

    if ctrl.currentFootstep then
        Audio.StopSounds(ctrl.currentFootstep)
    end

    if ctrl.footstepIndex > #ctrl.footstepSounds then
        ctrl.footstepIndex = 1
    end

    ctrl.currentFootstep = ctrl.footstepSounds[ctrl.footstepIndex]
    Audio.Play(ctrl.currentFootstep)
    ctrl.footstepIndex = ctrl.footstepIndex % #ctrl.footstepSounds + 1
    ctrl.footstepTimer = 0.4
end

function PlayerFootsteps.Stop(ctrl)
    if ctrl.currentFootstep then
        Audio.StopSounds(ctrl.currentFootstep)
        ctrl.currentFootstep = nil
    end
    ctrl.footstepTimer = 0.0
end
