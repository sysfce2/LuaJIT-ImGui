--flush for popen:read"*l"
local old_print = print
print = function(...)
	old_print(...)
	io.stdout:flush()
end

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
print("file_path",file_path)
local Debugger = dofile(pathut.chain(file_path,"debugger.lua"))
print("Debugger",Debugger)
local serializer = require"imgui.libs.serializer"
local function ToStr(t)
	return serializer("tab_name",t,";")
end

local function xpcallerror(err)
	print"===========xpcallerror=============="
	print("xpcallerror1: "..tostring(err).."\n")
	--print(debug.traceback())
	
	----detect recursive error
	for i=2,math.huge do
		local debuginfo = debug.getinfo(i,"Snlf")
		if not debuginfo then break end
		if debuginfo.func == xpcallerror then
			print("========recursive error\n")
			return
		end
	end
	
	-- function to get compiler errors in required files
	local function compile_error(err,iscompileerr)
		local info = {}
		--catch error from require
		local err2 = err:match("from file%s+'.-':.-([%w%p]*:%d+:)")
		--catch error from loadfile
		if not err2 then
			err2 = err:match("loadfile error:([%w%p]*:%d+:)")
		end
		if not err2 and iscompileerr then err2 = err end
		if err2 then
			info.source = "@"..err2:match(":-(.-):%d*:")
			info.currentline = err2:match(":(%d*):") or -1
			return info
		end
	end
	
	local debuginfo = debug.getinfo(2,"Slf")
	--print("getting call stack...")
	local stack,vars = Debugger:get_call_stack(3) --Debugger_get_call_stack(3)
	--print("done getting call stack...")
	print("is require?",debuginfo.func == require)
	print("is dofile?",debuginfo.func == dofile)
	print("is loadfile?",debuginfo.func == loadfile)
	-- local debuginfo2 = debug.getinfo(1,"Slf")
	-- require"anima.utils"
	-- prtable("debuginfo",debuginfo)
	-- prtable("debuginfo2",debuginfo2)
	local is_comp_err = debuginfo.func == require or debuginfo.func == dofile or debuginfo.func == loadfile
	print("is_comp_err?", is_comp_err)
	-- if there is a compile error add it to stack and vars
	local info = compile_error(err, is_comp_err)
	-- dont
	if (false and info) then
		print("is compile error===========================")
		print("comp err source: ",info.source.."\n")
		print("comp err line: ",info.currentline,"\n")
		local stack_tbl2,vars2 = {},{}
		stack_tbl2[1] = info
		vars2[1] = {}
		for i,v in ipairs(stack) do
			stack_tbl2[i+1] = stack[i]
			vars2[i+1] = vars[i]
		end
		stack = stack_tbl2
		vars = vars2
	end
	
	print("========xpcallerror ended: ",debuginfo.source,debuginfo.currentline,stack,vars,false)
	print(debug.traceback(2))
	--print("---stack")
	print("stackXXXX",ToStr(stack)) --here we loose stinfo.func
		--too big but could be used in debugging
		--print("---vars")
		--print(ToStr(vars))
	print("======= error:",err)

end

local function load_script(script)
	--return function() dofile(script) end
	return function()
		local fs, err = loadfile(script)
		if not fs then
			--print(debug.traceback())
			print("======= compile error:",err) 
			--send stack
			local info = {}
			info.source = "@"..script
			info.currentline = err:match(":(%d*):") or -1
			print("stackXXXX",ToStr({info}))
		else
			return fs()
		end
		return
	end
end

--runs from f in loadfile
if not arg then
--if true then
	print"returnning function"
	inprocess = true
	return function(script, K, debuggerlinda, bp)
		local old_print2 = print
		print = function(...)
			--old_print2(...)
			local args = {}
			for i=1,select("#",...) do
				args[i] = tostring(select(i,...))
			end
			local str = table.concat(args,"\t")
			if str:match"^stackXXXX" then
				K:send("stack", str)
			else
				K:send("clave",str)
			end
		end
		--local bp = {breakpoints = {[10] = {["@"..script] = true}}}
		Debugger:init(bp, K, debuggerlinda)
		--print("going dofile",script)
		local ok,err = xpcall(load_script(script), xpcallerror)
		print("xpcall",ok,err)
		print"runer end======================================="
		return ok
	end
else
	--runs in another process
	inprocess = false
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
	
	
	local Sender = {}
	function Sender:send(key,value)
		print(key.."XXXX"..ToStr(value))
	end

	assert(arg[1], "no script given to runner.lua")
	local script = arg[1]

	local bp = dofile(pathut.chain(file_path,"breakpoints"))
	
	assert(not script:match"runner.lua","dont execute runner in other process")
	print("going dofile",script)
	deblinda:init()
	Debugger:init(bp, Sender, deblinda)
	local ok,err = xpcall(load_script(script), xpcallerror)
	print("xpcall",ok,err)
	print"runer end======================================="
	print("eretXXXX"..tostring(ok))
	return ok
end