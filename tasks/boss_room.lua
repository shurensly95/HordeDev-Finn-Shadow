local utils = require "core.utils"
local tracker = require "core.tracker"
local get_targets = require "core.get_targets"

local boss_room = {
    is_task_running = false,
    boss_room_coroutine = nil,
    max_boss_spawn_wait_time = 30,
}

local horde_boss_room_position = vec3:new(-36.17675, -36.3222, 2.200)

function boss_room:ensure_in_boss_position()
    if utils.distance_to(horde_boss_room_position) > 1 then
        pathfinder.force_move_raw(horde_boss_room_position)
        return false
    end
    return true
end

function boss_room:get_boss_count()
    local boss_count = 0
    for _, actor in pairs(actors_manager:get_all_actors()) do
        if actor:is_boss() then
            boss_count = boss_count + 1
        end
    end
    return boss_count
end

function boss_room:boss_room_wait_coroutine()
    return coroutine.create(function()
        local wait_start_time = get_time_since_inject()
        
        while true do
            local current_time = get_time_since_inject()
            local elapsed_time = current_time - wait_start_time
            
            if self:get_boss_count() > 0 then
                console.print("Bosses detected. Exiting wait state.")
                break
            elseif elapsed_time >= self.max_boss_spawn_wait_time then
                console.print("Max wait time reached. Exiting boss room.")
                tracker.horde_completed = true
                break
            end
            
            if self:ensure_in_boss_position() then
                console.print("Waiting for bosses to spawn... Time: " .. string.format("%.1f", elapsed_time))
            end
            
            coroutine.yield()
        end
    end)
end

function boss_room:handle_boss_room_actions(action)
    if not self.boss_room_coroutine or coroutine.status(self.boss_room_coroutine) == "dead" then
        self.boss_room_coroutine = self:boss_room_wait_coroutine()
    end

    if action == "wait_for_bosses" or action == "post_boss_wait" then
        local status, result = coroutine.resume(self.boss_room_coroutine)
        if not status then
            console.print("Error in boss room coroutine: " .. tostring(result))
        end
    elseif action == "boss_fight" then
        local player_pos = get_player_position()
        if player_pos then
            local target = get_targets.select_target(player_pos, 25)
            if target and utils.distance_to(target) > 1 then
                pathfinder.force_move_raw(target:get_position())
            else
                console.print("Fighting Boss")
            end
        else
            console.print("Error: Unable to get player position")
        end
    end
end

function boss_room:determine_action()
    local boss_count = self:get_boss_count()
    if boss_count > 0 then
        return "boss_fight"
    elseif not tracker.horde_completed then
        return "wait_for_bosses"
    else
        return "post_boss_wait"
    end
end

function boss_room:main_pulse()
    if get_local_player():is_dead() then
        console.print("Player is dead. Reviving at checkpoint.")
        revive_at_checkpoint()
        return
    end

    local action = self:determine_action()
    self:handle_boss_room_actions(action)

    if tracker.horde_completed then
        self.is_task_running = false
    end
end

local task = {
    name = "Boss Room",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02")
            and not utils.get_stash() 
            and tracker.in_boss_room
    end,
    
    Execute = function()
        if not boss_room.is_task_running then 
            boss_room.is_task_running = true
        end
        boss_room:main_pulse()
    end
}

return task