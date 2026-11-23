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
    local expected = { "refillable", "kit", "boss", "ancient", "magical", "light", "clothing", "tools" }
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
for _, prefab in ipairs({ "greenstaff", "orangestaff", "yellowstaff", "opalstaff", "greenamulet", "yellowamulet" }) do
    check(prefab .. " (ancient magic) stays magical", function()
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
check("half speed covers the pan flute with magical", function()
    return M.rate_multiplier(M.parse_half_rate("magical"), "panflute", false) == 0.5
end)
for _, prefab in ipairs({ "armorskeleton", "ruins_bat", "torch", "armordreadstone" }) do
    check("half speed 'all' leaves " .. prefab .. " at full speed", function()
        return M.rate_multiplier(M.parse_half_rate("all"), prefab, false) == 1
    end)
end
check("half speed 'all' leaves a refillable item at full speed", function()
    return M.rate_multiplier(M.parse_half_rate("all"), "wateringcan", false, { fillable = true }) == 1
end)
check("missing allowed settings allow every category", function()
    local allowed = M.parse_allowed(function() return nil end)
    for _, name in ipairs(M.CATEGORIES) do
        if allowed[name] ~= true then return false end
    end
    return true
end)
check("a category set to false is not allowed", function()
    local allowed = M.parse_allowed(function(key) if key == "allow_boss" then return false end end)
    return allowed.boss == false and allowed.tools == true
end)

------------------------------------------------------------------------------
-- modinfo exposes one allowed toggle per category, defaulting to Yes.

do
    local info = {}
    local chunk = assert(loadfile(mod_root .. "/modinfo.lua"))
    setfenv(chunk, info)
    chunk()
    local options = {}
    for _, option in ipairs(info.configuration_options or {}) do
        options[option.name] = option
    end
    for _, name in ipairs({ "refillable", "kit", "boss", "ancient", "magical", "light", "clothing", "tools" }) do
        check("modinfo has a Yes/No allow_" .. name .. " toggle defaulting to Yes", function()
            local option = options["allow_" .. name]
            if option == nil or option.default ~= true or #option.options ~= 2 then return false end
            local values = {}
            for _, v in ipairs(option.options) do values[tostring(v.data)] = true end
            return values["true"] and values["false"]
        end)
    end
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
        item.tags[spec.fueltype .. "_fueled"] = true
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
    return not accepts({ allow_boss = false }, server_item("armorskeleton"))
end)
check("server: tools stay allowed when boss gear is off", function()
    return accepts({ allow_boss = false }, server_item("spear"))
end)
check("server: refillable items are refused when refillable is off", function()
    return not accepts({ allow_refillable = false }, server_item("wateringcan", { fillable = true, uses = 10 }))
end)
check("server: kit gear is refused when kit gear is off", function()
    return not accepts({ allow_kit = false }, server_item("sword_lunarplant", { forge = "lunarplant" }))
end)
check("server: Thulecite is refused when ancient is off", function()
    return not accepts({ allow_ancient = false }, server_item("ruins_bat"))
end)
check("server: light sources are refused when light is off", function()
    return not accepts({ allow_light = false }, server_item("torch", { fueltype = "BURNABLE" }))
end)
check("server: the pan flute is accepted", function()
    return accepts({}, server_item("panflute", { equippable = false, uses = 5 }))
end)
check("server: the pan flute follows the magical toggle", function()
    return not accepts({ allow_magical = false }, server_item("panflute", { equippable = false, uses = 5 }))
end)
check("server: other non-equippable items stay out", function()
    return not accepts({}, server_item("rope", { equippable = false }))
end)

-- Client side: the same decisions from replicas and tags.
check("client: kit gear is refused when kit gear is off", function()
    return not accepts({ allow_kit = false }, client_item("sword_lunarplant", { forgerepairable_lunarplant = true }), false)
end)
check("client: refillable items are refused when refillable is off", function()
    return not accepts({ allow_refillable = false }, client_item("wateringcan", { fillable = true }), false)
end)
check("client: clothing is refused when clothing is off", function()
    return not accepts({ allow_clothing = false }, client_item("tophat", { USAGE_fueled = true }), false)
end)
check("client: clothing stays allowed when only tools are off", function()
    return accepts({ allow_tools = false }, client_item("tophat", { USAGE_fueled = true }), false)
end)
check("client: a modded cave-fueled lamp follows the light toggle", function()
    return not accepts({ allow_light = false }, client_item("modded_lamp", { CAVE_fueled = true }), false)
end)
check("client: the pan flute is accepted", function()
    return accepts({}, client_item("panflute", {}, false), false)
end)

-- Repairs
check("items of a disallowed category stop repairing", function()
    local _, postinits = load_modmain({ recovery_rate = 10, allow_light = false })
    local inst = with_tags({ components = {} }, {})
    function inst:UnregisterComponentActions() end
    function inst:DoPeriodicTask() end
    function inst:AddComponent()
        self.components.container = { slots = {}, WidgetSetup = function() end, IsOpen = function() return false end }
    end
    inst.components.wardrobe = { changers = {} }
    postinits.wardrobe(inst)
    local torch = server_item("torch", { fueltype = "BURNABLE" })
    local spear = server_item("spear", { uses = 50 })
    inst.components.container.slots[1], inst.components.container.slots[2] = torch, spear
    inst.OnLongUpdate(inst, 480)
    return torch.changes == 0 and spear.changes == 1
end)
check("the pan flute repairs its uses", function()
    local _, postinits = load_modmain({ recovery_rate = 10 })
    local inst = with_tags({ components = {} }, {})
    function inst:UnregisterComponentActions() end
    function inst:DoPeriodicTask() end
    function inst:AddComponent()
        self.components.container = { slots = {}, WidgetSetup = function() end, IsOpen = function() return false end }
    end
    inst.components.wardrobe = { changers = {} }
    postinits.wardrobe(inst)
    local flute = server_item("panflute", { equippable = false, uses = 50 })
    inst.components.container.slots[1] = flute
    inst.OnLongUpdate(inst, 480)
    -- Magical repairs at half speed by default: 10%/day halved is 5 uses.
    return math.abs(flute.components.finiteuses.current - 55) < 1e-9
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
