--WINUSEPTHREAD=true
local hasThread, Thread = pcall(require, "lj-async.thread")

if not hasThread then
    return {Execute = nil, ExecutePull = function() end, debuggerlinda = debuggerlinda, hasThread = hasThread}
end

---------get LuaJIT path
local function get_executable(arg)
    local i=0
    local v
    while true do 
        v = arg[i]
        if not v then
            i = i + 1 --was the last (inverse order)
            break
        end
        i = i - 1
    end
    return arg[i]
end

local executable = get_executable(arg)

---------for in process
local Kmaker = require"lj-async.keeper"
local K = Kmaker.MakeKeeper()
local debuggerlinda = Kmaker.MakeKeeper()
---------for out process
local pathut = require"imgui.libs.path"
local file_path = pathut.file_path()
local serializer = require"imgui.libs.serializer"
--print("executer file_path:",file_path)
--- for out process sends to deblinda in runner
local deblindaS = {}
function deblindaS:init()
    self.file,err = io.open(pathut.chain(file_path,"debuggerlinda"),"w")
    assert(self.file, err)
end
function deblindaS:close()
    if self.file then
        self.file:close()
    end
end

function deblindaS:send(key, value)
    if type(value)=="table" then
        value = "TABLE"..serializer("ttt",value,";").."return ttt;"
    end
    self.file:write("key"..tostring(key).."value"..tostring(value).."\n")
    self.file:flush()
end

local deblinda

local os_execute_async = function(executable, cmd, inprocess, K, debuggerlinda, breakpoints, do_debug, ...)
    local Thread = require"lj-async.thread"
    local Kmaker = require"lj-async.keeper"
    K = Kmaker.KeeperCast(K)
    debuggerlinda = Kmaker.KeeperCast(debuggerlinda)
    local args = {...}
    return function(ud)
        local ffi = require"ffi"
        
        --print("thread curpath",file_path)
        --package.path = file_path.."/?.lua;"..package.path
        --print("thread package path",package.path)
        
        -- K:send("clave","going to execute")
        -- K:send("clave","inprocess: "..tostring(inprocess))
        -- K:send("clave",nil)
        -- K:send("clave","una linea\notra linea\n")
        -- K:send("clave","inprocess end")
        
        local ret
        if inprocess then
        ---[[--------loadstring bad for same process sdl or glfw
        local f,err = loadfile(file_path.."/runner.lua")--cmd)
        if f then 
            ret = f()(cmd, K, debuggerlinda, breakpoints, do_debug) 
        else 
            K:send("clave","loadfile error:"..tostring(err)) 
        end
        --]]
        else
        
        ---for another process we have:
        ------- 1 execute
        -- but needs ipc 
        --local ret = os.execute(executable.." ".." ./libs/runner.lua "..cmd)
        
        --------2 popen
        --pero se me queda pegado en exe:read("*l") hasta que el programa acaba y viene a ser como execute
        --pero leo stdout
        ---[=[
        local serializer = require"imgui.libs.serializer"
        --send initial breakpoits via a file which runner will get
        if do_debug then
            local breakstr = serializer("tab_name",breakpoints,";")..";return tab_name;"
            local f,err = io.open(file_path.."/breakpoints","w")
            assert(f,err)
            f:write(breakstr)
            f:close()
        else
            os.remove(file_path.."/breakpoints")
        end
        
        local pcomand = executable.." ".." "..file_path.."/runner.lua "..cmd
        if jit.os == "Windows" then pcomand = [["]]..pcomand..[["]] end
        --K:send("clave","pcomand is:"..pcomand)
        local exe,err = io.popen(pcomand, "r")
        if not exe then
            K:send("clave","Could not popen. Error: "..tostring(err))
        else
            --K:send("clave","exe opened. Error: "..tostring(err))
            exe:setvbuf("no")
            --K:send("clave","going to lopp............")
            repeat
                exe:flush()
                local line = exe:read("*l")
                if line then
                    if line == "" then
                    elseif line:match"^debuggerXXXX" then
                        local value = line:match("debuggerXXXX(.+)")
                        K:send("debuggerXXXX", value)
                    elseif line:match"^eretXXXX" then
                        ret = line:match("^eretXXXX(.+)")
                    else K:send("clave",line) end
                else
                    break
                end
            until false
            exe:close()
        end
        --ret = err 
        end
        --]=]

        if ret then return Thread._return(tonumber(ret)) end
    end
end

Execute = function(self, cmd, inprocess, breakpoints, do_debug)
    self.Log:Clear()
    self.setStack({}) -- clear Stack
    --print("Execute",executable, cmd, inprocess)
    local thread = Thread(os_execute_async, nil,executable, cmd, inprocess, K, debuggerlinda, breakpoints, do_debug)
    return thread
