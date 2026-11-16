Script.Load("Core/Events")
Script.Load("Core/CollisionLayers")
Script.Load("Core/SurfaceMath")
Script.Load("Core/GameSession")
Script.Load("Core/GameActions")
Script.Load("Systems/PlanetLocomotion")
Script.Load("Systems/PlayerVisuals")
Script.Load("Systems/PlayerFootsteps")
Script.Load("Systems/ThirdPersonCamera")
Script.Load("Systems/EndingSequence")

ThirdPersonController = {}

ThirdPersonController.kGroundingDot = 0.9

local kEndingAnimation = "Boop"

function ThirdPersonController:Create()
    self.collider = nil
    self.camera = nil
    self.cameraPivot = nil
    self.mesh = nil
    self.cameraDistance = 10.0
    self.moveSpeed = 7.0
    self.followCamHeight = 4.0
    self.enableControl = true
    self.enableFollowCam = false
    self.enableCameraTrace = true
    self.AnimatedSprite = nil
    self.meshBaseRotation = nil
    self.footstepSounds = nil
    self.footstepSounds1 = nil
    self.footstepSounds2 = nil
    self.footstepSounds3 = nil
    self.footstepSounds4 = nil

    self.moveDir = Vec(0, 0, 0)
    self.currentAnimation = nil
    self.meshFlipped = false
    self.footstepIndex = 1
    self.footstepTimer = 0.0
    self.currentFootstep = nil
    self.vertMoveChange = false
    self.lookVec = Vec()
    self.meshYaw = 0.0
    self.lastNormal = Vec()
    self.tweenID = nil
    self.tweenTarget = Vec()
    self.DirLight = nil
    self.Music = nil
    self.stunTimer = 0.0
    self.subscribedStun = false
    self.subscribedComplete = false
    self.consoleVisible = false
    self.lastValidGroundPos = Vec()
    self.groundMissFrames = 0
    self.groundLost = false
    self.groundHitLogged = false
    self.EndingAnimation = kEndingAnimation
    self.ending = false
    self.endingSprite = nil
    self.endingTopOverlay = nil
    self.endingBottomOverlay = nil
    self.endingAnimTimer = 0.0
    self.endingFreezeTimer = 0.0
    self.endingFadeStarted = false
    self.endingFadeTimer = 0.0
    self.endingHoldTimer = 0.0
    self.endingRedirected = false
    self.subscribedEnding = false
end

function ThirdPersonController:GatherProperties()
    return
    {
        { name = "collider",          type = DatumType.Node },
        { name = "camera",            type = DatumType.Node },
        { name = "cameraPivot",       type = DatumType.Node },
        { name = "mesh",              type = DatumType.Node },
        { name = "cameraDistance",    type = DatumType.Float },
        { name = "moveSpeed",         type = DatumType.Float },
        { name = "followCamHeight",   type = DatumType.Float },
        { name = "enableControl",     type = DatumType.Bool },
        { name = "enableFollowCam",   type = DatumType.Bool },
        { name = "enableCameraTrace", type = DatumType.Bool },
        { name = "EndingAnimation",   type = DatumType.String },
        { name = "DirLight",          type = DatumType.Node },
        { name = "Music",             type = DatumType.Asset },
        { name = "AnimatedSprite",    type = DatumType.Node },
        { name = "footstepSounds1",   type = DatumType.Asset },
        { name = "footstepSounds2",   type = DatumType.Asset },
        { name = "footstepSounds3",   type = DatumType.Asset },
        { name = "footstepSounds4",   type = DatumType.Asset },
    }
end

