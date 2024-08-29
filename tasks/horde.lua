local utils = require "core.utils"
local enums = require "data.enums"
local settings = require "core.settings"
local tracker = require "core.tracker"
local get_targets = require "core.get_targets"
local pylon_logic = require "core.pylon_logic"

-- Set debug mode
get_targets.set_debug_mode(false)

local horde = {
    state = "idle",
    pylon_interaction_cooldown = 2.5,
    loot_scan_radius = 50,
    aether_collection_timeout = 15,
    is_task_running = false,
}

local horde_center_position = vec3:new(9.204102, 8.915039, 0.000000)
local horde_boss_room_position = vec3:new(-36.17675, -36.3222, 2.200)
local pre_boss_position = vec3:new(3.6182880401611, 3.7063026428223, 0)

local current_move_index = 1

local move_positions = {
    horde_center_position,
    vec3:new(19.5658, -1.5756, 0.6289),
    horde_center_position,
    vec3:new(20.17866, 17.897891, 0.24707),
    horde_center_position,
    vec3:new(0.24825286, 20.6410, 0.4697),
    horde_center_position,
}

-- Circle movement data
local circle_data = {
    radius = 12,
    steps = 15,
    delay = 0.01,
    current_step = 1,
    last_action_time = 0,
    height_offset = 1,
    center_x = horde_center_position:x(),
    center_y = horde_center_position:y(),
    center_z = horde_center_position:z()
}

local function shoot_in_circle()
    local current_time = get_time_since_inject()
    if current_time - circle_data.last_action_time < circle_data.delay then return end

    local angle = (circle_data.current_step / circle_data.steps) * (2 * math.pi)
    local cos_angle, sin_angle = math.cos(angle), math.sin(angle)

    local new_position = vec3:new(
        circle_data.center_x + circle_data.radius * cos_angle,
        circle_data.center_y + circle_data.height_offset * sin_angle,
        circle_data.center_z + circle_data.radius * sin_angle
    )

    pathfinder.force_move_raw(new_position)

    circle_data.last_action_time = current_time
    circle_data.current_step = (circle_data.current_step % circle_data.steps) + 1
end



