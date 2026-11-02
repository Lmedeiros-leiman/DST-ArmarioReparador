-- Regression tests for modmain.lua against a stubbed DST mod environment.
-- Covers the crash fixes: slot netvar capacity above 20 slots, the client
-- widget lookup by prefab name, and dropping contents when hammered.
-- Run from the mod root: lua5.1 test/test_modmain.lua

local mod_root = arg[0]:match("^(.*)/test/test_modmain%.lua$")
if mod_root == nil or mod_root == "" then
    mod_root = "."
end

local passed, failed = 0, 0

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
            Vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
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
    function inst:DoPeriodicTask() end
    function inst:AddComponent(name)
        assert(name == "container", "unexpected component " .. name)
        self.components.container = {
            WidgetSetup = function(_, prefab) log.widget = prefab end,
            SetNumSlots = function() end,
            DropEverything = function() table.insert(log, "drop") end,
        }
    end
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

    local log = {}
    local inst = make_wardrobe(log)
    postinits.wardrobe(inst)
    check(log.widget == "wardrobe", label .. "server widget setup matches the client lookup")

    inst.components.workable.onfinish(inst, {})
    check(log[1] == "drop" and log[2] == "vanilla_onfinish",
        label .. "hammering drops contents before the vanilla collapse")
end

print(passed .. "/" .. (passed + failed) .. " modmain tests passed")
if failed > 0 then
    os.exit(1)
end
