local utils = require "core.utils"
local enums = require "data.enums"
local settings = require "core.settings"
local tracker = require "core.tracker"

local explorer = {
    enabled = false,
    is_task_running = false,
    grid_size = 1.5,
    exploration_radius = 10,
    max_target_distance = 120,
    stuck_threshold = 10,
    unstuck_target_distance = 15,
    max_last_targets = 50
}

local explored_areas = {}
local target_position = nil
local last_position = nil
local last_move_time = 0
local last_explored_targets = {}

local explored_area_bounds = {
    min_x = math.huge, max_x = -math.huge,
    min_y = math.huge, max_y = -math.huge,
    min_z = math.huge, max_z = -math.huge
}

local function get_grid_key(point)
    return string.format("%d,%d,%d",
        math.floor(point:x() / explorer.grid_size),
        math.floor(point:y() / explorer.grid_size),
        math.floor(point:z() / explorer.grid_size)
    )
end

local function update_explored_area_bounds(point, radius)
    explored_area_bounds.min_x = math.min(explored_area_bounds.min_x, point:x() - radius)
    explored_area_bounds.max_x = math.max(explored_area_bounds.max_x, point:x() + radius)
    explored_area_bounds.min_y = math.min(explored_area_bounds.min_y, point:y() - radius)
    explored_area_bounds.max_y = math.max(explored_area_bounds.max_y, point:y() + radius)
    explored_area_bounds.min_z = math.min(explored_area_bounds.min_z, point:z() - radius)
    explored_area_bounds.max_z = math.max(explored_area_bounds.max_z, point:z() + radius)
end

local function mark_area_as_explored(center, radius)
    update_explored_area_bounds(center, radius)
    local grid_key = get_grid_key(center)
    explored_areas[grid_key] = true
end

local function is_point_walkable(point)
    return utility.is_point_walkeable(utility.set_height_of_valid_position(point))
end

local function find_target(exploration_mode)
    local player_pos = get_player_position()
    local check_radius = explorer.max_target_distance
    local best_target = nil
    local best_distance = math.huge

    for x = -check_radius, check_radius, explorer.grid_size do
        for y = -check_radius, check_radius, explorer.grid_size do
            local point = vec3:new(player_pos:x() + x, player_pos:y() + y, player_pos:z())
            point = utility.set_height_of_valid_position(point)
            local grid_key = get_grid_key(point)

            if is_point_walkable(point) and 
               ((exploration_mode == "unexplored" and not explored_areas[grid_key]) or
                (exploration_mode == "explored" and explored_areas[grid_key])) then
                
                local distance = player_pos:dist_to_ignore_z(point)
                if distance < best_distance then
                    best_distance = distance
                    best_target = point
                end
            end
        end
    end

    return best_target
end

function explorer:check_if_stuck()
    local player_pos = get_player_position()
    if last_position and player_pos:dist_to_ignore_z(last_position) < self.stuck_threshold then
        local time_since_last_move = get_time_since_inject() - last_move_time
        if time_since_last_move > self.unstuck_target_distance then
            return true
        end
    end
    return false
end

function explorer:clear_path_and_target()
    target_position = nil
end

function explorer:move_to_target()
    if target_position then
        pathfinder.force_move_raw(target_position)
    else
        console.print("No target position set.")
    end
end

function explorer:set_custom_target(pos)
    target_position = pos
    if type(pos) == "userdata" and pos.x and pos.y and pos.z then
        console.print(string.format("Custom target set to: x=%.2f, y=%.2f, z=%.2f", pos:x(), pos:y(), pos:z()))
    else
        console.print("Custom target set (unable to display coordinates)")
    end
end

function explorer:update()
    local current_time = get_time_since_inject()
    local player_pos = get_player_position()

    -- Check and reset dungeons if necessary
    if tracker.pit_start_time > 0 then
        local time_spent_in_pit = current_time - tracker.pit_start_time
        if time_spent_in_pit > settings.reset_time then
            console.print("Time spent in pit exceeds limit. Resetting all dungeons.")
            reset_all_dungeons()
        end
    end

    -- Mark current area as explored
    mark_area_as_explored(player_pos, self.exploration_radius)

    -- Check if stuck and find new target if necessary
    if self:check_if_stuck() then
        self:clear_path_and_target()
        target_position = find_target("unexplored") or find_target("explored")
        if target_position then
            console.print("Stuck detected. Moving to new target position.")
            self:move_to_target()
        else
            console.print("No valid targets found. Exploration halted.")
        end
    end

    -- Move towards target if set
    if target_position then
        self:move_to_target()
    end

    -- Update position and time
    last_position = player_pos
    last_move_time = current_time
end

return explorer