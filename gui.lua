local gui = {}
local plugin_label = "Infernal Horde - Finn Edition"

local function create_checkbox(key)
    return checkbox:new(false, get_hash(plugin_label .. "_" .. key))
end

gui.chest_types_options = {
    "Gear",
    "Materials",
    "Gold",
}

-- Add chest types enum
gui.chest_types_enum = {
    GEAR = 0,
    MATERIALS = 1,
    GOLD = 2,
}

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox("main_toggle"),
    chest_type_selector = combo_box:new(0, get_hash("chest_type_selector")),
    always_open_ga_chest = create_checkbox("always_open_ga_chest"),
}

function gui.render()
    if not gui.elements.main_tree:push("Infernal Horde - Finn Edition") then return end

    gui.elements.main_toggle:render("Enable", "Enable the bot")
    
    -- Updated chest type selector to use the new enum structure
    gui.elements.always_open_ga_chest:render("Always Open GA Chest", "Toggle to always open Greater Affix chest when available")
    gui.elements.chest_type_selector:render("Chest Type", gui.chest_types_options, "Select the type of chest to open")



    gui.elements.main_tree:pop()
end

return gui