function horde:patrol()
    local target_position = move_positions[current_move_index]
    if utils.distance_to(target_position) > 1 then
        pathfinder.force_move_raw(target_position)
    else
        current_move_index = (current_move_index % #move_positions) + 1
    end
end


function horde:all_waves_cleared()
    for _, actor in pairs(actors_manager:get_all_actors()) do
        local skin_name = actor:get_skin_name()
        if skin_name == "BSK_MapIcon_LockedDoor" or get_targets.is_valid_enemy(actor) then
            return false
        end
    end
    tracker.all_waves_cleared = true
    return true
end

function horde:get_locked_door()
    local is_locked, in_wave = false, false
    local door_actor = nil

    for _, actor in pairs(actors_manager:get_all_actors()) do
        local name = actor:get_skin_name()
        if name == "BSK_MapIcon_LockedDoor" then is_locked = true
        elseif name == "Hell_Fort_BSK_Door_A_01_Dyn" then door_actor = actor
        elseif name == "DGN_Standard_Door_Lock_Sigil_Ancients_Zak_Evil" then in_wave = true end
    end

    return not in_wave and is_locked and door_actor
end

function horde:get_aether_actors()
    local aether_actors = {}
    for _, actor in pairs(actors_manager:get_all_actors()) do
        local name = actor:get_skin_name()
        if name == "BurningAether" then
            table.insert(aether_actors, actor)
        end
    end
    return aether_actors
end

function horde:calculate_optimal_aether_route(aether_actors)
    local player_pos = get_player_position()
    table.sort(aether_actors, function(a, b)
        return player_pos:dist_to(a:get_position()) < player_pos:dist_to(b:get_position())
    end)
    return aether_actors
end

function horde:perform_pre_boss_loot()
    local current_time = get_time_since_inject()
    
    if not tracker.pre_boss_loot_started then
        tracker.pre_boss_loot_started = true
        tracker.pre_boss_loot_start_time = current_time
        console.print("Starting pre-boss loot phase")
        return
    end
    
    if not tracker.moved_to_center then
        if utils.distance_to(horde_center_position) > 2 then
            pathfinder.force_move_raw(horde_center_position)
        else
            tracker.moved_to_center = true
            console.print("Reached center position, scanning for aether")
        end
        return
    end
    
    if not tracker.aether_route_calculated then
        local aether_actors = self:get_aether_actors()
        if #aether_actors > 0 then
            tracker.aether_route = self:calculate_optimal_aether_route(aether_actors)
            tracker.aether_route_calculated = true
            console.print("Calculated optimal aether route with " .. #tracker.aether_route .. " points")
        else
            console.print("No aether found, moving to pre-boss position")
            tracker.pre_boss_loot_completed = true
        end
        return
    end
    
    if tracker.aether_route and #tracker.aether_route > 0 then
        local current_aether = tracker.aether_route[1]
        if current_aether and utils.distance_to(current_aether) > 2 then
            pathfinder.force_move_raw(current_aether:get_position())
        else
            table.remove(tracker.aether_route, 1)
            console.print("Collected aether, " .. #tracker.aether_route .. " points remaining")
        end
    elseif utils.distance_to(pre_boss_position) > .5 then
        pathfinder.force_move_raw(pre_boss_position)
    else
        tracker.pre_boss_loot_completed = true
        console.print("Pre-boss loot completed, ready to enter boss room")
    end
    
    if current_time - tracker.pre_boss_loot_start_time > self.aether_collection_timeout then
        tracker.pre_boss_loot_completed = true
        console.print("Pre-boss loot timeout reached, moving to boss room")
    end
end

function horde:determine_next_action()
    local pylon = pylon_logic.get_pylons()
    local locked_door = self:get_locked_door()
    local player_pos = get_player_position()
    local target = get_targets.select_target(player_pos, 25)
    local aether = utils.get_aether_actor()

    if pylon then return "interact_pylon", pylon
    elseif aether then return "collect_aether", aether
    elseif locked_door and not tracker.pre_boss_loot_completed then return "pre_boss_loot"
    elseif locked_door then return "interact_door", locked_door
    elseif target then return "attack_target", target
    elseif self:all_waves_cleared() and not aether and tracker.boss_room_unlocked then return "move_to_boss_room"
    else return "patrol" end
end

function horde:handle_actions(action, target)
    if action == "interact_pylon" then
        pylon_logic.handle_pylon_interaction(target, self.pylon_interaction_cooldown)
    elseif action == "interact_door" then
        if utils.distance_to(target) > 2 then
            pathfinder.force_move_raw(target:get_position())
        else
            interact_object(target)
            tracker.boss_room_unlocked = true
            console.print("Boss room unlocked")
        end
    elseif action == "attack_target" or action == "collect_aether" then
        if target and utils.distance_to(target) > 1 then
            pathfinder.force_move_raw(target:get_position())
        else
            shoot_in_circle()
        end
        
    elseif action == "pre_boss_loot" then
        self:perform_pre_boss_loot()
    elseif action == "move_to_boss_room" then
        if utils.distance_to(horde_boss_room_position) > 1 then
            pathfinder.force_move_raw(horde_boss_room_position)
        else
            tracker.in_boss_room = true
            console.print("Reached boss room position")
        end
    elseif action == "patrol" then
        self:patrol()
    end
end

function horde:main_pulse()
    if get_local_player():is_dead() then
        console.print("Player is dead. Reviving at checkpoint.")
        revive_at_checkpoint()
        return
    end

    local action, target = self:determine_next_action()

    if action ~= self.state then
        console.print("Changing state from " .. self.state .. " to " .. action)
        self.state = action
    end

    self:handle_actions(action, target)

    if tracker.in_boss_room then
        self.is_task_running = false
    end
end

local task = {
    name = "Infernal Horde",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") 
            and not utils.get_stash()
            and not tracker.in_boss_room
    end,
    Execute = function()
        if not horde.is_task_running then
            horde.is_task_running = true
        end
        horde:main_pulse()
    end
}

return task