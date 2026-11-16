Script.Load("Core/Events")

EnemyContact = {}

local STUN_PARTICLE = "PlayerStunnedParticle"
local STUN_PARTICLE_MATERIAL = "ParticleMaterial"
local sStunParticleWarned = false
local sStunMaterialWarned = false

function EnemyContact.LoadAssets(enemy)
    enemy.stunParticle = LoadAsset(STUN_PARTICLE)
    if enemy.stunParticle == nil and not sStunParticleWarned then
        sStunParticleWarned = true
        Log.Warning("Enemy: missing particle " .. STUN_PARTICLE)
    end

    enemy.stunParticleMaterial = LoadAsset(STUN_PARTICLE_MATERIAL)
    if enemy.stunParticleMaterial == nil and not sStunMaterialWarned then
        sStunMaterialWarned = true
        Log.Warning("Enemy: missing material " .. STUN_PARTICLE_MATERIAL)
    end
end

function EnemyContact.CheckPlayerDistance(enemy)
    if enemy.hitCooldown > 0.0 or not enemy.player then
        return
    end

    local a = enemy:GetWorldPosition()
    local b = enemy.player:GetWorldPosition()
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z

    if dx * dx + dy * dy + dz * dz <= enemy.stunRadiusSq then
        EnemyContact.TryHitPlayer(enemy)
    end
end

function EnemyContact.SpawnStunParticle(enemy)
    if not enemy.stunParticle then
        return
    end

    local world = enemy:GetWorld()
    if not world then
        return
    end

    local position = enemy:GetWorldPosition()
    if enemy.player then
        position = enemy.player:GetWorldPosition()
    end

    local particle = world:SpawnParticle(enemy.stunParticle, position)
    if particle then
        if enemy.stunParticleMaterial then
            particle:SetMaterialOverride(enemy.stunParticleMaterial)
        end
        if TargetScreen then
            particle:SetTargetScreen(TargetScreen.Top)
        end
    end
end

function EnemyContact.TryHitPlayer(enemy)
    if enemy.hitCooldown > 0.0 then
        return
    end

    enemy.hitCooldown = enemy.hitCooldownDuration
    Log.Debug("Enemy: hit player")
    EnemyContact.SpawnStunParticle(enemy)
    SignalBus.Emit(Events.PLAYER_STUNNED, enemy.stunDuration)
end
