local utils = require "core.utils"
local tracker = require "core.tracker"

local pylon_logic = {}

local pylons = {
    "SkulkingHellborne",       -- Hellborne Hunting You, Hellborne +1 Aether
    "SurgingHellborne",        -- +1 Hellborne when Spawned, Hellborne Grant +1 Aether
    "EmpoweredHellborne",      -- Hellborne +25% Damage, Hellborne grant +1 Aether
    "MeteoricHellborne",       -- Hellfire now spawns Hellborne, +1 Aether
    "SurgingElites",           -- Chance for Elite Doubled, Aether Fiends grant +1 Aether
    "BlisteringHordes",        -- Normal Monster Spawn Aether Events 50% Faster
    "EmpoweredElites",         -- Elite damage +25%, Aether Fiends grant +1 Aether
    "UnstoppableElites",       -- Elites are Unstoppable, Aether Fiends grant +1 Aether
    "InvigoratingHellborne",   -- Hellborne Damage +25%, Slaying Hellborne Invigorates you
    "InfernalStalker",         -- An Infernal demon has your scent, Slay it to gain +25 Aether
    "AetherRush",              -- Normal Monsters Damage +25%, Gathering Aether Increases Movement Speed
    "IncreasedEvadeCooldown",  -- Increase Evade Cooldown +2 Sec, Council grants +15 Aether
    "IncreasedPotionCooldown", -- Increase potion cooldown +2 Sec, Council Grants +15 Aether
    "ReduceAllResistance",     -- Reduce All Resist -10%, Council grants +15 Aether
    "EmpoweredCouncil",        -- Fell Council +50% Damage, Council grants +15 Aether
    "EmpoweredMasses",         -- Aetheric Mass damage: +25%, Aetheric Mass grants +1 Aether
    "EnergizingMasses",        -- Slaying Aetheric Masses slow you, While slowed this way, you have UNLIMITED RESOURCES
    "ThrivingMasses",          -- Masses deal unavoidable damage, Wave start, spawn an Aetheric Mass
    "DeadlySpires",            -- Soulspires Drain Health, Soulspires grant +2 Aether
    "CorruptingSpires",        -- Soulspires empower nearby foes, they also pull enemies inward
    "GreedySpires",            -- Soulspire requires 2x kills, Soulspires grant 2x Aether
    "UnstableFiends",          -- Elite Damage +25%, Aether Fiends explode and damage FOES
    "RagingHellfire",          -- Hellfire rains upon you, at the end of each wave spawn 1-3 Aether
    "GestatingMasses",         -- Masses spawn an Aether lord on Death, Aether Lords Grant +3 Aether
    "InfernalLords"            -- Aether Lords Now Spawn, they grant +3 Aether
}

local pylon_priority = {}
for i, pylon in ipairs(pylons) do
    pylon_priority[pylon] = i
end

function pylon_logic.get_pylons()
    local highest_priority_actor = nil
    local highest_priority = #pylons + 1

    for _, actor in pairs(actors_manager:get_all_actors()) do
        local name = actor:get_skin_name()
        if name:match("BSK_Pyl") then
            for pylon, priority in pairs(pylon_priority) do
                if name:match(pylon) and priority < highest_priority then
                    highest_priority = priority
                    highest_priority_actor = actor
                end
            end
        end
    end

    return highest_priority_actor
end

function pylon_logic.can_interact_with_pylon(cooldown)
    local current_time = get_time_since_inject()
    return current_time - tracker.last_pylon_interaction_time >= cooldown
end

function pylon_logic.handle_pylon_interaction(target, cooldown)
    if utils.distance_to(target) > 2 then
        pathfinder.force_move_raw(target:get_position())
        return false
    elseif pylon_logic.can_interact_with_pylon(cooldown) then
        interact_object(target)
        tracker.last_pylon_interaction_time = get_time_since_inject()
        console.print("Interacted with pylon, now idling for cooldown")
        return true
    else
        console.print("Idling while waiting for pylon cooldown")
        return false
    end
end

return pylon_logic