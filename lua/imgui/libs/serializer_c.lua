local serializer = require"imgui.libs.serializer"

local function autoser_cdata(tab, endline)
    endline = endline or "\n"
	return table.concat{ [[local ffi = require"ffi"]]..endline, serializer("tab", tab, endline), "return tab;"}
end
return { serializer = serializer, autoser_cdata = autoser_cdata}