end


ExecutePull = function(self)
	while true do
    local key,value = K:receive("debuggerXXXX","debugger","clave") --,"stack"
    if key then
        if key == "debuggerXXXX" then
            local f,err = loadstring(value)
            assert(f,err)
            value = f()
            local Stack = value[3]
            local _error = value[4]
            local vars = value[5]
            -- not needed with keepper with cycles
            -- local f,err = loadstring(vars)
            -- assert(f,err)
            -- vars = f()
            self.setStack(Stack, _error, vars)
        elseif key == "debugger" then
            local Stack = value[3]
            local _error = value[4]
            local vars = value[5]
            -- not needed with keepper with cycles
            -- local f,err = loadstring(vars)
            -- assert(f,err)
            -- vars = f()
            self.setStack(Stack, _error, vars)
        else
            self.Log:Add(string.format("-- %s: %s\n", key,value))
        end
	else
		break
    end
	end
    if self.runningThread then
            local ok, err = self.runningThread:join(0.01, true) --true for getting number
            if ok then
                self.Log:Add("-- Joined %s %d\n", self.shrt_name, err)
                if err == 1 then
                    self.setStack({}) -- clear Stack
                    self.notifications:Add(self.ig.lib.info, "Execute finished",10000);
                elseif err==2 then
                    self.notifications:Add(self.ig.lib.error, "Compile error",10000);
                elseif err==3 then
                    self.notifications:Add(self.ig.lib.error, "Execute error",10000);
                end
                self.runningThread = nil
            elseif not err then
                --print("  Timed out")
            else
                print("  Error:")
                print(err)
            end
    end
end


local function send_breakpoint(bp)
    if deblinda then
        deblinda:send("brpoints",bp)
    end
end
local ffi = require"ffi"
local do_debug = ffi.new("bool[?]",1)
local function renderMenuExecute(self, curdoc)
    self.file_name = self.opendocs[curdoc] and self.opendocs[curdoc].file_name or nil
    local ig = self.ig
    if (ig.BeginMenu("Execute", self.file_name~=nil and executable and hasThread ))  then 
            if (ig.MenuItem("Execute in this process",nil,nil,not self.runningThread))  then 
                deblinda = debuggerlinda
                local thread = Execute(self, self.file_name, true, self.getBreakPoints(), do_debug[0])
                self.runningThread = thread
            end 
            if (ig.MenuItem("Execute in other process", nil, nil, not self.runningThread))  then 
                deblindaS:close()
                deblindaS:init()
                deblinda = deblindaS
                local thread = Execute(self, self.file_name, false, self.getBreakPoints(), do_debug[0])
                self.runningThread = thread
            end
            ig.Separator()
            if (ig.MenuItem("Debug", nil, do_debug, not self.runningThread))  then 
            end 
            ig.Separator()
            if (ig.MenuItem("continue", "F9", nil, self.runningThread and do_debug[0] or false))  then 
                deblinda:send("continue",true)
            end 
            if (ig.MenuItem("break", nil, nil, self.runningThread and do_debug[0] or false))  then 
                deblinda:send("break",true)
            end 
            if (ig.MenuItem("debug_exit", nil, nil, self.runningThread and do_debug[0] or false))  then 
                deblinda:send("debug_exit",true)
            end 
            if (ig.MenuItem("step_into", "F10", nil, self.runningThread and do_debug[0] or false))  then 
                deblinda:send("step_into",true)
            end
            if (ig.MenuItem("step_over", "Shift-F10", nil, self.runningThread and do_debug[0] or false))  then 
                deblinda:send("step_over",true)
            end
            if (ig.MenuItem("step_out", "Ctrl-F10", nil, self.runningThread and do_debug[0] or false))  then 
                deblinda:send("step_out",true)
            end
        ig.EndMenu();
    end 
    if ig.Shortcut(ig.lib.ImGuiKey_F9) then
        deblinda:send("continue",true)
    end
    if ig.Shortcut(ig.lib.ImGuiKey_F10) then
        deblinda:send("step_into",true)
    end
    if ig.Shortcut(bit.bor(ig.lib.ImGuiMod_Ctrl, ig.lib.ImGuiKey_F10)) then
        deblinda:send("step_out",true)
    end
    if ig.Shortcut(bit.bor(ig.lib.ImGuiMod_Shift, ig.lib.ImGuiKey_F10)) then
        deblinda:send("step_over",true)
    end
end

return {Execute = Execute, ExecutePull = ExecutePull, send_breakpoint = send_breakpoint, executable = executable, hasThread = hasThread, renderMenuExecute = renderMenuExecute}
