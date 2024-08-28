local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"
local explorer = require "core.explorer"

local MAX_ATTEMPTS = 5
local ATTEMPT_DELAY = 5 -- seconds
local POWERSHELL_WAIT_TIME = 1 -- seconds

local function execute_powershell_script()
    local script_path = "C:\\users\\finnd\\desktop\\diablo_qqt\\scripts\\HordeDev-Finn\\send_key.ps1"
    local command = string.format('start /b powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%s"', script_path)
    
    local result = os.execute(command)
    if result then
        console.print("PowerShell script execution initiated.")
        return true
    else
        console.print("Failed to initiate PowerShell script execution")
        return false
    end
end

local function enter_horde()
    local portal = utils.get_horde_portal()
    if portal then
        if utils.distance_to(portal) < 2 then
            console.print("Player is close enough to the portal. Interacting with the portal.")
            interact_object(portal)
            return true
        else
            console.print("Moving closer to the portal.")
            explorer.move_to(portal)
            return false
        end
    else
        console.print("Portal Not found!")
        return false
    end
end

local enter_horde_task = {
    name = "Enter Horde",
    shouldExecute = function()
        return utils.player_in_zone("Kehj_Caldeum")
            and not tracker.horde_entered 
            and tracker.horde_attempt_count < MAX_ATTEMPTS
    end,
    
    Execute = function()
        local current_time = get_time_since_inject()

        -- Check if it's time for a new attempt
        if current_time - tracker.last_horde_attempt_time < ATTEMPT_DELAY then
            return
        end

        -- Check if max attempts reached
        if tracker.horde_attempt_count >= MAX_ATTEMPTS then
            console.print("Max attempts reached. Aborting Enter Horde task.")
            tracker.horde_entered = true
            return
        end

        -- Start a new attempt
        if not tracker.powershell_executed then
            tracker.horde_attempt_count = tracker.horde_attempt_count + 1
            tracker.last_horde_attempt_time = current_time
            console.print("Attempt " .. tracker.horde_attempt_count .. " to enter horde")

            if execute_powershell_script() then
                tracker.powershell_executed = true
                tracker.powershell_execute_time = current_time
            else
                -- If PowerShell script fails to execute, reset for retry
                tracker.powershell_executed = false
                tracker.powershell_execute_time = 0
            end
            return
        end

        -- Wait a short time after executing PowerShell before trying to enter horde
        if current_time - tracker.powershell_execute_time < POWERSHELL_WAIT_TIME then
            return
        end

        -- Try to enter the horde
        local horde_entered = enter_horde()
        if horde_entered then
            console.print("Successfully interacted with portal.")
            tracker.horde_entered = true
        else
            console.print("Failed to interact with portal or portal not found. Will retry.")
            -- Reset PowerShell execution status for retry
            tracker.powershell_executed = false
            tracker.powershell_execute_time = 0
        end
    end
}

return enter_horde_task