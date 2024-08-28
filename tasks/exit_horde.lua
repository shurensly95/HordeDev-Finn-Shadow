local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

local exit_horde_task = {
    name = "Exit Horde",
    
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02")
            and utils.get_stash()
            and tracker.finished_chest_looting
            and not tracker.exit_horde_completed
    end,
    
    Execute = function()
        local current_time = get_time_since_inject()

        if not tracker.exit_horde_start_time then
            tracker.exit_horde_start_time = current_time
            console.print("Starting 5-second timer before exiting Horde")
            return
        end
       
        local elapsed_time = current_time - tracker.exit_horde_start_time
        if elapsed_time >= 5 then
            console.print("5-second timer completed. Resetting all dungeons")
            reset_all_dungeons()
            tracker.exit_horde_completed = true
            console.print("Horde exit completed")
        else
            console.print(string.format("Waiting to exit Horde. Time remaining: %.2f seconds", 5 - elapsed_time))
        end
    end
}

return exit_horde_task