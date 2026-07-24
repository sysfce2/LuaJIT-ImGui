--flush for popen:read"*l"
io.stdout:setvbuf"no"

--[[
print"=======================================I am runner"
local argva = {...}

if argva then
print("argva--------")
for k,v in pairs(argva) do
    print(k,v)
end
end
if arg then
print("arg--------")
for k,v in pairs(arg) do
    print(k,v)
end
end
--]]
-----------------------------------------------
local inprocess
local pathut = require"imgui.libs.path"
local file_path = pathut.file_path()
local Debugger = dofile(pathut.chain(file_path,"debugger.lua"))
local serializer = require"imgui.libs.serializer"

local xpcallerror
xpcallerror = function(err)
     --print"===========xpcallerror=============="
      if tostring(err):match"stack overflow" then
		debug.sethook()
        io.write("stack overflow\n")
        --local debinfo = debug.getinfo(2,"Slf")
        --print(debinfo.source, debinfo.currentline)
		return --err
     end
     local lvl = 3
     --print("xpcallerror1: "..err)
     if err:match("debug cancel$") then
        print"debug cancel detected"
        lvl = 4
     end
    ---- detect recursive error
    for i=2,math.huge do
        local debuginfo = debug.getinfo(i,"Snlf")
        if not debuginfo then break end
        if debuginfo.func == xpcallerror then
            print("========recursive error",err)
            print(debug.traceback())
            return
        end
    end

    local debuginfo = debug.getinfo(lvl,"Slf")

    local stack,vars = Debugger:get_call_stack(lvl + 1) 

    -- vars can have cycles so serialize for Keeper
    --Debugger.send_debuginfo(debuginfo.source,debuginfo.currentline,Debugger.cleanStack(stack), err, serializer("tab_name",vars,";").."return tab_name;")
    Debugger.send_debuginfo(debuginfo.source,debuginfo.currentline,Debugger.cleanStack(stack), err, vars)
    --print("========xpcallerror ended: ",debuginfo.source,debuginfo.currentline,stack,vars)
    --print("traceback",debug.traceback(2))
    print("======= error:",err)

end


local function load_script(script)
        local fs, err = loadfile(script)
        if not fs then
            --send stack
            local info = {}
            info.source = "@"..script
            info.currentline = err:match(":(%d*):") or -1
            Debugger.send_debuginfo(info.source, info.currentline,{info}, err, {}, true) --compile error
            return error"compile loadfile error"
        else
            return fs
        end
end
FINALIZER = function(ok,val) print("---i am runner finalizer",ok,val) end

--runs from f in loadfile
if not arg then
    --print"returnning function"
    inprocess = true
    return function(script, K, debuggerlinda, bp, do_debug)
        local old_print2 = print
        print = function(...)
            old_print2(...)
            local args = {}
            for i=1,select("#",...) do
                args[i] = tostring(select(i,...))
            end
            local str = table.concat(args,"\t")
            K:send("clave",str)
        end

        --local bp = {breakpoints = {[10] = {["@"..script] = true}}}
        Debugger:init(do_debug, bp, K, debuggerlinda)
        
        --local ok,err = xpcall(load_script(script), xpcallerror)
        local err
        local ok,fs = pcall(load_script, script)
        if not ok then --compile error
            print("compile error",fs)
            return 2
        else
            ok, err = xpcall(fs, xpcallerror)
        end
        --print("xpcall ",tostring(ok)," ",tostring(err),"\n")
		debug.sethook()
		print = old_print2
        if ok then
            return 1
        else
            -- if err then
                -- print("error:",err)
            -- end
            return 3
        end
    end
    
else
    --runs in another process
    inprocess = false
    ---- receives from deblindaS in runner
    local deblinda = {}
    function deblinda:init()
        self.file,err = io.open(pathut.chain(file_path,"debuggerlinda"),"r")
        self.received = {}
        assert(self.file, err)
    end
    function deblinda:receive(...)
        while true do
            local line = self.file:read"*l"
            if line then
                --print("receive",line)
                local k,v = line:match("key(.+)value(.+)")
                local TABLE = v:match("^TABLE(.+)")
                if TABLE then
                    v = loadstring(TABLE)()
                end
                self.received[k] = self.received[k] or {}
                table.insert(self.received[k],v)
            else
                break
            end
        end
        
        for i,kr in ipairs{...} do
            if self.received[kr] and #self.received[kr] > 0 then
                return kr,table.remove(self.received[kr],1)
            end
        end
    end
    
    -- for sending to process which called popen and call read"*l"
    -- will be used by key: debugger
    local Sender = {}
    function Sender:send(key,value)
        value = serializer("tab_name", value, ";").."return tab_name;"
        print(key.."XXXX"..value)
    end

    assert(arg[1], "no script given to runner.lua")
    local script = arg[1]
    
    --get initial breakpoints 
    local bp
    --check existence, only exists if do_debug
    local brf,err = io.open(pathut.chain(file_path,"breakpoints"),"r")
    if brf then
        brf:close()
        bp = dofile(pathut.chain(file_path,"breakpoints"))
    end
    
    assert(not script:match"runner.lua","dont execute runner in other process")
    
    local do_debug = bp and true or false
    deblinda:init()
    Debugger:init(do_debug, bp, Sender, deblinda)
    
    local err
    local ok,fs = pcall(load_script, script)
    if not ok then --compile error
        print("compile error",fs)
        print("eretXXXX"..tostring(2))
        return 
    else
        ok, err = xpcall(fs, xpcallerror)
    end
    --print("xpcall ",tostring(ok)," ",tostring(err),"\n")

    local eret
    if ok then
        eret = 1
    else
        -- if err then
            -- print("error:", err) 
        -- end
        eret = 3
    end
    -- sending to popen
    -- for key: eret
    print("eretXXXX"..tostring(eret))
end