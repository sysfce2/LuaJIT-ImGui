--- debugger module
-- @warning need to copy not to make lanes transfer functions
local Debugger = {}
local send_debuginfo = function() end
local print_if_verbose = function() end
local serializer = require"imgui.libs.serializer"


local function cleanStack(stack)
    for i,v in ipairs(stack) do
        for k,val in pairs(v) do
            if k=="func" then
                v[k] = tostring(val)
            end
        end
    end
    return stack
end
Debugger.cleanStack = cleanStack
--all goes to string without \r\n except tables
local function debugger_copy(object,lookup_table)

    local basicCopy = function(ob)
        if type(ob)=="string" then
            ob = ob:gsub("[\n\r]","") --in case it goes to stdout
            return ob
        else
            return tostring(ob)
        end
    end
    local function _copy(object)
            --print("debugger",ToStr(object))
        if type(object) ~= "table" then
            return basicCopy(object)
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[tostring(index)] = _copy(value)
            --new_table[_copy(index)] = _copy(value)
            --tables are not linda transfered in keys
            --new_table[ToStr(index)] = _copy(value)
        end
        local mt = getmetatable(object)
        if mt then
            new_table.METATABLE = _copy(mt)
            --setmetatable(new_table, _copy(mt))
        end
        return new_table
    end
    return _copy(object)
end

function Debugger:get_call_stack(inilevel)
    local thread, is_main_thread = coroutine.running()
    local deph = self.maxdeph or math.huge
    --print("staklevel",deph)
    local endlevel = inilevel + deph
    local stack = {}
    local vars = {}
    local lookup_table = {}
    for level = inilevel or 1,endlevel do
        local stlevel = level - inilevel + 1
        local stinfo = debug.getinfo( level,"Snlf")
        if not stinfo then return stack,vars end

        stack[stlevel] = stinfo
        --locals
        vars[stlevel] = {locals= {},upvalues= {}}
        local i = 1
        while true do
            local name,value = debug.getlocal( level,i)
            if not name then break end
            if string.sub(name, 1, 1) ~= '(' then
                vars[stlevel].locals[name] = debugger_copy(value,lookup_table)
            end
            i = i + 1
        end
        local func = stinfo.func
        local i = 1
        while func do
            local name,value = debug.getupvalue(func,i)
            if not name then break end
            vars[stlevel].upvalues[name] = debugger_copy(value,lookup_table)
            i = i + 1
        end
        -- dont force lanes to send function
        --stinfo.func = nil
    end
    return stack,vars
end
local function getstacklevel()
    for i = 1,math.huge do
        if not debug.getinfo(i,"l") then return i end
    end
end
local function is_stacklevel_lower(level)
    return not debug.getinfo(level,"l")
end

local pathsc = require"imgui.libs.path"
local function absolutePath(path)
    return "@"..pathsc.abspath(path:sub(2))
end
function Debugger.hook_call_ret(event)
    local func = debug.getinfo(2,"f").func

    if Debugger.functable[func]==nil then
        local debuginfo = debug.getinfo(2,"SL")
        local activelines = debuginfo.activelines
        local source = absolutePath(debuginfo.source)
        --local source = debuginfo.source
        --print(source,path.abspath(source))
        for i,line in ipairs(activelines) do
            if Debugger.breakpoints[line] and Debugger.breakpoints[line][source] then
                Debugger.functable[func] = true
            end
        end
        Debugger.functable[func] = false
    end
end
local cancelcount = 0
local debuggerlinda
--- get Sleep
local has_lptime, lp_time = pcall(require, "luapower.time")
--has_lptime = false
--print("has_lptime, lp_time", has_lptime, lp_time)
-------make cheap solution
local Sleep
if not has_lptime then
    local ffi = require"ffi"
    if ffi.os == "Windows" then
        ffi.cdef[[void deb_Sleep(uint32_t) asm("Sleep");]]
        Sleep = function(ti)
            ffi.C.Sleep(ti*1000)
        end
    else
        ffi.cdef[[unsigned int deb_sleep(unsigned int) asm("sleep");]]
        Sleep = function(ti)
            ffi.C.sleep(ti)
        end
    end
