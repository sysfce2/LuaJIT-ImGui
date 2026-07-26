
local count = 0
local function hook(ev,l)
    count = count + 1
    print(ev,count)
    if count > 100 then error"cancelled" end
end
--debug.sethook(hook, "", 100)

local function run()
	while true do end
end

run()
print"done"