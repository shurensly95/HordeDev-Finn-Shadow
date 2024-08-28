local gui = require "gui"
local settings = {
    enabled = false,
    reset_time = 1, -- Default to 1
    selected_chest_type = 1, -- GEAR = 0, MATERIALS = 1, GOLD = 2
}

function settings:update_settings()
    settings.enabled = gui.elements.main_toggle:get()
    settings.selected_chest_type = gui.elements.chest_type_selector:get()
    settings.always_open_ga_chest = gui.elements.always_open_ga_chest:get()
end

return settings