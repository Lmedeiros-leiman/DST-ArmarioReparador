-- Item categories: classification, the per-category "allowed" settings,
-- repairs of disallowed categories, the burning wardrobe's skin menu, and
-- the shared open/close feedback between storage and the skin menu.
-- Run from the mod root: lua5.1 test/test_categories.lua

local mod_root = arg[0]:match("^(.*)/test/test_categories%.lua$")
if mod_root == nil or mod_root == "" then
    mod_root = "."
end

local passed, failed = 0, 0

-- Each check runs protected, so a missing function counts as one failure
-- instead of stopping the run.
local function check(msg, fn)
    local ok, result = pcall(fn)
    if ok and result then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("FAIL: " .. msg .. (ok and "" or (" (" .. tostring(result) .. ")")) .. "\n")
    end
end

local M = dofile(mod_root .. "/wardrobe_restorer_math.lua")

local FUELTYPE = {
    BURNABLE = "BURNABLE", USAGE = "USAGE", MAGIC = "MAGIC", CAVE = "CAVE",
    NIGHTMARE = "NIGHTMARE", ONEMANBAND = "ONEMANBAND", PIGTORCH = "PIGTORCH",
    CHEMICAL = "CHEMICAL", WORMLIGHT = "WORMLIGHT", LIGHTER = "LIGHTER",
}
local FORGEMATERIALS = { LUNARPLANT = "lunarplant", VOIDCLOTH = "voidcloth", WAGPUNKBITS = "wagpunk_bits" }

------------------------------------------------------------------------------
-- Classification

local function category(prefab, usage, traits)
    return M.item_category(prefab, usage, traits)
end

check("categories are listed in precedence order", function()
    local expected = { "refillable", "kit", "boss", "ancient", "ancient_magic", "magical", "light", "clothing", "tools" }
    for i, name in ipairs(expected) do
        if M.CATEGORIES[i] ~= name then return false end
    end
    return #M.CATEGORIES == #expected
end)

check("a fillable item is refillable", function()
    return category("wateringcan", false, { fillable = true }) == "refillable"
end)
check("a forge-repairable item is kit gear", function()
    return category("armor_lunarplant", false, { kit = true }) == "kit"
end)
check("a modded forge-repairable item is kit gear", function()
    return category("modded_blade", false, { kit = true }) == "kit"
end)
-- forgerepairable_<material> is only tagged while the item is damaged, so
-- clients need the kit prefabs by name to agree with the server.
for _, prefab in ipairs({ "armor_lunarplant", "lunarplanthat", "sword_lunarplant", "pickaxe_lunarplant",
    "shovel_lunarplant", "staff_lunarplant", "armor_voidcloth", "voidclothhat", "voidcloth_scythe",
    "voidcloth_boomerang", "voidcloth_umbrella", "shadow_battleaxe", "armorwagpunk", "wagpunkhat" }) do
    check(prefab .. " is kit gear by name", function()
        return category(prefab, false, {}) == "kit"
    end)
end
for _, prefab in ipairs({ "armordreadstone", "dreadstonehat" }) do
    check(prefab .. " (self-repairing) is kit gear", function()
        return category(prefab, false, {}) == "kit"
    end)
end
for _, prefab in ipairs({ "armorskeleton", "skeletonhat", "shieldofterror", "eyemaskhat", "armordragonfly",
    "beargervest", "hivehat", "antlionhat", "staff_tornado", "spiderhat", "alterguardianhat" }) do
    check(prefab .. " is boss gear", function()
        return category(prefab, false, {}) == "boss"
    end)
end
check("a usage-fueled boss item is boss gear, not clothing", function()
    return category("eyebrellahat", true, {}) == "boss"
end)
for _, prefab in ipairs({ "ruinshat", "armorruins", "ruins_bat" }) do
    check(prefab .. " (Thulecite) is ancient", function()
        return category(prefab, false, {}) == "ancient"
    end)
end
-- Ancient tab magic gets its own category, the Lazy Forager included.
for _, prefab in ipairs({ "greenstaff", "orangestaff", "yellowstaff", "opalstaff",
    "greenamulet", "yellowamulet", "orangeamulet" }) do
    check(prefab .. " is ancient magic", function()
        return category(prefab, false, {}) == "ancient_magic"
    end)
end
for _, prefab in ipairs({ "firestaff", "icestaff", "telestaff", "amulet", "purpleamulet", "nightsword" }) do
    check(prefab .. " stays magical", function()
        return category(prefab, false, {}) == "magical"
    end)
