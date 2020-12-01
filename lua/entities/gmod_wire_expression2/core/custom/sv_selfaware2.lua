-- Author: Vurv, define runtime functions

--[[
   _____        __ ____   ___                                  ___
  / ___/ ___   / // __/  /   | _      __ ____ _ _____ ___     |__ \
  \__ \ / _ \ / // /_   / /| || | /| / // __ `// ___// _ \    __/ /
 ___/ //  __// // __/  / ___ || |/ |/ // /_/ // /   /  __/   / __/
/____/ \___//_//_/    /_/  |_||__/|__/ \__,_//_/    \___/   /____/

 Adds functions similarly to regular-e2's self-aware core.
]]

local isfunction, debug_getinfo = isfunction, debug.getinfo
local string_find, string_sub, table_GetKeys = string.find, string.sub, table.GetKeys
local luaTableToE2, getE2UDF, getE2Func = vex.luaTableToE2, vex.getE2UDF, vex.getE2Func

-- TODO: Set E2 costs ( __e2setcost(N) ).

-- Ex: print(defined("print(...)")) or print(defined("health(e:)"))
-- Returns number, 0 being not defined, 1 being defined as an official e2 function, 2 being a user-defined function.
-- Note: If you are checking for availability of the builtin function and if you know the signature ahead of time,
--       then it is preferred to use #ifdef pre-processor statement; this function exists for dynamic kind of checks.
e2function number defined(string funcname)
    -- Check UDF first (see the above note for why).
    local isUDF, udfDirect = getE2UDF(self, funcname)
    if udfDirect then return 2 end -- UDF perfect match.
    local isFunc, funcDirect = getE2Func(self, funcname)
    if funcDirect then return 1 end -- Builtin perfect match.
    -- Name only match after this point :(
    -- Which one to prefer if they are both defined with identical name? It makes sense to prefer UDF?    *smh*
    -- Should this return a negative number to indicate uncertainity?
    -- To be honest, this function should be split into 2, respectively. To avoid such dilemma...
    if isUDF --[[and not isFunc]] then return 2 end -- Found named UDF match.
    if isFunc --[[and not isUDF]] then return 1 end -- Found named builtin match.
    return 0
end

-- Ex: print(getFunctionPath("print(...)")) would print the path to .../core/debug.lua file.
-- Returns the path where the function was defined, useful for finding whether something was added with an addon.
e2function string getFunctionPath(string funcname)
    local func = getE2Func(self, funcname)
    -- source is better than short_src, because it can help identify custom addon/core more easily.
    return isfunction(func) and debug_getinfo(func, "S").source or ""
end

-- Returns an array containing only names of all User-Defined Functions.
e2function array udfNames()
    -- Populate keys on the table (to avoid duplicate entries) and then get the keys on return.
    local ret = {}
    for name in pairs(self.funcs_ret) do
        local idx = string_find(name, "(", 2, true) -- This should never return a nil.
        ret[string_sub(name, 1, idx - 1)] = true
    end
    return table_GetKeys(ret)
end

--[[-------------------------------------------------------------------------------------------------------------------
    Returns a table containing useful information about all User-Defined Functions.
    This function can operate differently, the `mode` argument controls how the output table will be structured:
        Mode 0 (aka Flat): [See below].
        Mode 1 (aka D&C) : [See below].
    This design is used specifically to avoid making an additional E2 functions (additional modes can be added later).
    For example, if you define the following UDFs in your E2:
        function void foo(Num, Text:string)
        function string entity:myFunc(Col:vector4, Ar:array)
        function table entity:myFunc(Rot:angle, Pos:vector)
    You would get the following table in Mode 0 (aka Flat):
        {
            ["foo(ns)"] = { [1]="", [2]="", [2] = "Num,Text", [3]="myfuncs.txt:1" },
            ["myFunc(e:xv4r)"] = { [1]="s", [2]="Col,Ar", [3]="myfuncs.txt:4" },
            ["myFunc(e:av)"] = { [1]="t", [2]="Rot,Pos", [3]="myfuncs.txt:7" }
        }
    You would get the following table in Mode 1 (aka D&C):
        {
            ["foo"] =
            {
                { [1]="ns", [2]="", [3]="Num,Text", [4]="myfuncs.txt:1" }
            },
            ["myFunc"] =
            {
                { [1]="e:xv4r", [2]="s", [3]="Col,Ar", [4]="myfuncs.txt:4" },
                { [1]="e:av", [2]="t", [3]="Rot,Pos", [4]="myfuncs.txt:7" }
            }
        }
---------------------------------------------------------------------------------------------------------------------]]
local UDF_ALL_MODES = {
    [vex.registerConstant("UDF_ALL_FLAT", 0)] =
        function(self)
            --[[--
            Table key is the same string as in the funcs_ret table (name + signature).
            Table value is an array:
                [1] = Return type (ID) string as reported by funcs_ret  (empty string if void)
                [2] = Comma-separated string containing names of arguments
                [3] = Filename and line number specifying where the UDF is defined at (within the current E2)
            --]]--
            local funcs_ret = self.funcs_ret
            --print("[E2 funcs_ret]") PrintTable(funcs_ret, 1) -- Quick debugging shit...
            local res = {}
            -- MYTODO
            for name,returnType in pairs(funcs_ret) do
                res[name] = { [1] = returnType or "" }
            end
            return luaTableToE2(res, true) -- Convert to E2 table with array optimization.
        end;
    [vex.registerConstant("UDF_ALL_DNC", 1)] =
        function(self)
            --[[--
            Table key is made of just the name of the UDF.
            Table value is a table of tables containing:
                [1] = Function signature (extracted portion between parentheses of the funcs_ret key)
                [2] = Return type (ID) string as reported by funcs_ret  (empty string if void)
                [3] = Comma-separated string containing names of arguments
                [4] = Filename and line number specifying where the UDF is defined at (within the current E2)
            --]]--
            local funcs_ret = self.funcs_ret
            --print("[E2 funcs_ret]") PrintTable(funcs_ret, 1) -- Quick debugging shit...
            local res = {}
            -- MYTODO
            return luaTableToE2(res, false) -- Convert to E2 table without array optimization.
        end;
}
e2function table udfAll(mode)
    mode = UDF_ALL_MODES[mode]
    return mode and mode(self) or luaTableToE2{}
end