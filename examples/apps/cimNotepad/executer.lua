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
print("executer file_path:",file_path)
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
	self.file:write("key"..tostring(key).."value"..tostring(value).."\n")
	self.file:flush()
end

local deblinda

local os_execute_async = function(executable, cmd, inprocess, K, debuggerlinda, breakpoints, ...)
	local Thread = require"lj-async.thread"
	local Kmaker = require"lj-async.keeper"
	K = Kmaker.KeeperCast(K)
	debuggerlinda = Kmaker.KeeperCast(debuggerlinda)
	local args = {...}
	return function(ud)
		local ffi = require"ffi"
		
		print("thread curpath",file_path)
		package.path = file_path.."/?.lua;"..package.path
		print("thread package path",package.path)
		
		-- K:send("clave","going to execute")
		-- K:send("clave","inprocess: "..tostring(inprocess))
		-- K:send("clave",nil)
		-- K:send("clave","una linea\notra linea\n")
		-- K:send("clave","inprocess end")
		
		local ret
		if inprocess then
		---[[--------loadstring bad for same process sdl or glfw
		local f,err = loadfile(file_path.."/runner.lua")--cmd)
		print"-------runner loaded"
		if f then 
			ret = f()(cmd, K, debuggerlinda, breakpoints) 
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
		local breakstr = serializer("tab_name",breakpoints,";")..";return tab_name;"
		local f,err = io.open(file_path.."/breakpoints","w")
		assert(f,err)
		f:write(breakstr)
		f:close()
		local pcomand = executable.." ".." "..file_path.."/runner.lua "..cmd
		if jit.os == "Windows" then pcomand = [["]]..pcomand..[["]] end
		K:send("clave","pcomand is:"..pcomand)
		local exe,err = io.popen(pcomand, "r")
		if not exe then
			K:send("clave","Could not popen. Error: "..tostring(err))
		else
			K:send("clave","exe opened. Error: "..tostring(err))
			exe:setvbuf("no")
			K:send("clave","going to lopp............")
			repeat
				exe:flush()
				local line = exe:read("*l")
				if line then
					if line == "" then
					elseif line:match"^stackXXXX" then
						K:send("stack", line)
					elseif line:match"^debuggerXXXX" then
						local value = line:match("debuggerXXXX(.+)")
						value = value..";return tab_name;"
						local f,err = loadstring(value)
						assert(f,err)
						value = f()
						K:send("debugger", value)
					elseif line:match"^eretXXXX" then
						ret = line:match("^eretXXXX(.+)")
						ret = ret=="true" and true or false
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
		
		K:send("clave","............finished ret: "..tostring(ret))
		K:send("clave",ret)
		if ret then return Thread._return(1) else return Thread._return(0) end
	end
end

Execute = function(self, cmd, inprocess, breakpoints)
	self.Log:Clear()
	self.setStack({}) -- clear Stack
	print("Execute",executable, cmd, inprocess)
	local thread = Thread(os_execute_async, nil,executable, cmd, inprocess, K, debuggerlinda, breakpoints)
	return thread
end


ExecutePull = function(self)
	local key,value = K:receive("stack","clave","debugger")
	if key then
		self.Log:Add(string.format("-- %s: %s\n", key,value))
		if key == "stack" then
			value = value:gsub("stackXXXX", "")
			value = value..";return tab_name;"
			local f,err = loadstring(value)
			assert(f,err)
			--setfenv(f,setmetatable({ig=ig},{ __index = _G}))
			local Stack = f()
			self.setStack(Stack)
			-- require"anima.utils"
			-- prtable("=====================Stack",Stack)
		elseif key == "debugger" then
			local Stack = value[3]
			self.setStack(Stack)
		end
	end
	if self.runningThread then
			local ok, err = self.runningThread:join(0.01, true) --true for getting number
			if ok then
				self.Log:Add("-- Joined %s %d\n", self.shrt_name, err)
				if err == 1 then
					self.setStack({}) -- clear Stack
					self.notifications:Add(self.ig.lib.info, "Execute finished",10000);
				else
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

local function renderMenuExecute(self, curdoc)
	self.file_name = self.opendocs[curdoc] and self.opendocs[curdoc].file_name or nil
	local ig = self.ig
	if (ig.BeginMenu("Execute", self.file_name~=nil and executable and hasThread ))  then 
			if (ig.MenuItem("Execute in this process",nil,nil,not self.runningThread))  then 
				deblinda = debuggerlinda
				local thread = Execute(self, self.file_name, true, self.getBreakPoints())
				self.Log:Add("thread is "..tostring(thread).."\n")
				self.runningThread = thread
			end 
			if (ig.MenuItem("Execute in other process", nil, nil, not self.runningThread))  then 
				deblindaS:close()
				deblindaS:init()
				deblinda = deblindaS
				local thread = Execute(self, self.file_name, false, self.getBreakPoints())
				self.Log:Add("thread is "..tostring(thread).."\n")
				self.runningThread = thread
			end
			ig.Separator()
			if (ig.MenuItem("continue", nil, nil, self.runningThread and true or false))  then 
				deblinda:send("continue",true)
			end 
			if (ig.MenuItem("break", nil, nil, self.runningThread and true or false))  then 
				deblinda:send("break",true)
			end 
			if (ig.MenuItem("debug_exit", nil, nil, self.runningThread and true or false))  then 
				deblinda:send("debug_exit",true)
			end 
			if (ig.MenuItem("step_into", nil, nil, self.runningThread and true or false))  then 
				deblinda:send("step_into",true)
			end
			if (ig.MenuItem("step_over", nil, nil, self.runningThread and true or false))  then 
				deblinda:send("step_over",true)
			end
			if (ig.MenuItem("step_out", nil, nil, self.runningThread and true or false))  then 
				deblinda:send("step_out",true)
			end
		ig.EndMenu();
	end 

end

return {Execute = Execute, ExecutePull = ExecutePull, debuggerlinda = debuggerlinda, executable = executable, hasThread = hasThread, renderMenuExecute = renderMenuExecute}
