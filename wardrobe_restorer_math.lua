-- Pure durability-recovery math for wardrobe_restorer.
-- Loaded by modmain via modimport and by test/test_recover.lua via loadfile.

local M = {}

-- A full DST day cycle is 16 segments of 30 seconds.
M.SEGMENT_LENGTH_SECONDS = 30
M.DAY_LENGTH_SECONDS = 480

-- The game ships backgrounds through 5x4 only. The square grids above that
-- reuse the square ancient 4x4 frame, scaled evenly to the grid's width
-- (the art spans 4 slots of 80 units).
-- pos_y is the preferred position, just above the character's head.
-- M.fit_layout moves or shrinks a grid that does not fit there.
local SLOT_LAYOUTS =
{
    [4]  = { num_slots = 4,  cols = 2, spacing = 80, bank = "ui_chest_3x3",        pos_y = 200 },
    [9]  = { num_slots = 9,  cols = 3, spacing = 80, bank = "ui_chest_3x3",        pos_y = 200 },
    [16] = { num_slots = 16, cols = 4, spacing = 80, bank = "ui_boat_ancient_4x4", pos_y = 200 },
    [20] = { num_slots = 20, cols = 5, spacing = 75, bank = "ui_fish_box_5x4",     pos_y = 220 },
    [25] = { num_slots = 25, cols = 5, spacing = 75, bank = "ui_boat_ancient_4x4", pos_y = 230, bgscale = 5 * 75 / 320 },
    [36] = { num_slots = 36, cols = 6, spacing = 75, bank = "ui_boat_ancient_4x4", pos_y = 243, bgscale = 6 * 75 / 320 },
    [49] = { num_slots = 49, cols = 7, spacing = 75, bank = "ui_boat_ancient_4x4", pos_y = 265, bgscale = 7 * 75 / 320 },
}

