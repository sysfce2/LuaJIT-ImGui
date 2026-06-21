--flush for popen:read"*l"
local old_print = print
print = function(...)
	old_print(...)
	io.stdout:flush()
end



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

print("from runner una linea\notra linea")

local function debugger_copy(object,lookup_table)

	local basicCopy = function(ob)
		return tostring(ob)
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


local function Debugger_get_call_stack(inilevel)
    local deph = math.huge
    local endlevel = inilevel + deph
	local stack = {}
	local vars = {}
	local lookup_table = {}
	for level = inilevel or 1,endlevel do
		local stlevel = level - inilevel + 1
		local stinfo = debug.getinfo(level,"Snlf")
		if not stinfo then --print("call_stact level: returns");
		return stack,vars end
		
		-- print("stinfo is:",stinfo)--ToStr(stinfo))
		-- for k,v in pairs(stinfo) do
			-- print("stinfo:",k,v)
		-- end
		-- print("stinfo end")
		
		stack[stlevel] = stinfo
		--  get locals an upvalues
		vars[stlevel] = {locals= {},upvalues= {}}
		local i = 1
		while true do
			local name,value = debug.getlocal(level,i)
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
		--print("stinfo.func", stinfo.func)
		-- dont force lanes to send function
		--stinfo.func = nil
	end
    return stack,vars
end

local serializer
local function ToStr(t)
	return serializer("tab_name",t,";")
end

local function xpcallerror(err)
	print"===========xpcallerror=============="
	print("xpcallerror1: "..tostring(err).."\n")
	print(debug.traceback())
	
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
	local stack,vars = Debugger_get_call_stack(3)
	--print("done getting call stack...")
	print("is require?",debuginfo.func == require)
	print("is dofile?",debuginfo.func == dofile)
	print("is loadfile?",debuginfo.func == loadfile)
	local is_comp_err = debuginfo.func == require or debuginfo.func == dofile or debuginfo.func == loadfile
	print("is_comp_err?", is_comp_err)
	-- if there is a compile error add it to stack and vars
	local info = compile_error(err,is_comp_err)
	if (info) then
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
	
	print("---stack")
	print("stackXXXX",ToStr(stack)) --here we loose stinfo.func
	--too big but could be used in debugging
	--print("---vars")
	--print(ToStr(vars))
	
	print("========xpcallerror ended: ",debuginfo.source,debuginfo.currentline,stack,vars,false)
end

--runs from f in loadfile
if not arg then
	serializer = require"serializer"
	print"returnning function"

	return function(script, K)
		local old_print2 = print
		print = function(...)
			old_print2(...)
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
		print("going dofile",script)
		--dofile(script)
		local ok,err = xpcall(function() return dofile(script) end, xpcallerror)
		print("xpcall",ok,err)
		print"after dofile"
		print"runer end======================================="
	end
else
	--runs in another process
	local currpath = debug.getinfo(1,'S').source
	currpath = currpath:match("@(.+)[\\/]([^\\/]+)")
	package.path = currpath.."/?.lua;"..package.path
	serializer = require"serializer"
	assert(#arg==1, "no script given to runner.lua")
	local script = arg[#arg]
	assert(not script:match"runner.lua","dont execute runner in other process")
	print("going dofile",script)
	--dofile(script)
	local ok,err = xpcall(function() return dofile(script) end, xpcallerror)
	print("xpcall",ok,err)
	print"after dofile"
	print"runer end======================================="
end