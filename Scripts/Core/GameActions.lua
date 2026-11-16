GameActions = {}

local sRegistered = false
local sPlayerInputReady = false

local function TryRegister(category, name, trigger, bindings)
    if PlayerInput == nil or PlayerInput.RegisterAction == nil then
        return false
    end

    local ok = pcall(PlayerInput.RegisterAction, category, name,
    {
        trigger = trigger,
        bindings = bindings,
    })
    return ok
end

function GameActions.Register()
    if sRegistered then
        return
    end
    sRegistered = true

    if PlayerInput == nil then
        return
    end

    local mineOk = TryRegister("Game", "Mine", "SinglePress",
    {
        { type = "Key", key = Key.E },
        { type = "Gamepad", button = Gamepad.A },
    })

    local recenterOk = TryRegister("Game", "RecenterCamera", "SinglePress",
    {
        { type = "Key", key = Key.Q },
        { type = "Gamepad", button = Gamepad.L1 },
    })

    local consoleOk = TryRegister("Game", "ToggleDebugConsole", "SinglePress",
    {
        { type = "Key", key = Key.F1 },
        { type = "Gamepad", button = Gamepad.L2 },
    })

    sPlayerInputReady = mineOk and recenterOk and consoleOk
    Log.Debug("GameActions: PlayerInput ready=" .. tostring(sPlayerInputReady))
end

local function WasJustActivated(actionName)
    if not sPlayerInputReady then
        return nil
    end

    local ok, value = pcall(PlayerInput.WasJustActivated, "Game", actionName)
    if ok then
        return value == true
    end

    return nil
end

function GameActions.MinePressed()
    GameActions.Register()

    if WasJustActivated("Mine") == true then
        return true
    end

    return Input.IsKeyPressed(Key.E) or Input.IsGamepadPressed(Gamepad.A)
end

function GameActions.RecenterCameraPressed()
    GameActions.Register()

    if WasJustActivated("RecenterCamera") == true then
        return true
    end

    return Input.IsKeyPressed(Key.Q) or Input.IsGamepadPressed(Gamepad.L1)
end

function GameActions.ToggleDebugConsolePressed()
    GameActions.Register()

    if WasJustActivated("ToggleDebugConsole") == true then
        return true
    end

    return Input.IsKeyPressed(Key.F1) or Input.IsGamepadPressed(Gamepad.L2)
end
