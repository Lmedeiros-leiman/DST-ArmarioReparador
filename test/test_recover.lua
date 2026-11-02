-- Test harness for the wardrobe_restorer durability math.
-- Run from the mod root: lua5.1 test/test_recover.lua

local mod_root = arg[0]:match("^(.*)/test/test_recover%.lua$")
if mod_root == nil or mod_root == "" then
    mod_root = "."
end

local M
do
    local chunk = loadfile(mod_root .. "/wardrobe_restorer_math.lua")
    if chunk == nil then
        io.stderr:write("FAIL: wardrobe_restorer_math.lua not found (or has a syntax error)\n")
        os.exit(1)
    end
    M = chunk()
    if type(M) ~= "table" then
        io.stderr:write("FAIL: wardrobe_restorer_math.lua must return a table\n")
        os.exit(1)
    end
end

local count = 0
local failures = 0

local function assert_eq(actual, expected, label)
    count = count + 1
    if actual ~= expected then
        failures = failures + 1
        io.stderr:write(string.format("FAIL: %s (expected %s, got %s)\n",
            label, tostring(expected), tostring(actual)))
    end
end

local function assert_near(actual, expected, eps, label)
    count = count + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > (eps or 1e-9) then
        failures = failures + 1
        io.stderr:write(string.format("FAIL: %s (expected ~%s, got %s)\n",
            label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value == true and true or false, true, label)
end

-- Day length: a full DST day cycle is 16 segments of 30 seconds.
assert_eq(M.DAY_LENGTH_SECONDS, 480, "default day length is 480s")

-- 5%/day over one full day on a 100-use item recovers 5 uses.
assert_near(M.recovery_delta(100, 5, 480), 5, 1e-9, "5%/day over one day adds 5 uses")

-- A single 1-second tick recovers 5/480 of a day's worth.
assert_near(M.recovery_delta(100, 5, 1), 100 * 5 / 100 / 480, 1e-12, "1s tick is proportional")

-- Rate in %/day maps linearly to time until full.
assert_near(M.recover(0, 100, 5, 480 * 20), 100, 1e-9, "5%/day fills a 100-use item in 20 days")
assert_near(M.recover(0, 100, 5.5, 480 * 100 / 5.5), 100, 1e-9, "5.5%/day fills in ~18.2 days")
assert_true(M.recover(0, 100, 5, 480 * 18) < 100, "5%/day does NOT fill in 18 days")

-- Recovery clamps at the item's maximum.
assert_eq(M.recover(99.5, 100, 5, 480), 100, "recovery clamps at max")
assert_eq(M.recover(100, 100, 5, 480), 100, "full item stays full")

-- Degenerate inputs produce zero delta instead of errors.
assert_eq(M.recovery_delta(0, 5, 480), 0, "zero max gives zero delta")
assert_eq(M.recovery_delta(nil, 5, 480), 0, "nil max gives zero delta")
assert_eq(M.recovery_delta(100, 0, 480), 0, "zero rate gives zero delta")
assert_eq(M.recovery_delta(100, nil, 480), 0, "nil rate gives zero delta")
assert_eq(M.recovery_delta(100, 5, 0), 0, "zero dt gives zero delta")
assert_eq(M.recovery_delta(100, 5, -10), 0, "negative dt gives zero delta")

-- Custom day length is honored (used if we ever read it from the world).
assert_eq(M.recovery_delta(480, 100, 480, 960), 240, "custom day length scales the delta")

-- Step accumulation: 20 days of one step per segment ends at full.
do
    local current = 0
    local steps_per_day = M.DAY_LENGTH_SECONDS / M.SEGMENT_LENGTH_SECONDS
    assert_eq(steps_per_day, 16, "a day has 16 segments")
    for _ = 1, 20 * steps_per_day do
        current = M.recover(current, 100, 5, M.SEGMENT_LENGTH_SECONDS)
    end
    assert_near(current, 100, 1e-6, "20 days of per-segment steps fill the item")
    assert_near(M.recovery_delta(100, 5, M.SEGMENT_LENGTH_SECONDS), 0.3125, 1e-9,
        "one segment at 5%/day restores 0.3125% of a 100-use item")
end

-- Integration contract used by modmain: finiteuses pairs current with total,
-- armor pairs condition with maxcondition.
do
    local fu = { current = 50, total = 100 }
    fu.current = M.recover(fu.current, fu.total, 5, 480)
    assert_eq(fu.current, 55, "finiteuses recovers toward total")

    local armor = { condition = 10, maxcondition = 100 }
    armor.condition = M.recover(armor.condition, armor.maxcondition, 5, 480)
    assert_eq(armor.condition, 15, "armor recovers toward maxcondition")
end

-- Item acceptance: equipment only, nothing that rots.
assert_eq(M.accepts_item(true, false), true, "plain equipment is accepted")
assert_eq(M.accepts_item(true, true), false, "perishable equipment is rejected")
assert_eq(M.accepts_item(false, false), false, "non-equipment is rejected")
assert_eq(M.accepts_item(nil, false), false, "missing equippable is rejected")

-- Item classification: magical by prefab, clothing by usage fuel, the rest
-- are tools. The Lazy Forager is exempt from the magical list.
assert_eq(M.item_category("panflute", false), "magical", "pan flute is magical")
assert_eq(M.item_category("greenamulet", false), "magical", "construction amulet is magical")
assert_eq(M.item_category("yellowamulet", false), "magical", "magiluminescence is magical")
assert_eq(M.item_category("greenstaff", false), "magical", "deconstruction staff is magical")
assert_eq(M.item_category("orangestaff", false), "magical", "lazy explorer is magical")
assert_eq(M.item_category("orangeamulet", false), "tools", "lazy forager counts as a tool")
assert_eq(M.item_category("spear", false), "tools", "spear is a tool")
assert_eq(M.item_category("armorwood", false), "tools", "armor counts as a tool")
assert_eq(M.item_category("tophat", true), "clothing", "usage-fueled gear is clothing")
assert_eq(M.item_category("minerhat", false), "tools", "cave-fueled hat is not clothing")
assert_eq(M.item_category(nil, false), "tools", "missing prefab is a tool")

-- The half-rate setting parses into a set of categories.
local function half_rate_applies(selection, category)
    return M.parse_half_rate(selection)[category] == true
end
assert_eq(half_rate_applies("none", "magical"), false, "none covers nothing")
assert_eq(half_rate_applies("all", "clothing"), true, "all covers everything")
assert_eq(half_rate_applies("magical", "magical"), true, "magical covers magical")
assert_eq(half_rate_applies("magical", "tools"), false, "magical does not cover tools")
assert_eq(half_rate_applies("magical+tools", "tools"), true, "magical+tools covers tools")
assert_eq(half_rate_applies("magical+tools", "magical"), true, "magical+tools covers magical")
assert_eq(half_rate_applies("magical+tools", "clothing"), false, "magical+tools does not cover clothing")
assert_eq(half_rate_applies("tools+clothing", "clothing"), true, "tools+clothing covers clothing")
assert_eq(half_rate_applies(nil, "magical"), false, "missing setting covers nothing")

-- Multiplier under the default setting ("magical").
assert_eq(M.rate_multiplier(M.parse_half_rate("magical"), "firestaff", false), 0.5, "staff recovers at half rate")
assert_eq(M.rate_multiplier(M.parse_half_rate("magical"), "orangeamulet", false), 1, "lazy forager recovers at full rate")
assert_eq(M.rate_multiplier(M.parse_half_rate("magical"), "spear", false), 1, "tool recovers at full rate")
assert_eq(M.rate_multiplier(M.parse_half_rate("magical"), "tophat", true), 1, "clothing recovers at full rate")
assert_eq(M.rate_multiplier(M.parse_half_rate("all"), "spear", false), 0.5, "all halves tools")
assert_eq(M.rate_multiplier(M.parse_half_rate("none"), "firestaff", false), 1, "none keeps staffs at full rate")
assert_eq(M.rate_multiplier(M.parse_half_rate("clothing"), "tophat", true), 0.5, "clothing setting halves clothing")
assert_near(M.recover(0, 100, 5 * M.rate_multiplier(M.parse_half_rate("magical"), "firestaff", false), 480 * 20), 50, 1e-9,
    "a magical item at 5%/day reaches 50% after 20 days")
assert_near(M.recover(0, 100, 5 * M.rate_multiplier(M.parse_half_rate("magical"), "firestaff", false), 480 * 40), 100, 1e-9,
    "a magical item at 5%/day fills in 40 days")

-- The mod configuration accepts square grids from 2x2 through 7x7, plus
-- the existing 5x4 default. Unsupported values must not create invisible
-- slots outside the selected widget geometry.
do
    local cases =
    {
        { requested = 4,  slots = 4,  cols = 2, label = "2x2" },
        { requested = 9,  slots = 9,  cols = 3, label = "3x3" },
        { requested = 16, slots = 16, cols = 4, label = "4x4" },
        { requested = 20, slots = 20, cols = 5, label = "5x4 default" },
        { requested = 25, slots = 25, cols = 5, label = "5x5" },
        { requested = 36, slots = 36, cols = 6, label = "6x6" },
        { requested = 49, slots = 49, cols = 7, label = "7x7" },
    }

    for _, case in ipairs(cases) do
        local layout = M.get_slot_layout(case.requested)
        assert_eq(layout.num_slots, case.slots, case.label .. " keeps its slot count")
        assert_eq(layout.cols, case.cols, case.label .. " uses the right column count")
        local grid = M.build_grid(layout.num_slots, layout.cols, layout.spacing)
        assert_eq(#grid, case.slots, case.label .. " builds every slot")
    end

    local fallback = M.get_slot_layout(24)
    assert_eq(fallback.num_slots, 20, "unsupported slot count falls back to 20")
    assert_eq(fallback.cols, 5, "unsupported slot count uses the 5x4 layout")
end

-- Grid generator must reproduce the exact vanilla layouts.
do
    local grid = M.build_grid(9, 3, 80)
    assert_eq(#grid, 9, "3x3 grid has 9 slots")
    assert_eq(grid[1].x, -80, "3x3 first x is -80")
    assert_eq(grid[1].y, 80, "3x3 first y is 80 (top-left)")
    assert_eq(grid[5].x, 0, "3x3 center x is 0")
    assert_eq(grid[5].y, 0, "3x3 center y is 0")
    assert_eq(grid[9].x, 80, "3x3 last x is 80")
    assert_eq(grid[9].y, -80, "3x3 last y is -80 (bottom-right)")

    grid = M.build_grid(16, 4, 80)
    assert_eq(#grid, 16, "4x4 grid has 16 slots")
    assert_eq(grid[1].x, -120, "4x4 first x is -120")
    assert_eq(grid[1].y, 120, "4x4 first y is 120")

    grid = M.build_grid(20, 5, 75)
    assert_eq(#grid, 20, "5x4 grid has 20 slots")
    assert_eq(grid[1].x, -150, "5x4 first x is -150")
    assert_near(grid[1].y, 112.5, 1e-9, "5x4 first y is 112.5")
    assert_eq(grid[20].x, 150, "5x4 last x is 150")
    assert_near(grid[20].y, -112.5, 1e-9, "5x4 last y is -112.5")
    assert_eq(grid[2].y, grid[1].y, "grid fills rows horizontally")
    assert_true(grid[6].y < grid[5].y, "grid rows go top to bottom")
end

if failures > 0 then
    io.stderr:write(string.format("%d/%d tests failed\n", failures, count))
    os.exit(1)
end
print(string.format("%d/%d tests passed", count, count))
