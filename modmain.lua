-- Wardrobe Restorer
-- Adds chest storage to the vanilla wardrobe and slowly restores the
-- durability of items stored inside. Left click keeps the skin-change menu,
-- right click opens the storage.

modimport("wardrobe_restorer_math.lua")
local mathmod = wardrobe_restorer_math

local containers = GLOBAL.require("containers")
local Vector3 = GLOBAL.Vector3

local layout = mathmod.get_slot_layout(GetModConfigData("num_slots"))

local slotpos = {}
for _, point in ipairs(mathmod.build_grid(layout.num_slots, layout.cols, layout.spacing)) do
    table.insert(slotpos, Vector3(point.x, point.y, 0))
end

containers.params.wardrobe_restorer =
{
    widget =
    {
        slotpos = slotpos,
        animbank = layout.bank,
        animbuild = layout.bank,
        pos = Vector3(0, layout.pos_y, 0),
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

local function recover_items_in(inst, rate, dt)
    local container = inst.components.container
    if container == nil or inst:HasTag("burnt") then
        return
    end
    for slot = 1, container:GetNumSlots() do
        local item = container:GetItemInSlot(slot)
        local comps = item ~= nil and item.components or nil
        -- Items that rot never recover (and should not be stored anyway).
        if comps ~= nil and comps.perishable == nil then
            local finiteuses = comps.finiteuses
            if finiteuses ~= nil and finiteuses.current < finiteuses.total then
                finiteuses:Repair(mathmod.recovery_delta(finiteuses.total, rate, dt))
            end
            local armor = comps.armor
            if armor ~= nil
                and not armor:IsIndestructible()
                and armor.condition < armor.maxcondition then
                armor:SetCondition(armor.condition + mathmod.recovery_delta(armor.maxcondition, rate, dt))
            end
            -- Covers fueled amulets and clothing. Items the game marks as
            -- unrepairable keep that rule.
            local fueled = comps.fueled
            if fueled ~= nil
                and not fueled.no_sewing
                and fueled.maxfuel ~= nil and fueled.maxfuel > 0
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

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("wardrobe_restorer")

    local rate = GetModConfigData("recovery_rate") or 5
    inst.components.container:SetNumSlots(layout.num_slots)

    inst:DoPeriodicTask(1, function()
        recover_items_in(inst, rate, 1)
    end)

    inst.OnLongUpdate = function(inst_, dt)
        recover_items_in(inst_, rate, dt)
    end

    -- Same open/close feedback the wardrobe uses while changing skins.
    inst.components.container.onopenfn = function(inst_)
        if not inst_:HasTag("burnt") then
            inst_.AnimState:PlayAnimation("open")
            inst_.SoundEmitter:PlaySound("dontstarve/common/wardrobe_open")
        end
    end
    inst.components.container.onclosefn = function(inst_)
        if not inst_:HasTag("burnt") and inst_.AnimState:IsCurrentAnimation("open") then
            inst_.AnimState:PlayAnimation("cancel")
            inst_.SoundEmitter:PlaySound("dontstarve/common/wardrobe_close")
        end
    end
end)
