local function inner_f(ini)
	print("inner ini is", ini)
	for i=1,10 do
		print("inner says",i)
		if i == 4 then error"debug" end
		local ret = coroutine.yield(i)
		print("yield received", ret)
	end
	return 20
end

local corut = coroutine.wrap(inner_f)

local counter = 0
while true do
	print"resuming"
	counter = counter + 1
	local num = corut(counter)
	print("corut returned", num)
	if num == 20 then
		print("corut finished")
		break 
	end
end