end
for _, prefab in ipairs({ "torch", "lighter", "lantern", "minerhat", "molehat", "redlantern", "nightstick" }) do
    check(prefab .. " is a light source", function()
        return category(prefab, prefab == "minerhat", {}) == "light"
    end)
end
check("a modded item on light fuel is a light source", function()
    return category("modded_lamp", false, { light_fuel = true }) == "light"
end)
check("kit gear wins over boss gear", function()
    return category("armorskeleton", false, { kit = true }) == "kit"
end)
check("refillable wins over everything", function()
    return category("torch", false, { fillable = true, kit = true }) == "refillable"
end)

------------------------------------------------------------------------------
-- Storage rules and repair speed

check("the pan flute is accepted although it is not equippable", function()
    return M.accepts_item(false, false, "panflute") == true
end)
check("other non-equippable items stay out", function()
    return M.accepts_item(false, false, "rope") == false
end)
check("a perishable pan flute would still be refused", function()
    return M.accepts_item(false, true, "panflute") == false
end)

-- Per-category settings: store_<c>, repair_<c>, halfrate_<c>.
local function settings(config)
    return M.parse_category_settings(function(key) return config[key] end)
end
check("missing settings store and repair every category", function()
    local s = settings({})
    for _, name in ipairs(M.CATEGORIES) do
        if s[name].store ~= true or s[name].repair ~= true then return false end
    end
    return true
end)
-- Half rate by default: magic and the strongest gear (boss, kit).
local HALF_BY_DEFAULT = { magical = true, ancient_magic = true, boss = true, kit = true }
check("missing half-rate settings halve magical, ancient magic, boss and kit gear only", function()
    local s = settings({})
    for _, name in ipairs(M.CATEGORIES) do
        if s[name].half ~= (HALF_BY_DEFAULT[name] == true) then return false end
    end
    return true
end)
check("full speed by default for tools", function()
    return M.category_rate(settings({}), "tools", 10) == 10
end)
check("full speed by default for Thulecite gear", function()
    return M.category_rate(settings({}), "ancient", 10) == 10
end)
for _, name in ipairs({ "magical", "boss", "kit" }) do
    check("half speed by default for " .. name, function()
        return M.category_rate(settings({}), name, 10) == 5
    end)
end
check("halfrate_boss set to No restores full speed", function()
    return M.category_rate(settings({ halfrate_boss = false }), "boss", 10) == 10
end)
check("halfrate_tools halves tools", function()
    return M.category_rate(settings({ halfrate_tools = true }), "tools", 10) == 5
end)
check("halfrate_magical set to No restores full speed", function()
    return M.category_rate(settings({ halfrate_magical = false }), "magical", 10) == 10
end)
check("repair_boss set to No stops boss repairs", function()
    return M.category_rate(settings({ repair_boss = false }), "boss", 10) == 0
end)
check("store_boss set to No also stops boss repairs", function()
    return M.category_rate(settings({ store_boss = false }), "boss", 10) == 0
end)
check("a store setting only affects its own category", function()
    local s = settings({ store_boss = false })
    return s.boss.store == false and s.tools.store == true
end)
check("a magical item at 5%/day reaches 50% after 20 days at half speed", function()
    return math.abs(M.recover(0, 100, M.category_rate(settings({}), "magical", 5), 480 * 20) - 50) < 1e-9
end)

------------------------------------------------------------------------------
-- modinfo exposes Store, Repair and Half rate toggles per category and no
-- longer has the global half-speed setting.

do
    local info = {}
    local chunk = assert(loadfile(mod_root .. "/modinfo.lua"))
    setfenv(chunk, info)
    chunk()
    local options = {}
    for _, option in ipairs(info.configuration_options or {}) do
        options[option.name] = option
    end
    local function yes_no(name, default)
        local option = options[name]
        if option == nil or option.default ~= default or #option.options ~= 2 then return false end
        local values = {}
        for _, v in ipairs(option.options) do values[tostring(v.data)] = true end
        return values["true"] and values["false"]
    end
    for _, name in ipairs({ "refillable", "kit", "boss", "ancient", "ancient_magic", "magical", "light", "clothing", "tools" }) do
        check("modinfo has store_" .. name .. " defaulting to Yes", function()
            return yes_no("store_" .. name, true)
        end)
        check("modinfo has repair_" .. name .. " defaulting to Yes", function()
            return yes_no("repair_" .. name, true)
        end)
        local half = HALF_BY_DEFAULT[name] == true
        check("modinfo has halfrate_" .. name .. " defaulting to " .. (half and "Yes" or "No"), function()
            return yes_no("halfrate_" .. name, half)
        end)
    end
    check("modinfo no longer has the global half_rate setting", function()
        return options.half_rate == nil
    end)
    check("modinfo no longer has allow_* settings", function()
        for name in pairs(options) do
            if name:match("^allow_") then return false end
        end
        return true
    end)