function ThirdPersonController:Start()
    self.cameraDistance = math.max(1.0, self.cameraDistance or 10.0)
    self.moveSpeed = math.max(0.0, self.moveSpeed or 7.0)
    self.followCamHeight = self.followCamHeight or 4.0

    if self.Music then
        Audio.Play(self.Music, 1.0, 1.0, 0.0, true)
    end

    PlayerFootsteps.Build(self)

    if not self.collider then
        self.collider = self:GetParent()
    end
    if self.collider then
        self.collider:AddTag("Controller")
    end

    if not self.camera and self.collider then
        self.camera = self.collider:FindChild("Camera", true)
    end

    if self.mesh then
        self.meshBaseRotation = self.mesh:GetRotation()
        if self.mesh ~= self.collider then
            if self.mesh.EnableCollision then
                self.mesh:EnableCollision(false)
            end
            if self.mesh.EnableOverlaps then
                self.mesh:EnableOverlaps(false)
            end
        end
    end

    self.stunTimer = 0.0
    if self.collider then
        self.lastNormal = SurfaceMath.SafeNormalize(self.collider:GetUpVector(), Vec(0.0, 1.0, 0.0))
        self.lastValidGroundPos = self.collider:GetWorldPosition()
        self.tweenTarget = self.collider:GetRotation()
    end
    self.groundMissFrames = 0
    self.groundLost = false
    self.groundHitLogged = false

    if self.EndingAnimation == nil or self.EndingAnimation == "" then
        self.EndingAnimation = kEndingAnimation
    end
    self.ending = false
    self.endingSprite = nil
    self.endingTopOverlay = nil
    self.endingBottomOverlay = nil
    self.endingAnimTimer = 0.0
    self.endingFreezeTimer = 0.0
    self.endingFadeStarted = false
    self.endingFadeTimer = 0.0
    self.endingHoldTimer = 0.0
    self.endingRedirected = false

    GameSession.Reset()
    GameSession.SetPhase(GameSession.PHASE_PLAYING)

    if self.subscribedStun then
        SignalBus.Unsubscribe(Events.PLAYER_STUNNED, self)
    end
    SignalBus.Subscribe(Events.PLAYER_STUNNED, self, ThirdPersonController.OnPlayerStunned)
    self.subscribedStun = true

    if self.subscribedComplete then
        SignalBus.Unsubscribe(Events.GAME_COMPLETED, self)
    end
    SignalBus.Subscribe(Events.GAME_COMPLETED, self, ThirdPersonController.OnGameCompleted)
    self.subscribedComplete = true

    if self.subscribedEnding then
        SignalBus.Unsubscribe(Events.ENDING_REQUESTED, self)
    end
    SignalBus.Subscribe(Events.ENDING_REQUESTED, self, ThirdPersonController.OnEndingRequested)
    self.subscribedEnding = true

    self.consoleVisible = false
    Renderer.EnableConsole(false)
    self:DisableOverlapChecks()
end

function ThirdPersonController:DisableOverlapChecks()
    local function disableOverlaps(node)
        if node:IsA("Primitive3D") then
            node:EnableOverlaps(false)
        end
        for i = 1, node:GetNumChildren() do
            disableOverlaps(node:GetChild(i))
        end
    end

    if self.collider then
        self.collider:EnableOverlaps(false)
    end

    local world = self:GetWorld()
    local root = world and world:GetRootNode()
    if root then
        disableOverlaps(root)
    end
end

function ThirdPersonController:OnPlayerStunned(duration)
    self.stunTimer = math.max(self.stunTimer or 0.0, duration or 2.0)
    Log.Debug("ThirdPersonController: stunned")
end

function ThirdPersonController:OnGameCompleted()
    self.enableControl = false
    self.moveDir.x = 0.0
    self.moveDir.y = 0.0
    self.moveDir.z = 0.0
    GameSession.SetPhase(GameSession.PHASE_ENDING)
    if self.Music then
        Audio.StopSounds(self.Music)
    end
    Log.Debug("ThirdPersonController: game complete")
end

function ThirdPersonController:OnEndingRequested()
    EndingSequence.Begin(self)
end

function ThirdPersonController:Stop()
    if self.Music then
        Audio.StopSounds(self.Music)
    end
    PlayerFootsteps.Stop(self)

    if self.subscribedStun then
        SignalBus.Unsubscribe(Events.PLAYER_STUNNED, self)
        self.subscribedStun = false
    end
    if self.subscribedComplete then
        SignalBus.Unsubscribe(Events.GAME_COMPLETED, self)
        self.subscribedComplete = false
    end
    if self.subscribedEnding then
        SignalBus.Unsubscribe(Events.ENDING_REQUESTED, self)
        self.subscribedEnding = false
    end
    self.stunTimer = 0.0

    if self.tweenID then
        Tween.Cancel(self.tweenID)
        self.tweenID = nil
    end
    self.groundMissFrames = 0
    self.groundLost = false
    EndingSequence.Stop(self)

    Renderer.EnableConsole(false)
    self.consoleVisible = false
end

function ThirdPersonController:UpdateDebugConsoleToggle()
    if GameActions.ToggleDebugConsolePressed() then
        self.consoleVisible = not self.consoleVisible
        Renderer.EnableConsole(self.consoleVisible)
    end
end

function ThirdPersonController:Tick(deltaTime)
    if self.ending then
        EndingSequence.Update(self, deltaTime)
        return
    end

    self:UpdateDebugConsoleToggle()

    PlanetLocomotion.UpdateInput(self, deltaTime)
    PlayerVisuals.Update(self)
    PlayerFootsteps.Update(self, deltaTime)
    PlanetLocomotion.Move(self, deltaTime)
    PlanetLocomotion.AimSun(self)
    ThirdPersonCamera.Update(self)
end

function ThirdPersonController:GetCameraYaw()
    return ThirdPersonCamera.GetYaw(self)
end
