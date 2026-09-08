-- Pure durability-recovery math for wardrobe_restorer.
-- Loaded by modmain via modimport and by test/test_recover.lua via loadfile.

local M = {}

-- A full DST day cycle is 16 segments of 30 seconds.
M.DAY_LENGTH_SECONDS = 480

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
