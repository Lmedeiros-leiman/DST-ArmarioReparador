-- Wardrobe Storage and Repair
-- Adds chest storage to the vanilla wardrobe and slowly restores the
-- durability of items stored inside. Left click keeps the skin-change menu,
-- right click opens the storage.

modimport("wardrobe_restorer_math.lua")
local mathmod = wardrobe_restorer_math

local containers = GLOBAL.require("containers")
local Vector3 = GLOBAL.Vector3

local layout = mathmod.get_slot_layout(GetModConfigData("num_slots"))
local recovery_rate = GetModConfigData("recovery_rate") or 5
local halved = mathmod.parse_half_rate(GetModConfigData("half_rate") or "magical")

local slotpos = {}
for _, point in ipairs(mathmod.build_grid(layout.num_slots, layout.cols, layout.spacing)) do
    table.insert(slotpos, Vector3(point.x, point.y, 0))
end

-- Clients set up the widget from the prefab name, so the params must be
-- keyed by "wardrobe" or the client gets no widget and crashes on open.
containers.params.wardrobe =
{
    widget =
    {
        slotpos = slotpos,
        animbank = layout.bank,
        animbuild = layout.bank,
        pos = Vector3(0, layout.pos_y, 0),
        slotscale = layout.slotscale,
        side_align_tip = 160,
    },
    type = "chest",
    -- Equipment only, nothing that rots. Server path checks components
    -- (authoritative); client path checks the replica and networked tags,
    -- same pattern the vanilla fish box uses.
    itemtestfn = function(container, item, slot)
        if item.components ~= nil and item.components.equippable ~= nil then
            return mathmod.accepts_item(true, item.components.perishable ~= nil)
        end
        return mathmod.accepts_item(
            item.replica ~= nil and item.replica.equippable ~= nil,
            item:HasTag("show_spoilage"))
    end,
}

-- container_classified preallocates MAXITEMSLOTS slot netvars, sized at load
-- time to the largest vanilla container (20). Grids above that would run out
-- of netvars and crash when a wardrobe spawns.
containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, layout.num_slots)

-- The built-in container collector already adds RUMMAGE on both click sides.
-- On left clicks we also offer CHANGEIN, which has the higher priority, so
-- left click resolves to the skin menu and right click resolves to RUMMAGE.
AddComponentAction("SCENE", "container", function(inst, doer, actions, right)
    if right
        or not inst:HasTag("wardrobe_restorer")
        or inst:HasTag("burnt")
        or inst.replica.container == nil
        or not inst.replica.container:CanBeOpened()
        or doer.replica.inventory == nil
        or (doer.replica.rider ~= nil and doer.replica.rider:IsRiding())
    then
        return
    end
    table.insert(actions, GLOBAL.ACTIONS.CHANGEIN)
end)

local function recover_items_in(inst, dt)
    -- Burning removes the container, which also ends the repairs.
    local container = inst.components.container
    if container == nil then
        return
    end
    for _, item in pairs(container.slots) do
        local comps = item.components
        -- Items that rot never recover (and should not be stored anyway).
        if comps.perishable == nil then
            local fueled = comps.fueled
            -- Selected categories recover at a fraction of the configured rate.
            local rate = recovery_rate * mathmod.rate_multiplier(halved, item.prefab,
                fueled ~= nil and fueled.fueltype == GLOBAL.FUELTYPE.USAGE)
            -- Each component clamps at its maximum. Full items are skipped so
            -- they do not push percentusedchange on every step.
            local finiteuses = comps.finiteuses
            if finiteuses ~= nil and finiteuses.current < finiteuses.total then
                finiteuses:Repair(mathmod.recovery_delta(finiteuses.total, rate, dt))
            end
            -- SetCondition ignores indestructible armor.
            local armor = comps.armor
            if armor ~= nil and armor.condition < armor.maxcondition then
                armor:SetCondition(armor.condition + mathmod.recovery_delta(armor.maxcondition, rate, dt))
            end
            -- Covers fueled amulets and clothing. Items the game marks as
            -- unrepairable keep that rule.
            if fueled ~= nil
                and not fueled.no_sewing
                and fueled.maxfuel > 0
                and fueled.currentfuel < fueled.maxfuel then
                fueled:DoDelta(mathmod.recovery_delta(fueled.maxfuel, rate, dt))
            end
        end
    end
end

AddPrefabPostInit("wardrobe", function(inst)
    inst:AddTag("wardrobe_restorer")

    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    -- Drop the built-in wardrobe scene collector so CHANGEIN is only offered
    -- by our container collector above.
    inst:UnregisterComponentActions("wardrobe")

    -- WidgetSetup also sets the slot count from the widget's slot positions.
    inst:AddComponent("container")
    local container = inst.components.container
    container:WidgetSetup("wardrobe")

    -- Same open/close feedback the wardrobe uses while changing skins.
    container.onopenfn = inst.components.wardrobe.onopenfn
    container.onclosefn = inst.components.wardrobe.onclosefn

    -- One repair step per day segment (16 per day) rather than every second.
    inst:DoPeriodicTask(mathmod.SEGMENT_LENGTH_SECONDS, recover_items_in, nil, mathmod.SEGMENT_LENGTH_SECONDS)
    inst.OnLongUpdate = recover_items_in

    -- The vanilla hammer callback only drops the recipe loot, which would
    -- delete everything stored inside.
    local workable = inst.components.workable
    if workable ~= nil then
        local onfinish = workable.onfinish
        workable:SetOnFinishCallback(function(inst_, worker)
            if inst_.components.container ~= nil then
                inst_.components.container:DropEverything()
            end
            if onfinish ~= nil then
                onfinish(inst_, worker)
            end
        end)
    end

end)
