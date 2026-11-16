PointerInput = {}

function PointerInput.IsPressed(index)
    return Input.IsPointerPressed(index)
end

function PointerInput.IsDown(index)
    return Input.IsPointerDown(index)
end

function PointerInput.IsReleased(index)
    return Input.IsPointerReleased(index)
end

function PointerInput.GetPosition(index)
    return Input.GetPointerPosition(index)
end

function PointerInput.IsTouchDown(index)
    return Input.IsTouchDown(index)
end
