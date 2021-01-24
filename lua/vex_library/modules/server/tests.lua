-- This module will run all of the tests in VExtensions/lua/tests.
-- It will do this by using vex.runE2.

local Tokenizer,Parser,Optimizer,Compiler = E2Lib.Tokenizer, E2Lib.Parser, E2Lib.Optimizer, E2Lib.Compiler

-- Out of all the things for the E2Lib to not have, they are missing this. So... we have to copy the code.
-- Nice.
local ScopeManager = {}
ScopeManager.__index = ScopeManager

function ScopeManager:InitScope()
    self.Scopes = {}
    self.ScopeID = 0
    self.Scopes[0] = self.GlobalScope or { vclk = {} } -- for creating new enviroments
    self.Scope = self.Scopes[0]
    self.GlobalScope = self.Scope
end

function ScopeManager:PushScope()
    self.Scope = { vclk = {} }
    self.ScopeID = self.ScopeID + 1
    self.Scopes[self.ScopeID] = self.Scope
end

function ScopeManager:PopScope()
    self.ScopeID = self.ScopeID - 1
    self.Scope = self.Scopes[self.ScopeID]
    self.Scopes[self.ScopeID] = self.Scope
    return table.remove(self.Scopes, self.ScopeID + 1)
end

function ScopeManager:SaveScopes()
    return { self.Scopes, self.ScopeID, self.Scope }
end

function ScopeManager:LoadScopes(Scopes)
    self.Scopes = Scopes[1]
    self.ScopeID = Scopes[2]
    self.Scope = Scopes[3]
end

-- Someone rename this pls
-- E2 construction assumes the entity has a few properties
-- (inports, outports), so we'll add them here.
local function initEntity( ent )
    ent.outports = { {}, {}, {} }
    ent.inports = { {}, {}, {} }
end

local function newE2Instance()
    local ctx = setmetatable({
        data = {},
        vclk = {},
        funcs = {},
        funcs_ret = {},
        entity = game.GetWorld(), -- Supposed to be the chip.
        player = game.GetWorld(),
        uid = IsValid(owner) and owner:UniqueID() or "World",
        prf = 0,
        prfcount = 0,
        prfbench = 0,
        time = 0,
        timebench = 0,
        includes = {}
    },ScopeManager)
    ctx:InitScope()
    initEntity( ctx.entity )
    local ok, why = pcall(wire_expression2_CallHook, "construct", ctx)
    if not ok then
        -- If constructing fails in the process, cleanup
        error("Failed to construct virtual e2 instance.\n" .. why)
        pcall(CallHook, ctx, "destruct")
    end
    return ctx
end

-- Runs E2 Code purely from code. No chip. (No outputs / inputs will be used.)
-- Also runs the preprocessor in order to get persists.
-- Will always run in safe mode
local function runE2Virtual( code )
    local ctx = newE2Instance()
    local status, directives, code = E2Lib.PreProcessor.Execute(code,nil,ctx)
    if not status then return false, directives end -- Preprocessor failed.
    local status, tokens = Tokenizer.Execute(code)
    if not status then return false, tokens end -- Tokenizer failed.
    local status, tree, dvars = Parser.Execute(tokens)
    if not status then return false, tree end -- Parser failed.
    status,tree = Optimizer.Execute(tree)
    if not status then return false, tree end -- Optimizer failed.
    local status, script, inst = Compiler.Execute(tree, {}, {}, directives.persist[3], dvars, {})
    if not status then return false, script end -- Compiler failed

    local success,why = pcall( script[1], ctx, script )
    return success,(not success) and why or nil -- Need to flip logic for the second arg because of lua's 'ternary'
end

vex.addConsoleCommand("vex_test",function(_, cmd, args)
    local failed = false
    for _, file_name in pairs( file.Find( vex.path .. "tests/*.txt" , "GAME" ) ) do
        local success, err = runE2Virtual( file.Read(vex.path .. "tests/" .. file_name,"GAME") )
        if not success then
            vex.printf("%s test failed. [%s]", file_name, err)
            failed = true
        end
    end
    if failed then print("Some tests failed!") end
end)