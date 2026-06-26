local ffi = require"ffi"

local Sleep
if ffi.os == "Windows" then
	ffi.cdef[[void Sleep(uint32_t);]]
	Sleep = function(ti)
		ffi.C.Sleep(ti*1000)
	end
else
	ffi.cdef[[unsigned int sleep(unsigned int);]]
	Sleep = function(ti)
		ffi.C.sleep(ti)
	end
end
--local nothing = require"nothing"
--KK = II.bad
--Klocal rrr = 1

local pathut = require"imgui.libs.path"
local file_path = pathut.file_path()
--local this_script_path = pathut.this_script_path()
print("pathssss", file_path, this_script_path)

local function run()
	local i = 0
	while i < 5 do

		print("hello",i)
		i = i + 1
		--Sleep(1)
		--error"debug"
	end
end

run()