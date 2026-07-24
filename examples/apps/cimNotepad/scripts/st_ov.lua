
local function fs(n)
        return  n*fs(n)
		--return  fs(n-1)
end
print("jitstatus", jit.status())
fs(25)