end

------------------------------------------------------------------------------
-- modmain against a stubbed DST environment

local function Vector3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, { __mul = function(v, k) return Vector3(v.x * k, v.y * k, v.z * k) end })
end

local function load_modmain(config)
    local containers = { MAXITEMSLOTS = 20, params = {} }
    local postinits, collectors = {}, {}
    local env = {
        -- Same Lua globals as DST's mod environment (mods.lua CreateEnvironment):
        -- no `next`, so modmain must reach it through GLOBAL.
        pairs = pairs, ipairs = ipairs, print = function() end,
        math = math, table = table, type = type, string = string, tostring = tostring,
        MODROOT = mod_root .. "/",
        GLOBAL = {
            require = function() return containers end,
            Vector3 = Vector3,
            TheSim = { GetScreenSize = function() return 1920, 1080 end, GetScreenPos = function(_, x) return x, 540 end },
            RESOLUTION_X = 1280, RESOLUTION_Y = 720,
            pcall = pcall,
            next = next,
            TheWorld = { ismastersim = true },
            TUNING = { SEG_TIME = 30 },
            FUELTYPE = FUELTYPE,
            FORGEMATERIALS = FORGEMATERIALS,
            ACTIONS = { CHANGEIN = { strfn = function() return nil end } },
            STRINGS = { ACTIONS = { CHANGEIN = { GENERIC = "Use" } } },
        },
        GetModConfigData = function(name) return config[name] end,
        AddComponentAction = function(actiontype, component, fn) collectors[actiontype .. "/" .. component] = fn end,
        AddPrefabPostInit = function(prefab, fn) postinits[prefab] = fn end,
    }
    env.env = env
    env.modimport = function(name)
        local c = assert(loadfile(env.MODROOT .. name))
        setfenv(c, env)
        c()
    end
    local c = assert(loadfile(mod_root .. "/modmain.lua"))
    setfenv(c, env)
    c()
    return containers, postinits, collectors, env.GLOBAL
end

local function with_tags(inst, tags)
    inst.tags = tags or {}
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:AddTag(tag) self.tags[tag] = true end
    return inst
end

-- A server-side item: real components, plus the tags the components add.
local function server_item(prefab, spec)
    spec = spec or {}
    local item = with_tags({ prefab = prefab, components = {}, changes = 0 }, {})
    local comps = item.components
    if spec.equippable ~= false then comps.equippable = {} end
    if spec.uses then
        comps.finiteuses = { current = spec.uses, total = 100,
            Repair = function(self, n) item.changes = item.changes + 1; self.current = math.min(self.current + n, self.total) end }
    end
    if spec.fueltype then
        comps.fueled = { currentfuel = 50, maxfuel = 100, fueltype = spec.fueltype,
            DoDelta = function(self, n) item.changes = item.changes + 1; self.currentfuel = math.min(self.currentfuel + n, self.maxfuel) end }
        -- fueled.lua: usage fuel tags "needssewing" only while damaged (this
        -- stub is at 50/100); other fuel tags "<FUELTYPE>_fueled".
        item.tags[spec.fueltype == "USAGE" and "needssewing" or (spec.fueltype .. "_fueled")] = true
    end
    if spec.fillable then comps.fillable = {}; item.tags.fillable = true end
    if spec.forge then comps.forgerepairable = {}; item.tags["forgerepairable_" .. spec.forge] = true end
    return item
end

-- A client-side item: an empty components table, replicas and tags only.
local function client_item(prefab, tags, equippable)
    local item = with_tags({ prefab = prefab, components = {}, replica = {} }, tags)
    if equippable ~= false then item.replica.equippable = {} end
    return item
end

local function accepts(config, item, mastersim)
    local containers, _, _, G = load_modmain(config)
    G.TheWorld.ismastersim = mastersim ~= false
    return containers.params.wardrobe.itemtestfn(nil, item, 1) == true
end

