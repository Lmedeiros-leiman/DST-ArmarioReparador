name = "Wardrobe Storage and Repair"
description = [[Turns the wardrobe into a chest (20 slots by default) that slowly repairs the equipment stored inside. Left click opens the storage, right click changes skins. Each item category can be allowed or refused in the config.

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

-- One Yes/No toggle per item category; modmain reads "allow_<category>".
local function allow(category, label, hover)
    return {
        name = "allow_" .. category,
        label = label,
        hover = hover .. " When No, these items cannot be stored and stored ones stop repairing.",
        options =
        {
            { description = "Yes", data = true },
            { description = "No", data = false },
        },
        default = true,
    }
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
        hover = "Slowly repair equipment stored in the wardrobe. When disabled the wardrobe is storage only and the repair options below are ignored.",
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
        name = "half_rate",
        label = "Half speed",
        hover = "Categories that recover at half the configured rate. Magical: staffs, amulets, pan flute, shadow gear (the Lazy Forager counts as a tool). Tools: tools, weapons and armor. Clothing: sewable items. Ancient, boss, kit, light and refillable items always recover at full speed. Ignored when repair is disabled.",
        options =
        {
            { description = "None", data = "none" },
            { description = "Magical", data = "magical" },
            { description = "Tools", data = "tools" },
            { description = "Clothing", data = "clothing" },
            { description = "Magical + tools", data = "magical+tools" },
            { description = "Magical + clothing", data = "magical+clothing" },
            { description = "Tools + clothing", data = "tools+clothing" },
            { description = "All", data = "all" },
        },
        default = "magical",
    },
    {
        name = "allowed_header",
        label = "Allowed items",
        options = { { description = "", data = 0 } },
        default = 0,
    },
    allow("tools", "Tools, weapons & armor", "Axes, pickaxes, spears, log suits, football helmets and anything not in another category."),
    allow("clothing", "Clothing", "Sewable hats, vests and other gear that wears out with use."),
    allow("magical", "Magical", "Staffs (ancient ones included), amulets, night armor, dark sword, bat bat, one-man band and the pan flute."),
    allow("ancient", "Ancient (Thulecite)", "Thulecite crown, suit and club."),
    allow("boss", "Boss gear", "Dropped by a boss or made from a boss drop: Bone Armor and Helm, Shield of Terror, Eye Mask, Scalemail, Hibearnation Vest, Eyebrella, Bee Queen Crown, Turf-Raiser Helm, Weather Pain, Spiderhat, Enlightened Crown."),
    allow("kit", "Kit gear", "Brightshade, Void cloth and W.A.R.B.I.S. gear (normally fixed with a repair kit), plus Dreadstone (heals itself)."),
    allow("light", "Light sources", "Torch, Morning Star, lighter, lantern, miner hat, moggles and red lantern."),
    allow("refillable", "Refillable", "Watering cans and other items that are refilled rather than repaired."),
}
