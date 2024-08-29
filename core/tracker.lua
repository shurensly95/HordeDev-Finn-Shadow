local tracker = {
    finished_time = 0,
    pit_start_time = 0,
    start_dungeon_time = nil,
    horde_opened = false,
    horde_entered = false,
    horde_completed = false,
    first_run = false,
    wave_start_time = 0,
    all_waves_cleared = false,
    last_pylon_interaction_time = 0,
    pre_boss_loot_started = false,
    pre_boss_loot_start_time = 0,
    pre_boss_loot_completed = false,
    moved_to_center = false,
    aether_route_calculated = false,
    aether_route = nil,
    in_boss_room = false,
    boss_room_unlocked = false,
    boss_fight_started = false,
    post_boss_wait_start = 0,
    exit_horde_start_time = nil,
    exit_horde_completion_time = 0,
    exit_horde_completed = false,
    aether_collected = false,
    ga_chest_opened = false,
    selected_chest_opened = false,
    gold_chest_opened = false,
    finished_chest_looting = false,
    has_salvaged = false,
    powershell_executed = false,
    powershell_execute_time = 0,
    horde_attempt_count = 0,
    last_horde_attempt_time = 0,
}

function tracker.reset_horde_trackers()
    tracker.sigil_used = false
    tracker.horde_opened = false
    tracker.horde_entered = false
    tracker.horde_completed = false
    tracker.first_run = false
    tracker.wave_start_time = 0
    tracker.all_waves_cleared = false
    tracker.last_pylon_interaction_time = 0
    tracker.pre_boss_loot_started = false
    tracker.pre_boss_loot_start_time = 0
    tracker.pre_boss_loot_completed = false
    tracker.moved_to_center = false
    tracker.aether_route_calculated = false
    tracker.aether_route = nil
    tracker.in_boss_room = false
    tracker.boss_room_unlocked = false
    tracker.boss_fight_started = false
    tracker.post_boss_wait_start = 0
    tracker.exit_horde_start_time = nil
    tracker.exit_horde_completion_time = 0
    tracker.exit_horde_completed = false
end

function tracker.reset_chest_trackers()
    tracker.aether_collected = false
    tracker.ga_chest_opened = false
    tracker.selected_chest_opened = false
    tracker.gold_chest_opened = false
    tracker.finished_chest_looting = false
end

function tracker.reset_salvage_trackers()
    tracker.has_salvaged = false
end

function tracker.reset_horde_attempt_trackers()
    tracker.horde_attempt_count = 0
    tracker.last_horde_attempt_time = 0
    tracker.powershell_executed = false
    tracker.powershell_execute_time = 0
    tracker.horde_entered = false
end

function tracker.reset_all()
    tracker.reset_horde_trackers()
    tracker.reset_chest_trackers()
    tracker.reset_salvage_trackers()
    tracker.reset_horde_attempt_trackers()
    tracker.start_dungeon_time = nil
    tracker.pit_start_time = 0
    tracker.finished_time = 0
end

function tracker.check_time(key, delay)
    local current_time = get_time_since_inject()
    if not tracker[key] or current_time - tracker[key] >= delay then
        tracker[key] = current_time
        return true
    end
    return false
end

return tracker
