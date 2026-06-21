local ffi = require"ffi"
ffi.cdef[[void Sleep(uint32_t);]]
--local caca = require"caca"
local function run()
	local i = 0
	while i < 5 do

		print("hello",i)
		i = i + 1
		ffi.C.Sleep(1000)
		error"debug"
	end
end

run()