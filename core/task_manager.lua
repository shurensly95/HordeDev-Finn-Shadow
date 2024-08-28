local settings = require "core.settings"
local tracker = require "core.tracker"
local utils = require "core.utils"

local task_manager = {}
local tasks = {}
local current_task = { name = "Idle" }
local finished_time = 0
local flags_reset = true  -- Initial state set to true
local last_call_time = 0  -- Initialize last_call_time here
local initial_reset_done = false  -- Flag to track if the initial reset has been performed


function task_manager.set_finished_time(time)
    finished_time = time
end

function task_manager.get_finished_time()
    return finished_time
end

function task_manager.register_task(task)
    table.insert(tasks, task)
end

function task_manager.reset_flags_if_needed()
    if not flags_reset then
        tracker.reset_all()
        console.print("All flags have been reset at the start of the new run.")
        flags_reset = true
    end
end


function task_manager.execute_tasks()
    local current_core_time = get_time_since_inject()

    -- Reset flags if it's the start of the program or a new run
    if not initial_reset_done then
        if utils.player_in_zone("Kehj_Caldeum") and not utils.get_horde_portal() then
            tracker.reset_all()
            console.print("All flags have been reset at the start of the program.")
            initial_reset_done = true
        end
    else
        -- Reset flags if a new run starts after the initial reset
        if utils.player_in_zone("Kehj_Caldeum") and tracker.exit_horde_completed then
            tracker.reset_all()
            console.print("All flags have been reset at the start of the new run.")
            flags_reset = true
        elseif not utils.player_in_zone("Kehj_Caldeum") or tracker.horde_opened then
            -- Allow flags to be reset again if not in the target zone or if the horde is opened
            flags_reset = false
        end
    end

    -- Check if enough time has passed since the last task execution
    if current_core_time - last_call_time < 0.2 then
        return -- Avoid executing tasks too frequently
    end

    last_call_time = current_core_time

    local is_exit_or_finish_active = false
    for _, task in ipairs(tasks) do
        if task.shouldExecute() then
            current_task = task
            task:Execute()
            break -- Execute only one task per pulse
        end
    end

    current_task = current_task or { name = "Idle" }
end



function task_manager.get_current_task()
    return current_task
end

local task_files = {"open_chests", "exit_horde", "start_dungeon", "enter_horde", "horde", "boss_room"}
for _, file in ipairs(task_files) do
    local task = require("tasks." .. file)
    task_manager.register_task(task)
end

return task_manager
