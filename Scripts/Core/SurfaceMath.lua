SurfaceMath = {}

local kEpsilonSq = 0.000001

function SurfaceMath.SafeNormalize(vector, fallback)
    if vector == nil then
        return fallback
    end

    local magnitudeSq = vector.MagnitudeSq and vector:MagnitudeSq() or
        (vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    if magnitudeSq <= kEpsilonSq then
        return fallback
    end

    return vector / math.sqrt(magnitudeSq)
end

function SurfaceMath.ProjectOnPlane(vector, normal)
    if vector == nil then
        return Vec(0.0, 0.0, 0.0)
    end

    local unitNormal = SurfaceMath.SafeNormalize(normal, Vec(0.0, 1.0, 0.0))
    return vector - unitNormal * Vector.Dot(vector, unitNormal)
end

function SurfaceMath.UpFacing(normal, up, threshold)
    if normal == nil or up == nil then
        return false
    end

    local unitNormal = SurfaceMath.SafeNormalize(normal, Vec(0.0, 0.0, 0.0))
    local unitUp = SurfaceMath.SafeNormalize(up, Vec(0.0, 1.0, 0.0))
    return Vector.Dot(unitNormal, unitUp) > (threshold or 0.5)
end

function SurfaceMath.SquaredDistance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return dx * dx + dy * dy + dz * dz
end
