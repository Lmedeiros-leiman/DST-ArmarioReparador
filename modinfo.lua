name = "Wardrobe Storage and Repair"
description = [[Turns the wardrobe into a chest (20 slots by default) that slowly repairs the equipment stored inside. Left click opens the storage, right click changes skins. Each item category can be stored, repaired and slowed down separately in the config.

Warning: disabling this mod deletes everything stored in wardrobes. Empty them first.]]
author = "Frytura"
version = "1.4.0"

forumthread = ""

api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

all_clients_require_mod = true
client_only_mod = false

icon = "modicon.tex"
icon_atlas = "modicon.xml"

server_filter_tags =
{
    "wardrobe",
    "storage",
}

-- Yes/No option. modinfo runs in a sandbox without Lua's standard library
-- (modindex.lua InitializeModInfo), so the per-category options below are
-- spelled out instead of generated in a loop.
local function yes_no(name, label, hover, default)
    return {
        name = name,
        label = label,
        hover = hover,
        options =
        {
            { description = "Yes", data = true },
            { description = "No", data = false },
        },
        default = default,
    }
end

-- modmain reads "store_<category>", "repair_<category>" and "halfrate_<category>".
local function store(category, label, contents)
    return yes_no("store_" .. category, "Store " .. label,
        contents .. " No: these items cannot be stored, and ones already stored stop repairing.", true)
end

local function repair(category, label)
    return yes_no("repair_" .. category, "Repair " .. label,
        "Repair stored " .. label .. ". No effect when Enable repair? is No or Store " .. label .. " is No.", true)
end

local function half_rate(category, label, default)
    return yes_no("halfrate_" .. category, "Half rate " .. label,
        label .. " recover at half the Recovery rate. No effect unless " .. label .. " are repaired.", default)
end

configuration_options =
{
    {
        name = "num_slots",
        label = "Slots",
        hover = "Number of wardrobe slots.",
        options =
        {
            { description = "4 (2x2)", data = 4 },
            { description = "9 (chest 3x3)", data = 9 },
            { description = "16 (4x4)", data = 16 },
            { description = "20 (5x4, default)", data = 20 },
            { description = "25 (5x5)", data = 25 },
            { description = "36 (6x6)", data = 36 },
            { description = "49 (7x7)", data = 49 },
        },
        default = 20,
    },
    -- DST's config screen cannot hide options, so the repair settings sit
    -- under their own header right below the toggle.
    {
        name = "repair_header",
        label = "Repair",
        options = { { description = "", data = 0 } },
        default = 0,
    },
    {
        name = "enable_repair",
        label = "Enable repair?",
        hover = "Slowly repair equipment stored in the wardrobe. When No, the wardrobe is storage only and every Recovery, Repair and Half rate option is ignored.",
        options =
        {
            { description = "Yes", data = true },
            { description = "No", data = false },
        },
        default = true,
    },
    {
        name = "recovery_rate",
        label = "Recovery (%/day)",
        hover = "Durability recovered per day. 5% takes an item from 0% to 100% in 20 days. Ignored when repair is disabled.",
        options =
        {
            { description = "1% (100 days)", data = 1 },
            { description = "2% (50 days)", data = 2 },
            { description = "3% (33 days)", data = 3 },
            { description = "4% (25 days)", data = 4 },
            { description = "5% (20 days)", data = 5 },
            { description = "6% (17 days)", data = 6 },
            { description = "8% (13 days)", data = 8 },
            { description = "10% (10 days)", data = 10 },
            { description = "15% (7 days)", data = 15 },
            { description = "20% (5 days)", data = 20 },
        },
        default = 5,
    },
    {
        name = "categories_header",
        label = "Item categories",
        options = { { description = "", data = 0 } },
        default = 0,
    },
    store("tools", "Tools", "Tools, weapons and armor: axes, pickaxes, spears, log suits, football helmets and anything not in another category."),
    repair("tools", "Tools"),
    half_rate("tools", "Tools", false),
    store("clothing", "Clothing", "Sewable hats, vests and other gear that wears out with use."),
    repair("clothing", "Clothing"),
    half_rate("clothing", "Clothing", false),
    store("magical", "Magical", "Fire, ice and telelocator staffs, amulets, night armor, dark sword, bat bat, one-man band, Alarming Clock and the pan flute."),
    repair("magical", "Magical"),
    half_rate("magical", "Magical", true),
    store("ancient_magic", "Ancient magic", "Ancient tab staffs and amulets: Deconstruction Staff, Lazy Explorer, Star Caller's Staff, Moon Caller's Staff, Construction Amulet, Magiluminescence and Lazy Forager."),
    repair("ancient_magic", "Ancient magic"),
    half_rate("ancient_magic", "Ancient magic", true),
    store("ancient", "Ancient gear", "Thulecite crown, suit and club."),
    repair("ancient", "Ancient gear"),
    half_rate("ancient", "Ancient gear", false),
    store("boss", "Boss gear", "Dropped by a boss or made from a boss drop: Bone Armor and Helm, Shield of Terror, Eye Mask, Scalemail, Hibearnation Vest, Eyebrella, Bee Queen Crown, Turf-Raiser Helm, Weather Pain, Spiderhat, Enlightened Crown."),
    repair("boss", "Boss gear"),
    half_rate("boss", "Boss gear", false),
    store("kit", "Kit gear", "Brightshade, Void cloth and W.A.R.B.I.S. gear (normally fixed with a repair kit), plus Dreadstone (heals itself)."),
    repair("kit", "Kit gear"),
    half_rate("kit", "Kit gear", false),
    store("light", "Lights", "Torch, Morning Star, lighter, lantern, miner hat, moggles and red lantern."),
    repair("light", "Lights"),
    half_rate("light", "Lights", false),
    store("refillable", "Refillables", "Watering cans and other items that are refilled rather than repaired."),
    repair("refillable", "Refillables"),
    half_rate("refillable", "Refillables", false),
}
