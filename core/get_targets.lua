local get_targets = {}

local debug_mode = false
local last_target_switch_time = 0
local current_target = nil
local TARGET_SWITCH_COOLDOWN = 1.0  -- 1 second cooldown

function get_targets.set_debug_mode(mode)
    debug_mode = mode
end

function get_targets.is_valid_enemy(actor)
    local name = actor:get_skin_name()
    
    if name == "BSK_Soulspire" then
        return actor:get_current_health() > 0
    end

    return actor:get_current_health() > 0 and
           actor:is_enemy() and
           not actor:is_untargetable() and
           not actor:is_basic_particle()
end

function get_targets.select_target(source, dist)
    local current_time = get_time_since_inject()
    
    -- Check if we're still in cooldown and if the current target is still valid
    if current_target and current_time - last_target_switch_time < TARGET_SWITCH_COOLDOWN then
        if get_targets.is_valid_enemy(current_target) and source:dist_to(current_target:get_position()) <= dist then
            return current_target
        end
    end

    local targets = {
        Boss = {dist = math.huge},
        HellSeeker = {dist = math.huge},
        Champion = {dist = math.huge},
        Elite = {dist = math.huge},
        Membrane = {dist = math.huge},
        Mass = {dist = math.huge},
        Spire = {dist = math.huge},
        Monster = {dist = math.huge},
    }

    local target_counts = {
        Boss = 0, HellSeeker = 0, Champion = 0, Elite = 0,
        Membrane = 0, Mass = 0, Spire = 0, Monster = 0
    }

    local all_target_names = {}

    local function update_target(target_type, actor, distance)
        if distance < targets[target_type].dist then
            targets[target_type].dist = distance
            targets[target_type].actor = actor
        end
        target_counts[target_type] = target_counts[target_type] + 1
    end

    for _, actor in pairs(actors_manager:get_all_actors()) do
        if get_targets.is_valid_enemy(actor) then
            local distance = source:dist_to(actor:get_position())

            if distance <= dist and not evade.is_dangerous_position(actor:get_position()) then
                local name = actor:get_skin_name()

                if debug_mode then
                    table.insert(all_target_names, name)
                    console.print("Checking actor: " .. name .. " (Current Health: " .. actor:get_current_health() .. ")")
                end

                if actor:is_boss() then
                    update_target("Boss", actor, distance)
                elseif name:match("^BSK_HellSeeker") then
                    update_target("HellSeeker", actor, distance)
                elseif actor:is_champion() then
                    update_target("Champion", actor, distance)
                elseif name == "MarkerLocation_BSK_Occupied" then
                    update_target("Membrane", actor, distance)
                elseif name == "BSK_Structure_BonusAether" then
                    update_target("Mass", actor, distance)
                elseif name == "BSK_Soulspire" then
                    update_target("Spire", actor, distance)
                elseif actor:is_elite() then
                    update_target("Elite", actor, distance)
                else
                    update_target("Monster", actor, distance)
                end
            end
        end
    end

    local selected_target = nil
    for _, target_type in ipairs({"Boss", "HellSeeker", "Champion", "Membrane", "Mass", "Spire", "Elite", "Monster"}) do
        if targets[target_type].actor then
            selected_target = targets[target_type].actor
            break
        end
    end

    if selected_target and selected_target ~= current_target then
        last_target_switch_time = current_time
        current_target = selected_target
    end

    if debug_mode then
        console.print("All targets (" .. #all_target_names .. "): " .. table.concat(all_target_names, ", "))
        console.print("Target counts:")
        for _, target_type in ipairs({"Boss", "HellSeeker", "Champion", "Membrane", "Mass", "Spire", "Elite", "Monster"}) do
            console.print("  " .. target_type .. ": " .. target_counts[target_type])
        end
        if selected_target then
            local selected_health = selected_target:get_current_health()
            console.print("Selected target: " .. selected_target:get_skin_name() .. 
                          " (Type: " .. (selected_target:is_boss() and "Boss" or
                                         selected_target:is_champion() and "Champion" or
                                         selected_target:is_elite() and "Elite" or
                                         targets.HellSeeker.actor == selected_target and "HellSeeker" or
                                         "Normal") .. 
                          ", Health: " .. selected_health .. 
                          ", Distance: " .. string.format("%.2f", source:dist_to(selected_target:get_position())) .. ")")
        else
            console.print("No target selected")
        end
    end

    return selected_target
end

return get_targets