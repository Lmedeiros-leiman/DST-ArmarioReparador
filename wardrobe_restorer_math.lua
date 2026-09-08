-- Pure durability-recovery math for wardrobe_restorer.
-- Loaded by modmain via modimport and by test/test_recover.lua via loadfile.

local M = {}

-- A full DST day cycle is 16 segments of 30 seconds.
M.DAY_LENGTH_SECONDS = 480

-- The game ships backgrounds through 5x4 only. Larger grids reuse that
-- background and intentionally leave their extra slots unframed.
local SLOT_LAYOUTS =
{
    [4]  = { num_slots = 4,  cols = 2, spacing = 80, bank = "ui_chest_3x3",        pos_y = 200 },
    [9]  = { num_slots = 9,  cols = 3, spacing = 80, bank = "ui_chest_3x3",        pos_y = 200 },
    [16] = { num_slots = 16, cols = 4, spacing = 80, bank = "ui_boat_ancient_4x4", pos_y = 200 },
    [20] = { num_slots = 20, cols = 5, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 220 },
    [25] = { num_slots = 25, cols = 5, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 257.5 },
    [36] = { num_slots = 36, cols = 6, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 295 },
    [49] = { num_slots = 49, cols = 7, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 332.5 },
}

local function is_positive(value)
    return type(value) == "number" and value > 0
end

-- Durability units recovered for an item with `max_amount` total durability,
-- at `rate_per_day` percent per day, over `dt` seconds.
function M.recovery_delta(max_amount, rate_per_day, dt, day_length)
    if not is_positive(max_amount) or not is_positive(rate_per_day) or not is_positive(dt) then
        return 0
    end
    local day = is_positive(day_length) and day_length or M.DAY_LENGTH_SECONDS
    return max_amount * (rate_per_day / 100) * (dt / day)
end

-- New durability value after one step, clamped to the item's maximum.
function M.recover(current, max_amount, rate_per_day, dt, day_length)
    local next_value = current + M.recovery_delta(max_amount, rate_per_day, dt, day_length)
    if next_value > max_amount then
        next_value = max_amount
    end
    return next_value
end

-- Storage filter: equipment may be stored, perishables may not.
function M.accepts_item(is_equippable, is_perishable)
    return is_equippable == true and is_perishable ~= true
end

-- Returns the supported UI specification for a configuration value. A copy
-- keeps callers from mutating the shared layout table.
function M.get_slot_layout(num_slots)
    local layout = SLOT_LAYOUTS[num_slots] or SLOT_LAYOUTS[20]
    return {
        num_slots = layout.num_slots,
        cols = layout.cols,
        spacing = layout.spacing,
        bank = layout.bank,
        pos_y = layout.pos_y,
    }
end

-- Slot coordinates for a num_slots grid with the given column count and
-- spacing, row-major from the top-left, centered on (0, 0). Reproduces the
-- vanilla chest (9x80), ancient 4x4 (16x80), and fish box (20x75) layouts.
function M.build_grid(num_slots, cols, spacing)
    local grid = {}
    if type(num_slots) ~= "number" or num_slots < 1
        or type(cols) ~= "number" or cols < 1 then
        return grid
    end
    local s = type(spacing) == "number" and spacing or 80
    local rows = math.ceil(num_slots / cols)
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            if #grid < num_slots then
                grid[#grid + 1] = {
                    x = s * (c - (cols - 1) / 2),
                    y = s * ((rows - 1) / 2 - r),
                }
            end
        end
    end
    return grid
end

-- modimport discards return values, so modmain reads the module from this
-- global in the shared mod env.
wardrobe_restorer_math = M

return M
