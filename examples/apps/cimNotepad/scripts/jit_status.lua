jit.off(true, true)
--jit.off()
local function run()
	jit.off(true,true)
	--jit.off()
    print("======jit status:",jit.status())
end
jit.off(run, true)
run()
