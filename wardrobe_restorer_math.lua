-- Pure durability-recovery math for wardrobe_restorer.
-- Loaded by modmain via modimport and by test/test_recover.lua via loadfile.

local M = {}

-- A full DST day cycle is 16 segments of 30 seconds.
M.SEGMENT_LENGTH_SECONDS = 30
M.DAY_LENGTH_SECONDS = 480

-- The game ships backgrounds through 5x4 only. Larger grids reuse that
-- background and intentionally leave their extra slots unframed.
-- pos_y is the preferred position, just above the character's head.
-- M.fit_layout moves or shrinks a grid that does not fit the screen.
local SLOT_LAYOUTS =
{
    [4]  = { num_slots = 4,  cols = 2, spacing = 80, bank = "ui_chest_3x3",        pos_y = 200 },
    [9]  = { num_slots = 9,  cols = 3, spacing = 80, bank = "ui_chest_3x3",        pos_y = 200 },
    [16] = { num_slots = 16, cols = 4, spacing = 80, bank = "ui_boat_ancient_4x4", pos_y = 200 },
    [20] = { num_slots = 20, cols = 5, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 220 },
    [25] = { num_slots = 25, cols = 5, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 230 },
    [36] = { num_slots = 36, cols = 6, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 243 },
    [49] = { num_slots = 49, cols = 7, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 265 },
}

-- ContainerWidget draws at this scale inside the HUD container root.
M.WIDGET_SCALE = 0.6
-- Width of an inventory slot in widget units at slot scale 1.
M.SLOT_SIZE = 68
-- Gap kept between the grid and the top edge of the screen, in HUD units.
M.SCREEN_MARGIN = 5
-- Room kept free at the bottom of the screen for the inventory bar.
M.INVENTORY_BAR_HEIGHT = 150

-- Half the on-screen height of a layout's slots, in HUD units.
function M.layout_half_height(layout)
    local rows = math.ceil(layout.num_slots / layout.cols)
    return M.WIDGET_SCALE * ((rows - 1) / 2 * layout.spacing + M.SLOT_SIZE / 2)
end

-- Fits a layout into a HUD whose visible area spans +/-screen_half_height
-- units. Keeps the preferred position when the grid fits there, otherwise
-- slides it down below the top edge, and only shrinks the slots when the
-- grid is taller than the room between the top edge and the inventory bar.
-- Returns the widget's y position and the slot scale.
function M.fit_layout(layout, screen_half_height)
    local top = screen_half_height - M.SCREEN_MARGIN
    local bottom = M.INVENTORY_BAR_HEIGHT - screen_half_height
    local half = M.layout_half_height(layout)
    if layout.pos_y + half <= top then
        return layout.pos_y, 1
    end
    if top - 2 * half >= bottom then
        return top - half, 1
    end
    return (top + bottom) / 2, (top - bottom) / (2 * half)
end

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

-- Categories selected by the half-rate setting recover at this fraction of
-- the configured rate.
M.MAGIC_RATE_MULTIPLIER = 0.5

-- Prefab names of magical, non-clothing items with durability. The Lazy
-- Forager (orangeamulet) is intentionally left out: it is niche enough
-- that it always counts as an ordinary tool.
M.MAGIC_ITEMS =
{
    -- Magic tab
    panflute = true,
    onemanband = true,
    nightsword = true,
    armor_sanity = true,
    batbat = true,
    armorslurper = true,
    antlionhat = true,
    armordreadstone = true,
    dreadstonehat = true,
    pocketwatch_weapon = true,
    amulet = true,
    blueamulet = true,
    purpleamulet = true,
    firestaff = true,
    icestaff = true,
    telestaff = true,
    -- Ancient tab
    greenamulet = true,
    yellowamulet = true,
    greenstaff = true,
    orangestaff = true,
    yellowstaff = true,
    opalstaff = true,
}

-- Item categories used by the half-rate setting.
M.CATEGORY_MAGICAL = "magical"
M.CATEGORY_TOOLS = "tools"
M.CATEGORY_CLOTHING = "clothing"

-- Classifies an item: magical items by prefab name, clothing by usage fuel
-- (hats, vests and other sewable gear), everything else (tools, weapons,
-- armor, lanterns) as tools.
function M.item_category(prefab, is_usage_fueled)
    if type(prefab) == "string" and M.MAGIC_ITEMS[prefab] then
        return M.CATEGORY_MAGICAL
    end
    if is_usage_fueled == true then
        return M.CATEGORY_CLOTHING
    end
    return M.CATEGORY_TOOLS
end

-- Parses the half-rate setting ("none", "all", or categories joined with
-- "+", e.g. "magical+tools") into a set of categories. Done once at load so
-- the repair step does not re-parse the string for every item.
function M.parse_half_rate(selection)
    local halved = {}
    if selection == "all" then
        halved[M.CATEGORY_MAGICAL] = true
        halved[M.CATEGORY_TOOLS] = true
        halved[M.CATEGORY_CLOTHING] = true
    elseif type(selection) == "string" then
        for part in string.gmatch(selection, "[^+]+") do
            halved[part] = true
        end
    end
    return halved
end

-- Recovery rate multiplier for an item, given a parse_half_rate set.
function M.rate_multiplier(halved, prefab, is_usage_fueled)
    if halved[M.item_category(prefab, is_usage_fueled)] then
        return M.MAGIC_RATE_MULTIPLIER
    end
    return 1
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
