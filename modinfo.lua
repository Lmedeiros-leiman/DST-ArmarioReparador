name = "Wardrobe Storage and Repair"
description = [[Turns the wardrobe into a 20 slot chest that slowly repairs the equipment stored inside. Left click opens the storage, right click changes skins.]]
author = "Frytura"
version = "1.3.0"

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
    {
        name = "recovery_rate",
        label = "Recovery (%/day)",
        hover = "Durability recovered per day. 5% takes an item from 0% to 100% in 20 days.",
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
        hover = "Categories that recover at half the configured rate. Magical: staffs, amulets, pan flute, shadow gear (the Lazy Forager counts as a tool). Tools: tools, weapons and armor. Clothing: sewable items.",
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
}