-- Server side
check("server: every category is allowed by default", function()
    return accepts({}, server_item("armorskeleton")) and accepts({}, server_item("wateringcan", { fillable = true }))
        and accepts({}, server_item("spear"))
end)
check("server: boss gear is refused when boss gear is off", function()
    return not accepts({ store_boss = false }, server_item("armorskeleton"))
end)
check("server: tools stay allowed when boss gear is off", function()
    return accepts({ store_boss = false }, server_item("spear"))
end)
check("server: refillable items are refused when refillable is off", function()
    return not accepts({ store_refillable = false }, server_item("wateringcan", { fillable = true, uses = 10 }))
end)
check("server: kit gear is refused when kit gear is off", function()
    return not accepts({ store_kit = false }, server_item("sword_lunarplant", { forge = "lunarplant" }))
end)
check("server: Thulecite is refused when ancient is off", function()
    return not accepts({ store_ancient = false }, server_item("ruins_bat"))
end)
check("server: ancient staffs are refused when ancient magic is off", function()
    return not accepts({ store_ancient_magic = false }, server_item("greenstaff", { uses = 5 }))
        and accepts({ store_ancient = false }, server_item("greenstaff", { uses = 5 }))
end)
check("server: light sources are refused when light is off", function()
    return not accepts({ store_light = false }, server_item("torch", { fueltype = "BURNABLE" }))
end)
check("server: the pan flute is accepted", function()
    return accepts({}, server_item("panflute", { equippable = false, uses = 5 }))
end)
check("server: the pan flute follows the magical toggle", function()
    return not accepts({ store_magical = false }, server_item("panflute", { equippable = false, uses = 5 }))
end)
check("server: an item that cannot be repaired can still be stored", function()
    return accepts({ repair_tools = false }, server_item("spear"))
end)
check("server: other non-equippable items stay out", function()
    return not accepts({}, server_item("rope", { equippable = false }))
end)

-- Client side: the same decisions from replicas and tags.
check("client: kit gear is refused when kit gear is off", function()
    return not accepts({ store_kit = false }, client_item("sword_lunarplant", { forgerepairable_lunarplant = true }), false)
end)
check("client: refillable items are refused when refillable is off", function()
    return not accepts({ store_refillable = false }, client_item("wateringcan", { fillable = true }), false)
end)
check("client: damaged clothing (needssewing) is refused when clothing is off", function()
    return not accepts({ store_clothing = false }, client_item("tophat", { needssewing = true }), false)
end)
check("client: damaged clothing stays allowed when only tools are off", function()
    return accepts({ store_tools = false }, client_item("tophat", { needssewing = true }), false)
end)
-- Full clothing carries no fuel tag at all, so a client cannot tell it from
-- a tool; it must not refuse what the server would accept.
check("client: full clothing (no tags) stays allowed when only tools are off", function()
    return accepts({ store_tools = false }, client_item("tophat", {}), false)
end)
check("client: a tool is refused when tools and clothing are both off", function()
    return not accepts({ store_tools = false, store_clothing = false }, client_item("spear", {}), false)
end)
check("server: full clothing is refused when clothing is off", function()
    local hat = server_item("tophat", { fueltype = "USAGE" })
    hat.components.fueled.currentfuel = 100
    hat.tags.needssewing = nil
    return not accepts({ store_clothing = false }, hat)
end)
check("client: a modded cave-fueled lamp follows the light toggle", function()
    return not accepts({ store_light = false }, client_item("modded_lamp", { CAVE_fueled = true }), false)
end)
check("client: undamaged kit gear (no repair tag) follows the kit toggle", function()
    return not accepts({ store_kit = false }, client_item("sword_lunarplant", {}), false)
        and accepts({ store_tools = false }, client_item("sword_lunarplant", {}), false)
end)
check("client: the pan flute is accepted", function()
    return accepts({}, client_item("panflute", {}, false), false)
end)

-- Repairs: a wardrobe whose container holds the given items, after one day.
local function repair_one_day(config, items)
    local _, postinits = load_modmain(config)
    local inst = with_tags({ components = {} }, {})
    function inst:UnregisterComponentActions() end
    function inst:DoPeriodicTask() end
    function inst:AddComponent()
        self.components.container = { slots = {}, WidgetSetup = function() end, IsOpen = function() return false end }
    end
    inst.components.wardrobe = { changers = {} }
    postinits.wardrobe(inst)
    for i, item in ipairs(items) do
        inst.components.container.slots[i] = item
    end
    if inst.OnLongUpdate ~= nil then
        inst.OnLongUpdate(inst, 480)
    end
end