-- ContainerWidget draws at this scale inside the HUD container root.
M.WIDGET_SCALE = 0.6
-- Width of an inventory slot in widget units at slot scale 1.
M.SLOT_SIZE = 68
-- Gap kept between the grid and the top edge of the screen, in HUD units.
M.SCREEN_MARGIN = 5
-- Room kept free at the bottom of the screen for the inventory bar.
M.INVENTORY_BAR_HEIGHT = 150
-- A grid placed beside the character is centered at this height (about the
-- character's middle) and keeps this horizontal gap from screen center.
M.BESIDE_CENTER_Y = 50
M.CHARACTER_CLEARANCE = 80

-- Half the on-screen size of a layout's slots along one axis, in HUD units.
local function half_extent(count, spacing)
    return M.WIDGET_SCALE * ((count - 1) / 2 * spacing + M.SLOT_SIZE / 2)
end

function M.layout_half_height(layout)
    return half_extent(math.ceil(layout.num_slots / layout.cols), layout.spacing)
end

function M.layout_half_width(layout)
    return half_extent(layout.cols, layout.spacing)
end

-- Fits a layout into a HUD whose visible area spans +/-screen_half_height
-- units. Keeps the preferred spot above the character when the grid fits
-- there. Otherwise the grid goes beside the character, on `side` (1 right,
-- -1 left), and only shrinks when it is taller than the room between the top
-- edge and the inventory bar. Returns the widget's x, y and the slot scale.
function M.fit_layout(layout, screen_half_height, side)
    local top = screen_half_height - M.SCREEN_MARGIN
    local bottom = M.INVENTORY_BAR_HEIGHT - screen_half_height
    local half = M.layout_half_height(layout)
    if layout.pos_y + half <= top then
        return 0, layout.pos_y, 1
    end
    local scale = math.min(1, (top - bottom) / (2 * half))
    half = half * scale
    local y = math.max(bottom + half, math.min(M.BESIDE_CENTER_Y, top - half))
    local x = (side or 1) * (M.layout_half_width(layout) * scale + M.CHARACTER_CLEARANCE)
    return x, y, scale
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

-- Item categories. Each has an "allow_<name>" setting; the half-rate
-- setting covers magical, tools and clothing only.
M.CATEGORY_REFILLABLE = "refillable"
M.CATEGORY_KIT = "kit"
M.CATEGORY_BOSS = "boss"
M.CATEGORY_ANCIENT = "ancient"
M.CATEGORY_MAGICAL = "magical"
M.CATEGORY_LIGHT = "light"
M.CATEGORY_CLOTHING = "clothing"
M.CATEGORY_TOOLS = "tools"

-- Precedence order: an item belongs to the first category that matches.
M.CATEGORIES =
{
    M.CATEGORY_REFILLABLE,
    M.CATEGORY_KIT,
    M.CATEGORY_BOSS,
    M.CATEGORY_ANCIENT,
    M.CATEGORY_MAGICAL,
    M.CATEGORY_LIGHT,
    M.CATEGORY_CLOTHING,
    M.CATEGORY_TOOLS,
}

-- Kit gear is recognized by its forgerepairable component (Brightshade,
-- Void cloth, W.A.R.B.I.S.). Dreadstone has no kit but heals itself, so it
-- is listed by name.
M.KIT_ITEMS =
{
    armordreadstone = true,
    dreadstonehat = true,
}

-- Dropped by a boss or crafted from a boss drop.
M.BOSS_ITEMS =
{
    armorskeleton = true,    -- Ancient Fuelweaver
    skeletonhat = true,      -- Ancient Fuelweaver
    shieldofterror = true,   -- Eye of Terror
    eyemaskhat = true,       -- Eye of Terror
    armordragonfly = true,   -- Dragonfly
    beargervest = true,      -- Bearger
    eyebrellahat = true,     -- Deerclops
    hivehat = true,          -- Bee Queen
    antlionhat = true,       -- Antlion
    staff_tornado = true,    -- Moose/Goose
    spiderhat = true,        -- Spider Queen
    alterguardianhat = true, -- Celestial Champion
}

-- Thulecite armor and weapons. Ancient staffs and amulets stay magical.
M.ANCIENT_ITEMS =
{
    ruinshat = true,
    armorruins = true,
    ruins_bat = true,
}

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

-- Light sources by name: the torch and Morning Star burn the default fuel
-- type, which compasses and fans share, so fuel alone cannot tell them apart.
M.LIGHT_ITEMS =
{
    torch = true,
    nightstick = true,
    lighter = true,
    lantern = true,
    minerhat = true,
    molehat = true,
    redlantern = true,
    yots_redlantern = true,
}

-- Fuel types only lights use. Catches modded lights by their fuel.
M.LIGHT_FUELTYPES =
{
    CAVE = true,
    WORMLIGHT = true,
    LIGHTER = true,
}

-- Items accepted although they are not equippable.
M.STORABLE_EXTRAS =
{
    panflute = true,
}

-- Classifies an item into the first matching category of M.CATEGORIES.
-- `traits` holds what the prefab name cannot tell: fillable (refills like a
-- watering can), kit (repaired with a forge kit) and light_fuel (burns a
-- light-only fuel). Clothing is anything on usage fuel (sewable gear);
-- everything else (tools, weapons, armor) is a tool.
function M.item_category(prefab, is_usage_fueled, traits)
    traits = traits or {}
    local known = type(prefab) == "string"
    if traits.fillable then
        return M.CATEGORY_REFILLABLE
    end
    if traits.kit or (known and M.KIT_ITEMS[prefab]) then
        return M.CATEGORY_KIT
    end
    if known and M.BOSS_ITEMS[prefab] then
        return M.CATEGORY_BOSS
    end
    if known and M.ANCIENT_ITEMS[prefab] then
        return M.CATEGORY_ANCIENT
    end
    if known and M.MAGIC_ITEMS[prefab] then
        return M.CATEGORY_MAGICAL
    end
    if traits.light_fuel or (known and M.LIGHT_ITEMS[prefab]) then
        return M.CATEGORY_LIGHT
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

-- Recovery rate multiplier for a category, given a parse_half_rate set.
function M.category_multiplier(halved, category)
    if halved[category] then
        return M.MAGIC_RATE_MULTIPLIER
    end
    return 1
end

-- Recovery rate multiplier for an item, given a parse_half_rate set.
function M.rate_multiplier(halved, prefab, is_usage_fueled, traits)
    return M.category_multiplier(halved, M.item_category(prefab, is_usage_fueled, traits))
end

-- Reads the "allow_<category>" settings through `get` (GetModConfigData).
-- Anything but false allows the category, so configs saved before the
-- settings existed keep every category.
function M.parse_allowed(get)
    local allowed = {}
    for _, category in ipairs(M.CATEGORIES) do
        allowed[category] = get("allow_" .. category) ~= false
    end
    return allowed
end

-- Storage filter: equipment (plus the listed extras) may be stored,
-- perishables may not.
function M.accepts_item(is_equippable, is_perishable, prefab)
    local storable = is_equippable == true or (type(prefab) == "string" and M.STORABLE_EXTRAS[prefab] == true)
    return storable and is_perishable ~= true
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
        bgscale = layout.bgscale,
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
