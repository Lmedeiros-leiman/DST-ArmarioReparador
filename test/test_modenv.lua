-- Regression test for the DST mod environment contract.
-- modimport runs the imported file in the shared mod env; modmain must then
-- find the module table as a global in that same env.
-- Run from the mod root: lua5.1 test/test_modenv.lua

local mod_root = arg[0]:match("^(.*)/test/test_modenv%.lua$")
if mod_root == nil or mod_root == "" then
    mod_root = "."
end

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
}
env.env = env
env.modimport = function(modulename)
    if string.sub(modulename, #modulename - 3, #modulename) ~= ".lua" then
        modulename = modulename .. ".lua"
    end
    local chunk = assert(loadfile(env.MODROOT .. modulename))
    setfenv(chunk, env.env)
    chunk()
end

env.modimport("wardrobe_restorer_math.lua")

-- This mirrors exactly what modmain.lua does after modimport.
local mathmod = env.wardrobe_restorer_math

if type(mathmod) ~= "table" then
    io.stderr:write("FAIL: wardrobe_restorer_math global not visible to modmain\n")
    os.exit(1)
end
if type(mathmod.recover) ~= "function" or type(mathmod.recovery_delta) ~= "function" then
    io.stderr:write("FAIL: module functions missing\n")
    os.exit(1)
end
if math.abs(mathmod.recover(0, 100, 5, 480) - 5) > 1e-9 then
    io.stderr:write("FAIL: recover math changed\n")
    os.exit(1)
end

print("modenv contract OK")
