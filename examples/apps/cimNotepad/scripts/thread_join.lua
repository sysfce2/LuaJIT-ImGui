local ThreadF = function()
print"init thread"
jit.off()
print("jitstatus", jit.status())
FINALIZER = function(ok,val) 
	print("====i am ThreadF finalizer",ok);
end
return function(ud)
	local a = 0
	local ffi = require "ffi"
	print("======inside thread",ud)

	local Sleep
	if ffi.os == "Windows" then
		ffi.cdef[[void Sleep(uint32_t);]]
		Sleep = function(s) ffi.C.Sleep(s*1000) end
	else
		ffi.cdef[[unsigned int sleep(unsigned int);]]
		Sleep = function(s) ffi.C.sleep(s) end
		ffi.C.sleep(5)
	end
	for i=1,6 do
		Sleep(1)
	end
	print"----done waiting"
	--error"debugxxx"
	
	--deadlock in thread
	--test for cancel
	while true do 

	end
end
end

--WINUSEPTHREAD = true
local Thread = require "lj-async.thread"
local ffi = require"ffi"
local thread_data_t = ffi.typeof("struct { int x; }")

local t = Thread({ThreadF},thread_data_t(1))
print("Thread will run for 5 seconds. Joining with 1 second timeouts.", t.thread)
FINALIZER = function(ok,val) 
	print("====i am thread.join finalizer",ok,val) 
	if t.thread then
	print("try coop_cancel on", t.thread)
	 t:cancel()
	print("try coop_cancel done")
	end
end
local sec =0
while true do
	sec = sec + 1
	print("loop",sec)
	local ok, err = t:join(1)
	if ok then
		print("  Joined",err)--, string.format("%X",Thread.pthread.C.PTHREAD_CANCELED))
		break
	elseif not err then
		print("  Timed out")
	else
		print("  Error:")
		print(err)
		break
	end
	 --error"dddddddd"
	if sec == 20 then
		print"send cancel"
		--t:cancel()
	end
end
print"doing t:free"
t:free()