end
function Debugger.debug_hook (event, line)
    --if event~="line" then print(event, line) end
    --print_if_verbose(event,line,tostring(debuggerlinda),"\n")

    cancelcount = cancelcount + 1
    if cancelcount > 10 then
        cancelcount = 0
        -- if cancel_test() then
            -- error(lanes.cancel_error)
        -- end
        if debuggerlinda:receive("cancel") then
            print("debug cancel")
            local Thread = require"lj-async.thread"
            debug.sethook()
            --Thread.exit(9)
            os.exit() --only when inprocess = false
            --error"cancel"
        end
        if debuggerlinda:receive("break") then
            Debugger.step_into = true
            Debugger.step_over = false
        end
    end

    if Debugger.breakpoints[line] or Debugger.step_into or Debugger.step_over then
        local thread, is_main_thread = coroutine.running() --or 0
        --print("coroutine.running", thread, is_main_thread)
        local debuginfo = debug.getinfo(2,"S")
        local s = absolutePath(debuginfo.source)

        --local s = debuginfo.source
        --print(s,path.abspath(s))
        --debug_print("trace",event, line,s,Debugger.step_over,Debugger.step_into)
        if (Debugger.step_over and Debugger.laststacklevel[thread] and is_stacklevel_lower(Debugger.laststacklevel[thread])
        or Debugger.step_into 
        or (Debugger.breakpoints[line] and Debugger.breakpoints[line][s])) then
            --debug_print(s , ":" , line,Debugger.step_into,Debugger.step_over , getstacklevel())
            --print(ToStr(debuginfo))
            --debug_print(debug.traceback("traceback",2))
            Debugger.step_into = false
            Debugger.step_over = false
            
            local stack,vars = Debugger:get_call_stack(3)
            --print("get_call_stack",ToStr(vars))
            print_if_verbose("debugger going to send_debuginfo\n")
            
            -- serializer to avoid cycles in table
            --send_debuginfo(s,line, cleanStack(stack), "debugging this line", serializer("tab_name",vars,";").."return tab_name;")
            send_debuginfo(s,line, cleanStack(stack), "debugging this line", vars)
            print_if_verbose("debugger going to loop\n")
            print_if_verbose("debugger11",event,line,tostring(debuggerlinda),"\n")
            while true do
                local key,val = debuggerlinda:receive("continue","debug_exit","step_into","step_over","step_out","brpoints")
                --if key then print("debuggerlinda",key,val) end
                if key == "debug_exit" then
                    debug.sethook()
                    break
                elseif key == "continue" then
                    break
                elseif key == "step_into" then
                    Debugger.step_into = true
                    break
                elseif key == "step_over" then
                    Debugger.laststacklevel[thread] = getstacklevel()
                    Debugger.step_over = true
                    break
                elseif key == "step_out" then
                    Debugger.laststacklevel[thread] = getstacklevel()-1
                    Debugger.step_over = true
                    break
                elseif key == "brpoints" then
                    --print(val[1],val[2],val[3])
                    if val[1] == "add" then
                        Debugger.breakpoints[val[3]] = Debugger.breakpoints[val[3]] or {}
                        Debugger.breakpoints[val[3]][val[2]] = true
                    else --delete
                        if Debugger.breakpoints[val[3]] then
                            Debugger.breakpoints[val[3]][val[2]] = nil
                        end
                    end
                elseif key==nil then
                    --sleep a while for CPU
                    if has_lptime then
                        lp_time.sleep(0.01)
                    else
                        Sleep(0.01)
                    end
                end
            end
        end
    end
end

function Debugger:init(do_debug, bp, K,Kdebuggerlinda,verbose, maxdeph)
    print_if_verbose("debugger: debuggerlinda soy yo", tostring(Kdebuggerlinda),"\n")
    debuggerlinda = Kdebuggerlinda
    bp = bp or {}
    if verbose then
        print_if_verbose = function(...)
            return io.write(...)
        end
    end

    send_debuginfo = function(...)
        --local str = serializer("tab_name1",{...})
        --print(str)
        --print_if_verbose("going to send\n")
        K:send("debugger",{...})
        --print_if_verbose("senddebuginfo done\n")
    end
    self.send_debuginfo = send_debuginfo
    self.maxdeph = maxdeph
    self.step_over = false
    self.step_into = false
    self.laststacklevel = {} 
    self.functable = {}
    self.breakpoints = bp.breakpoints or {}
    --clean linda
    local keys = {"continue","debug_exit","step_into","step_over","step_out","brpoints","break"}
    -- TODO for i,v in ipairs(keys) do debuggerlinda:set(v) end
    -- meanwhile:
    while true do
        local key, value = debuggerlinda:receive(unpack(keys))
        if not key then break end
    end
    if do_debug then
        --for debugging coroutines
        local oldcocreate = coroutine.create
        coroutine.create = function(f)
                local thread = oldcocreate(f) 
                --print("coroutine.running() is", thread, Debugger.debug_hook)
                debug.sethook(thread, Debugger.debug_hook, "l")
                return thread
            end
            
        debug.sethook(Debugger.debug_hook, "l")
        
        -- local f,m,c = debug.gethook ()
        -- print("gethook",f,m,c)
        -- print("gethook",type(f),type(m),type(c))
    end
end
return Debugger



