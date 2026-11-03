-- Regression tests for modmain.lua against a stubbed DST mod environment.
-- Covers the crash fixes (slot netvar capacity above 20 slots, the client
-- widget lookup by prefab name, dropping contents when hammered) and the
-- repair step itself.
-- Run from the mod root: lua5.1 test/test_modmain.lua

local mod_root = arg[0]:match("^(.*)/test/test_modmain%.lua$")
if mod_root == nil or mod_root == "" then
    mod_root = "."
end

local passed, failed = 0, 0
local mathmod = dofile(mod_root .. "/wardrobe_restorer_math.lua")

-- Enough of DST's Vector3 for the widget code: construction and scaling.
local vector3_mt = {}
local function Vector3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, vector3_mt)
end
vector3_mt.__mul = function(v, k) return Vector3(v.x * k, v.y * k, v.z * k) end

local function check(cond, msg)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. msg .. "\n")
    end
end

-- Vanilla containers.lua sizes MAXITEMSLOTS to its largest container.
local VANILLA_MAXITEMSLOTS = 20

local function load_modmain(config)
    local containers = { MAXITEMSLOTS = VANILLA_MAXITEMSLOTS, params = {} }
    local postinits = {}

    local env = {
        pairs = pairs,
        ipairs = ipairs,
        print = function() end,
        math = math,
        table = table,
        type = type,
        string = string,
        tostring = tostring,
        MODROOT = mod_root .. "/",
        GLOBAL = {
            require = function(name)
                assert(name == "containers", "unexpected require " .. name)
                return containers
            end,
            Vector3 = Vector3,
            TheSim = { GetScreenSize = function() return 1920, 1080 end },
            TheWorld = { ismastersim = true },
            TUNING = { SEG_TIME = 30 },
            FUELTYPE = { USAGE = "USAGE" },
            ACTIONS = { CHANGEIN = {} },
        },
        GetModConfigData = function(name) return config[name] end,
        AddComponentAction = function() end,
        AddPrefabPostInit = function(prefab, fn) postinits[prefab] = fn end,
    }
    env.env = env
    env.modimport = function(modulename)
        local chunk = assert(loadfile(env.MODROOT .. modulename))
        setfenv(chunk, env.env)
        chunk()
    end

    local chunk = assert(loadfile(mod_root .. "/modmain.lua"))
    setfenv(chunk, env)
    chunk()
    return containers, postinits
end

-- Minimal server-side wardrobe with the vanilla hammer callback.
local function make_wardrobe(log)
    local inst = { tags = {}, components = {} }
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:UnregisterComponentActions() end
    function inst:DoPeriodicTask(period, fn, initialdelay, arg)
        log.task = { period = period, fn = fn, arg = arg }
    end
    function inst:AddComponent(name)
        assert(name == "container", "unexpected component " .. name)
        self.components.container = {
            slots = {},
            WidgetSetup = function(_, prefab) log.widget = prefab end,
            DropEverything = function() table.insert(log, "drop") end,
        }
    end
    inst.components.wardrobe = {
        onopenfn = function() end,
        onclosefn = function() end,
    }
    inst.components.workable = {
        onfinish = function() table.insert(log, "vanilla_onfinish") end,
        SetOnFinishCallback = function(self, fn) self.onfinish = fn end,
    }
    return inst
end

