local function inner_f(ini)
	print("inner ini is", ini)
	for i=1,10 do
		print(coroutine.running())
		print("inner says",i)
		if i == 4 then error"debug" end
		local ret = coroutine.yield(i)
		print("yield received", ret)
	end
	return 20
end

local corut = coroutine.create(inner_f)

local counter = 0
while true do
	print(table.pack)
	print(coroutine.running())
	print"resuming"
	counter = counter + 1
	if coroutine.status(corut)=="dead" then break end
	local ok, num = coroutine.resume(corut, counter)
	if not ok then 
		print(num, "status:",coroutine.status(corut));
		print(debug.traceback(corut)) 
		error(num)
	else
		print("corut returned", num)
	end
end