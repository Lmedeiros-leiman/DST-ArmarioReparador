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

-- Tick accumulation: 20 days of 1-second ticks ends at full.
do
    local current = 0
    for _ = 1, 20 * 480 do
        current = M.recover(current, 100, 5, 1)
    end
    assert_near(current, 100, 1e-6, "20 days of 1s ticks fill the item")
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
