local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"
local explorer = require "core.explorer"

local MAX_ATTEMPTS = 5
local ATTEMPT_DELAY = 5 -- seconds
local POWERSHELL_WAIT_TIME = 3 -- seconds
local horde_portal_coords = vec3:new(30.581279754639, -477.47695922852, -24.44921875)

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

local function enter_horde(portal)
    if portal and utils.distance_to(portal) < 2 then
        console.print("Player is close enough to the portal. Interacting with the portal.")
        interact_object(portal)
        return true
    end
    return false
end

local enter_horde_task = {
    name = "Enter Horde",
    co = nil,

    shouldExecute = function()
        return utils.player_in_zone("Kehj_Caldeum")
            and tracker.sigil_used
            and not tracker.horde_entered 
    end,
    
    Execute = function(self)
        if not self.co or coroutine.status(self.co) == "dead" then
            self.co = coroutine.create(function()
                while tracker.horde_attempt_count < MAX_ATTEMPTS and not tracker.horde_opened do
                    tracker.horde_attempt_count = tracker.horde_attempt_count + 1
                    console.print("Attempt " .. tracker.horde_attempt_count .. " to open horde portal")

                    if execute_powershell_script() then
                        -- Wait for PowerShell script to potentially open the portal
                        for i = 1, POWERSHELL_WAIT_TIME * 10 do  -- 10 checks per second
                            coroutine.yield()
                            if utils.get_horde_portal() then
                                tracker.horde_opened = true
                                break
                            end
                        end

                        if tracker.horde_opened then
                            console.print("Horde portal opened successfully.")
                            break
                        else
                            console.print("Portal did not open. Will retry.")
                        end
                    else
                        console.print("PowerShell script execution failed. Will retry.")
                    end

                    -- Wait before next attempt
                    for i = 1, ATTEMPT_DELAY * 10 do  -- 10 yields per second
                        coroutine.yield()
                    end
                end

                if tracker.horde_opened then
                    while not tracker.horde_entered do
                        local portal = utils.get_horde_portal()
                        if portal then
                            local distance_to_portal = utils.distance_to(portal)
                            if distance_to_portal < 2 then
                                if enter_horde(portal) then
                                    console.print("Successfully entered the horde.")
                                    tracker.horde_entered = true
                                    break
                                end
                            elseif distance_to_portal < 28 then
                                console.print("Moving closer to the portal.")
                                pathfinder.force_move_raw(horde_portal_coords) --path = pathfinder.create_path_game_engine(horde_portal_coords)
                                
                                -- Wait for movement to complete
                                for i = 1, 0 do  -- Wait up to 5 seconds
                                    coroutine.yield()
                                    if utils.distance_to(portal) < 2 then
                                        break
                                    end
                                end
                            else
                                console.print("Please move closer to the portal manually.")
                            end
                        else
                            console.print("Portal not found. Retrying...")
                        end
                        coroutine.yield()  -- Yield to prevent tight loop
                    end
                else
                    console.print("Max attempts reached. Failed to open horde portal.")
                end
            end)
        end

        if coroutine.status(self.co) == "suspended" then
            local success, error = coroutine.resume(self.co)
            if not success then
                console.print("Error in enter_horde_task: " .. tostring(error))
                self.co = nil  -- Reset coroutine on error
            end
        end

        return not tracker.horde_entered
    end
}

return enter_horde_task