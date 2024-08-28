local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

local function wait_for(seconds)
    local start_time = get_time_since_inject()
    while get_time_since_inject() - start_time < seconds do
        coroutine.yield()
    end
end

local open_chests_task = {
    name = "Open Chests",
    co = nil,
    state = "idle",

    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") 
        and utils.get_stash() 
        and not tracker.finished_chest_looting
    end,

    get_aether_actors = function()
        local aether_actors = {}
        for _, actor in pairs(actors_manager:get_all_actors()) do
            local name = actor:get_skin_name()
            if name == "BurningAether" or name == "S05_Reputation_Experience_PowerUp_Actor" then
                table.insert(aether_actors, actor)
            end
        end
        return aether_actors
    end,

    aether_exists = function(self, aether)
        for _, actor in pairs(actors_manager:get_all_actors()) do
            if actor == aether then
                return true
            end
        end
        return false
    end,

    collect_aether = function(self)
        local collection_start_time = get_time_since_inject()
        local collection_timeout = 10  -- 10 seconds timeout for aether collection
        local max_aether_distance = 20  -- Maximum distance to travel for aether
        local check_interval = 0.5  -- Check for aether every 0.5 seconds
        local no_aether_count = 0  -- Counter for consecutive checks with no aether
        local max_no_aether_checks = 3  -- Maximum number of consecutive checks with no aether before moving on
    
        console.print("Starting aether collection")
    
        while get_time_since_inject() - collection_start_time < collection_timeout do
            local aether_actors = self:get_aether_actors()
            local player_pos = get_player_position()
            
            -- Filter aether actors by distance
            local nearby_aether = {}
            for _, aether in ipairs(aether_actors) do
                if player_pos:dist_to(aether:get_position()) <= max_aether_distance then
                    table.insert(nearby_aether, aether)
                end
            end
            
            if #nearby_aether == 0 then
                no_aether_count = no_aether_count + 1
                console.print("No nearby aether found. Check " .. no_aether_count .. " of " .. max_no_aether_checks)
                
                if no_aether_count >= max_no_aether_checks then
                    console.print("No aether found after multiple checks. Moving to open chests.")
                    return
                end
                
                wait_for(check_interval)
            else
                no_aether_count = 0  -- Reset the counter when aether is found
                
                for _, aether in ipairs(nearby_aether) do
                    local distance = player_pos:dist_to(aether:get_position())
                    if distance > 2 and distance <= max_aether_distance then
                        console.print("Moving to collect nearby aether")
                        pathfinder.request_move(aether:get_position())
                        wait_for(check_interval)
                        
                        -- Recheck aether existence after movement
                        if not self:aether_exists(aether) then
                            console.print("Aether no longer exists, stopping movement")
                            break
                        end
                    elseif distance <= 2 then
                        console.print("Interacting with aether")
                        interact_object(aether)
                        wait_for(check_interval)
                    end
                    
                    -- Break the loop to recheck all aether after each interaction or movement
                    break
                end
            end
        end
    
        console.print("Aether collection completed or timed out. Moving to open chests.")
    end,

    open_specific_chest = function(self, chest, chest_type, allow_multiple)
        console.print("Moving to " .. chest_type .. " chest.")
        while utils.distance_to(chest) > 2 do
            pathfinder.request_move(chest:get_position())
            coroutine.yield()
        end

        console.print("Attempting to open " .. chest_type .. " chest.")
        local max_attempts = allow_multiple and 1 or 3 -- More attempts for multiple-open chests
        local chest_opened = false

        for attempt = 1, max_attempts do
            interact_object(chest)

            -- Wait for the chest opening animation
            local start_time = get_time_since_inject()
            local vfx_found = false
            while get_time_since_inject() - start_time < 5 do -- Wait up to 5 seconds for VFX
                for _, actor in pairs(actors_manager:get_all_actors()) do
                    local name = actor:get_skin_name()
                    if name == "vfx_resplendentChest_coins" or name == "vfx_resplendentChest_lightRays" or name:match("g_gold") then
                        vfx_found = true
                        break
                    end
                end
                if vfx_found then break end
                wait_for(0.1) -- Check every 100ms
            end

            if vfx_found then
                console.print(chest_type .. " vfx detected.")
                chest_opened = true
                if not allow_multiple then
                    break
                end
                -- For multiple-open chests, continue trying
            else
                if not allow_multiple or attempt == max_attempts then
                    console.print("Failed to open " .. chest_type .. " chest after " .. attempt .. " attempts.")
                    break
                end
                console.print("Chest opening attempt " .. attempt .. " failed. Retrying...")
                wait_for(3) -- Wait before next attempt
            end
        end

        return chest_opened
    end,

    Execute = function(self)
        if not self.co or coroutine.status(self.co) == "dead" then
            self.co = coroutine.create(function()
                self.state = "idle"

                -- Step 1: Idle state for 3 seconds
                console.print("Waiting for 3 seconds for aether to drop...")
                wait_for(3)

                -- Step 2: Aether check
                if not tracker.aether_collected then
                    self.state = "collecting_aether"
                    tracker.aether_collected = self:collect_aether()
                end

                -- Step 3: Update flag after aether collection attempt
                self.state = "opening_chests"

                -- Step 4: Open chests
                local ga_chest_opened = false
                local selected_chest_opened = false
                local gold_chest_opened = false

                -- Open GA chest if setting is enabled
                if settings.always_open_ga_chest then
                    local ga_chest = utils.get_chest(enums.chest_types[3].value)
                    if ga_chest then
                        ga_chest_opened = self:open_specific_chest(ga_chest, "Greater Affix", false)
                        wait_for(2)
                    end
                end

                -- Open selected chest type
                local selected_type = enums.chest_types[settings.selected_chest_type]
                local selected_chest = utils.get_chest(selected_type.value)
                if selected_chest then
                    local is_multi_open = (settings.selected_chest_type == 0 or settings.selected_chest_type == 1)
                    while true do
                        local opened = self:open_specific_chest(selected_chest, selected_type.key, is_multi_open)
                        if opened then
                            selected_chest_opened = true
                            if not is_multi_open then
                                break
                            end
                            wait_for(2)
                        else
                            break
                        end
                    end
                end

                -- Check for Gold chest and open if present
                local gold_chest = utils.get_chest(enums.chest_types[2].value)
                if gold_chest then
                    gold_chest_opened = self:open_specific_chest(gold_chest, "Gold", false)
                else
                    console.print("Gold chest not found. Marking as completed.")
                    gold_chest_opened = true  -- Mark as opened even if not present
                end

                -- Update tracker based on actual results
                tracker.ga_chest_opened = ga_chest_opened
                tracker.selected_chest_opened = selected_chest_opened
                tracker.gold_chest_opened = gold_chest_opened
                tracker.finished_chest_looting = true

                self.state = "completed"
                console.print("Chest opening task completed.")
            end)
        end

        local success, error = coroutine.resume(self.co)
        if not success then
            console.print("Error in open_chests_task: " .. tostring(error))
            self.co = nil -- Reset coroutine on error
            self.state = "error"
        end

        return self.state ~= "completed" and self.state ~= "error"
    end,
}

return open_chests_task