for _, num_slots in ipairs({ 4, 9, 16, 20, 25, 36, 49 }) do
    local containers, postinits = load_modmain({ num_slots = num_slots, recovery_rate = 5, half_rate = "magical" })
    local label = num_slots .. " slots: "

    check(containers.MAXITEMSLOTS >= num_slots, label .. "MAXITEMSLOTS covers every slot")
    check(containers.MAXITEMSLOTS >= VANILLA_MAXITEMSLOTS, label .. "MAXITEMSLOTS never shrinks")

    local params = containers.params.wardrobe
    check(params ~= nil, label .. "params registered under the wardrobe prefab name")
    check(params ~= nil and #params.widget.slotpos == num_slots, label .. "widget has one position per slot")
    -- A HUD whose container root spans +/-half_height units on screen.
    local function doer_with_screen(half_height)
        return { HUD = { controls = { containerroot = {
            GetWorldScale = function() return { y = 1080 / 2 / half_height } end,
        } } } }
    end
    for _, half_height in ipairs({ 220, 360 }) do
        local doer = doer_with_screen(half_height)
        local y, scale = mathmod.fit_layout(mathmod.get_slot_layout(num_slots), half_height)
        local widget = params.widget
        check(math.abs(widget.posfn(nil, doer).y - y) < 1e-9,
            label .. "widget position fits a +/-" .. half_height .. " screen")
        check(math.abs(widget.slotscalefn(nil, doer) - scale) < 1e-9,
            label .. "slot scale fits a +/-" .. half_height .. " screen")
        local positions = widget.slotposfn(nil, doer)
        check(#positions == num_slots and math.abs(positions[1].y - widget.slotpos[1].y * scale) < 1e-9,
            label .. "slot positions scale with the slots on a +/-" .. half_height .. " screen")
    end
    check(params.widget.posfn(nil, nil).y == mathmod.fit_layout(mathmod.get_slot_layout(num_slots), 360),
        label .. "missing HUD falls back to a 720-unit screen")

    local log = {}
    local inst = make_wardrobe(log)
    postinits.wardrobe(inst)
    check(log.widget == "wardrobe", label .. "server widget setup matches the client lookup")
    check(inst.components.container.onopenfn == inst.components.wardrobe.onopenfn
        and inst.components.container.onclosefn == inst.components.wardrobe.onclosefn,
        label .. "container reuses the wardrobe open/close feedback")

    inst.components.workable.onfinish(inst, {})
    check(log[1] == "drop" and log[2] == "vanilla_onfinish",
        label .. "hammering drops contents before the vanilla collapse")
end

-- Stored item with one durability component. The stubs clamp at the maximum
-- like the real components and count how often they are changed.
local function make_item(prefab, kind, current, max, extra)
    local item = { prefab = prefab, components = {}, changes = 0 }
    if kind == "finiteuses" then
        item.components.finiteuses = { current = current, total = max,
            Repair = function(self, amount) item.changes = item.changes + 1; self.current = math.min(self.current + amount, self.total) end }
    elseif kind == "armor" then
        item.components.armor = { condition = current, maxcondition = max,
            SetCondition = function(self, amount) item.changes = item.changes + 1; self.condition = math.min(amount, self.maxcondition) end }
    elseif kind == "fueled" then
        item.components.fueled = { currentfuel = current, maxfuel = max, fueltype = "USAGE",
            DoDelta = function(self, amount) item.changes = item.changes + 1; self.currentfuel = math.min(self.currentfuel + amount, self.maxfuel) end }
    end
    for k, v in pairs(extra or {}) do
        item.components[k] = v
    end
    return item
end

do
    -- 10%/day so one 480s day restores 10 units of a 100-unit item.
    local _, postinits = load_modmain({ num_slots = 20, recovery_rate = 10, half_rate = "magical" })
    local log = {}
    local inst = make_wardrobe(log)
    postinits.wardrobe(inst)

    check(log.task.period == 30 and log.task.arg == 30, "repairs run once per 30s segment")

    local spear = make_item("spear", "finiteuses", 50, 100)
    local armor = make_item("armorwood", "armor", 50, 100)
    local tophat = make_item("tophat", "fueled", 50, 100)
    local staff = make_item("firestaff", "finiteuses", 50, 100)
    local full = make_item("spear", "finiteuses", 100, 100)
    local ham = make_item("hambat", "finiteuses", 50, 100, { perishable = {} })
    local sealed = make_item("tophat", "fueled", 50, 100)
    sealed.components.fueled.no_sewing = true
    local slots = inst.components.container.slots
    slots[1], slots[2], slots[3], slots[5], slots[8], slots[13], slots[20] = spear, armor, tophat, staff, full, ham, sealed

    inst.OnLongUpdate(inst, 480)
    check(math.abs(spear.components.finiteuses.current - 60) < 1e-9, "uses recover at the configured rate")
    check(math.abs(armor.components.armor.condition - 60) < 1e-9, "armor recovers at the configured rate")
    check(math.abs(tophat.components.fueled.currentfuel - 60) < 1e-9, "clothing recovers at the configured rate")
    check(math.abs(staff.components.finiteuses.current - 55) < 1e-9, "magical items recover at half rate")
    check(full.changes == 0, "full items are left alone")
    check(ham.changes == 0, "perishable items never recover")
    check(sealed.changes == 0, "unsewable items keep their rule")

    log.task.fn(inst, log.task.arg)
    check(math.abs(spear.components.finiteuses.current - 60.625) < 1e-9, "one periodic step restores one segment's worth")

    inst.components.container = nil
    local ok = pcall(inst.OnLongUpdate, inst, 480)
    check(ok, "a burnt wardrobe (container removed) skips repairs")
end

print(passed .. "/" .. (passed + failed) .. " modmain tests passed")
if failed > 0 then
    os.exit(1)
end