check("items of a category that is no longer stored stop repairing", function()
    local torch = server_item("torch", { fueltype = "BURNABLE" })
    local spear = server_item("spear", { uses = 50 })
    repair_one_day({ recovery_rate = 10, store_light = false }, { torch, spear })
    return torch.changes == 0 and spear.changes == 1
end)
check("repair_light set to No stores lights without repairing them", function()
    local torch = server_item("torch", { fueltype = "BURNABLE" })
    local spear = server_item("spear", { uses = 50 })
    repair_one_day({ recovery_rate = 10, repair_light = false }, { torch, spear })
    return torch.changes == 0 and spear.changes == 1
end)
check("Enable repair set to No overrides every Repair setting", function()
    local spear = server_item("spear", { uses = 50 })
    repair_one_day({ recovery_rate = 10, enable_repair = false, repair_tools = true }, { spear })
    return spear.changes == 0
end)
check("halfrate_tools halves a stored spear", function()
    local spear = server_item("spear", { uses = 50 })
    repair_one_day({ recovery_rate = 10, halfrate_tools = true }, { spear })
    return math.abs(spear.components.finiteuses.current - 55) < 1e-9
end)
check("the old half_rate setting is ignored", function()
    local spear = server_item("spear", { uses = 50 })
    repair_one_day({ recovery_rate = 10, half_rate = "all" }, { spear })
    return math.abs(spear.components.finiteuses.current - 60) < 1e-9
end)
check("the pan flute repairs its uses at the magical half rate", function()
    local flute = server_item("panflute", { equippable = false, uses = 50 })
    repair_one_day({ recovery_rate = 10 }, { flute })
    return math.abs(flute.components.finiteuses.current - 55) < 1e-9
end)
check("an ancient staff repairs at the ancient magic half rate", function()
    local staff = server_item("greenstaff", { uses = 50 })
    repair_one_day({ recovery_rate = 10 }, { staff })
    return math.abs(staff.components.finiteuses.current - 55) < 1e-9
end)

------------------------------------------------------------------------------
-- Burning wardrobe and shared open/close feedback

check("a burning wardrobe offers no skin menu", function()
    local _, _, collectors = load_modmain({})
    local inst = with_tags({ replica = { container = { CanBeOpened = function() return true end } } },
        { wardrobe_restorer = true, fire = true })
    local actions = {}
    collectors["SCENE/container"](inst, { replica = { inventory = {} } }, actions, true)
    return #actions == 0
end)

-- Wardrobe with vanilla feedback that logs its calls; `skins` holds the
-- players in the skin menu, `storage_open` whether storage is open.
local function feedback_wardrobe()
    local _, postinits = load_modmain({})
    local log = {}
    local inst = with_tags({ components = {} }, {})
    local state = { storage_open = false }
    function inst:UnregisterComponentActions() end
    function inst:DoPeriodicTask() end
    function inst:AddComponent()
        self.components.container = { slots = {}, WidgetSetup = function() end,
            IsOpen = function() return state.storage_open end }
    end
    inst.components.wardrobe = {
        changers = {},
        onopenfn = function() table.insert(log, "open") end,
        onclosefn = function() table.insert(log, "close") end,
    }
    postinits.wardrobe(inst)
    return inst, log, state
end

check("closing storage while someone changes skins keeps the wardrobe open", function()
    local inst, log = feedback_wardrobe()
    inst.components.wardrobe.changers[{}] = true
    inst.components.container.onclosefn(inst)
    return #log == 0
end)
check("closing storage with nobody in the skin menu closes the wardrobe", function()
    local inst, log = feedback_wardrobe()
    inst.components.container.onclosefn(inst)
    return log[1] == "close"
end)
check("leaving the skin menu while storage is open keeps the wardrobe open", function()
    local inst, log, state = feedback_wardrobe()
    state.storage_open = true
    inst.components.wardrobe.onclosefn(inst)
    return #log == 0
end)
check("opening storage while someone changes skins replays nothing", function()
    local inst, log = feedback_wardrobe()
    inst.components.wardrobe.changers[{}] = true
    inst.components.container.onopenfn(inst)
    return #log == 0
end)
check("opening storage on an idle wardrobe plays the open feedback", function()
    local inst, log = feedback_wardrobe()
    inst.components.container.onopenfn(inst)
    return log[1] == "open"
end)

print(passed .. "/" .. (passed + failed) .. " category tests passed, " .. failed .. " failed")
if failed > 0 then
    os.exit(1)
end
