local M = {}
local insert = table.insert
			--require"anima.utils"
local function findFunctionsLua(str)
    local funre = "([%w_%.]*) *=? *function( *)([%w_%.:]*)%s*%b()"

    local func_t = {}
    local lineg = 1
    local last_end = 1
    local s, e, cap, capm, cap2 = str:find(funre, 1)
    while s do
        --find line
        local pre = str:sub(last_end,s)
        for _ in pre:gmatch("\n") do
            lineg = lineg + 1
        end
        ---------------
        --print("------\n",str:sub(last_end,s-1),"\n+++++++++++++++")
        --print(lineg,s,e, string.format("%q, %q, %q",cap, capm, cap2))--cap, string.format("%q",capm),cap2)
        if #cap2 > 0 and #capm > 0 then
            insert(func_t, {name = cap2, line = lineg})
        elseif #cap > 0 then
            insert(func_t, {name = cap, line = lineg})
        else
            --print"skipping-------"
        end
        last_end = e+1
        s, e, cap, capm, cap2 = str:find(funre, last_end)
    end
    --print"======================================"
    local tab_nam = {}
	local tabs = {}
    local func_t_sorted = {}
    for i,fun in ipairs(func_t) do
        func_t_sorted[i] = fun
        local tnam = fun.name:match("([^%.:]+)[%.:]")
        if tnam then 
			tab_nam[tnam] = tab_nam[tnam] or {name = tnam, line = fun.line, child_f = {}}
			insert(tab_nam[tnam].child_f, fun)
		else 
			tab_nam.main = tab_nam.main or {name = "main", line = 1, child_f = {}}
			insert(tab_nam.main.child_f, fun)
		end
    end
    table.sort(func_t_sorted, function(a,b) return a.name < b.name end)
	for k,tab in pairs(tab_nam) do
		insert(tabs,tab)
	end
	table.sort(tabs, function(a,b) return a.name < b.name end)
    return {funcs=func_t, funcs_sorted=func_t_sorted, tables = tabs}
end
----------------------------cpp
local function split_comment(line)
    local comment = line:match("(%s*//.*)") --or ""
    line = line:gsub("%s*//[^\n]*","")
    line = line:gsub("%s*$","")
    return line,comment
end
local function clean_comments(txt)
	local comms = ""
	for comm in txt:gmatch("(%s*//[^\n]*)") do
		comms = comms..comm
	end
	txt = txt:gsub("%s*//[^\n]*","")
	return txt,comms
end
--dont keep commens above empty line
local function clean_outercomms(oc)
	local oc2 = {}
	for i,v in ipairs(oc) do
		--print(string.format("%d\n%q",i,v))
		if v:match"\n%s*\n" then
			--print(string.format("match:\n%q",v))--,v:match"\n%s*\n"))
			v=v:gsub("\n%s*\n","")
			--print("clean",v)
			oc2 = {}
		else
			--print"dont clean"
		end
		table.insert(oc2,v)
	end
	return table.concat(oc2)--,"\n")
end
local function isLeaf(re)
	return (re ~= "typedef_st_re" and re ~= "struct_re" and re~="namespace_re" and re~="class_re" and re~="union_re")
end
local function strip(cad)
    return cad:gsub("^%s*(.-)%s*$","%1") --remove initial and final spaces
end
local function strip_end(cad)
    return cad:gsub("^(.-)%s*$","%1") --remove  final spaces
end
local function strip_end_cr(cad)
    return cad:gsub("^(.-)%[\9\10\11\12 ]*$","%1") --remove  final spaces except\n
end
local function clean_spaces(cad)
    cad = strip(cad)
    cad = cad:gsub("%s+"," ") --not more than one space
    cad = cad:gsub("%s*([%(%),=:%+])%s*","%1") --not spaces with ( , ) or ( = ) or ( : ) or + 
	cad = cad:gsub("%s*(>>)%s*","%1")
	--name [] to name[]
	cad = cad:gsub("(%S)%s(%[)","%1%2")
	--clean %d * %d (could be done above but type*name should be treated different in other places)
	cad = cad:gsub("(%d)%s*(%*)%s*(%d)","%1%2%3")
    return cad
end
local function derived_check(it)
	--print("derived_check",it.name)
	--expects struct or class
	assert(it.re_name=="struct_re" or it.re_name=="class_re",it.re_name)
	local inistruct = clean_spaces(it.item:match("(.-)%b{}"))
	inistruct = clean_comments(inistruct)
	--clean final:
	inistruct = inistruct:gsub("%s*final%s*:",":")
	local stname, derived
	if inistruct:match":" then
		stname,derived = inistruct:match"struct%s*([^%s:]+):(.+)"
		if not stname then stname,derived = inistruct:match"class%s*([^%s:]+):(.+)" end
		if derived then 
			derived = derived:match"(%S+)$" 
		else assert(inistruct:match"private" or inistruct:match"protected",inistruct) end
	else
		if it.re_name == "struct_re" then
			stname = inistruct:match"struct%s(%S+)"
		elseif it.re_name == "class_re" then
			stname = inistruct:match"class%s(%S+)"
		end
	end
	return stname, derived
end
--gives the re table
local function getRE()
	local res = {

	function_re = "^([^;{}=]+%b()[\n%s=%w%(%)_]*;)", --attribute(deprecated)
	--we need to skip = as function because of "var = f()" initialization in struct fields
	-- but we don want operator== to appear as a var and as we should skip this kind of function solution is:
	operator_re = "^([^;{}]+operator[^;{}]+%b()[\n%s%w%(%)_]*;)",
	struct_re = "^([^;{}#]-struct[^;{}]-%b{}[%s%w_%(%)]*;)",
	class_re  = "^([^;{}#]-class[^;{}]-%b{}[%s%w_%(%)]*;)",
	enum_re = "^([^;{}]-enum[^;{}]-%b{}[%s%w_%(%)]*;)",
	union_re = "^([^;{}]-union[^;{}]-%b{}[%s%w_%(%)]*;)",
	structenum_re = "^([^;{}]-%b{}[%s%w_%(%)]*;)",
	namespace_re = "^([^;{}]-namespace[^;{}]-%b{})",
	typedef_re = "^\n*%s*(typedef[^;]+;)",
	typedef_st_re = "^\n*(typedef%s+struct%s*%b{}.-;)",
	functypedef_re = "^\n*%s*(typedef[%w%s%*_]+%(%s*%*%s*[%w_]+%s*%)%s*%b()%s*;)",
	functypedef_re = "^\n*%s*(typedef[%w%s%*_]+%([^*]*%*?%s*[%w_]+%s*%)%s*%b()%s*;)",
	vardef_re = "^\n*([^;#]+;)",
	functionD_re = "^([^;{}]-%b()[\n%s%w]*%b{}%s-;*)",
	functype_re = "^%s*[%w%s%*]+%(%*[%w_]+%)%([^%(%)]*%)%s*;",
	comment_re = "^\n*%s*//[^\n]*\n",
	comment2_re = "^%s*/%*.-%*/\n",
	emptyline_re = "^\n*%s*\n",
	preproc_re = "^#[^\n]+\n",
	unknown_re = "^[^\n]+\n"
	}
	
	local resN = {"preproc_re","comment2_re","comment_re","emptyline_re",
	"functypedef_re","functype_re","function_re","functionD_re","operator_re","typedef_st_re","struct_re","enum_re","union_re","namespace_re","class_re","typedef_re","vardef_re","unknown_re"}
	
	return res,resN
end
local function findTxtPartition(txt,getRE,lineg,founded_f, ...)
	--print("===========findTxtPartition")
	--local dumpit = true
	local res,resN = getRE()
	local ini = 1
	local last_e = 0
	local last_i = 0
	while true do
		local found = false
		for ire,re_name in ipairs(resN) do
			local re = res[re_name]
			local i,e = txt:find(re,ini)
			if i then
				--find line
				assert(ini==i)
				local pre = txt:sub(last_i,last_e)
				--assert(pre=="",string.format("%q %d, %d",pre,ini,i))
				for _ in pre:gmatch("\n") do
					lineg = lineg + 1
				end
				founded_f(lineg,txt,re_name,i,e,...)
				-----------------------
				if dumpit then
					print(lineg,i,e,re_name,"------------------------------------------------------")
					--print(clean_spaces(txt:sub(i,i+30)))
					print(string.format("%q",txt:sub(i,e):sub(1,30)))
					--print(string.format("item:%q pre:%q",txt:sub(i,e),pre))
				end
				found = true
				ini = e + 1
				last_e = e 
				last_i = i
				break
			end
		end
		-- no re matched
		if not found then
			if not (ini >= #txt) then 
				local rest = txt:sub(ini)
				local onlyspaces = rest:match("^%s*$")
				if not onlyspaces then
					print("=======parse error=======")
					print(ini,#txt);
					print(string.format("%q",txt));
					print"---------rest:"
					print(string.format("%q",rest))
					print"---------prev item:"
					print(item)
					error"parseItems error"
				end
			end
			break 
		end
	end
	return lineg
end

local function found_ff(lineg,txt,re_name, i, e, itparent, items,itemarr,outercomms)

	local item = txt:sub(i,e)
	--print(lineg,re_name,clean_spaces(item:sub(1,20)))
	--print("re_name:",re_name,string.format("%q",item))

	if re_name=="comment_re" or re_name=="comment2_re" or re_name=="emptyline_re" then
		item = item:gsub("^[^\n%S]*(//.-)$","%1")
		--comments begining with \n will go to next item
		if item:match("^%s*\n") then
			table.insert(outercomms,item)
		else
			-- comments to previous item
			if itemarr[#itemarr] then 
				local prev = itemarr[#itemarr].comments or ""
				itemarr[#itemarr].comments = prev .. item 
			end
		end
	else
		item = item:gsub("extern __attribute__%(%(dllexport%)%) ","")
		local comments = clean_outercomms(outercomms) 
		--local comments = table.concat(outercomms,"\n") --..inercoms
		if comments=="" then comments=nil end
		outercomms = {}

		table.insert(itemarr,{re_name=re_name,item=item,prevcomments=comments,parent=itparent,lineg=lineg})
		items[re_name] = items[re_name] or {}
		table.insert(items[re_name],item)
	end
end
local function parseItems(txt, itparent, lineg)

	local res,resN = getRE()
	
	local items = {}
	local itemarr = {}
	local outercomms = {}
	
	local lineg = findTxtPartition(txt, getRE,lineg, found_ff,itparent,items,itemarr,outercomms)
	
	return itemarr,items,lineg
end
local function moveptr(line)
	line = line:gsub("%s*%*","%*")
	line = line:gsub("%*([%w_])","%* %1")
	line = line:gsub("(%(%*)%s","%1")
	return line
end

local function parseFunction(it)

	local lineorig,comment = split_comment(it.item)
	local line = clean_spaces(lineorig)
	--move *
	line = moveptr(line)

	--print(line)
    --clean implemetation
    line = line:gsub("%s*%b{}","")
    --clean attribute
    line = line:gsub("%s*__attribute__%b()","")

    line = line:gsub("static","")
	line = line:gsub("inline","")
	line = line:gsub("mutable","")
	line = line:gsub("explicit","")
	line = line:gsub("constexpr","")
	line = clean_spaces(line)
	
	local funcname, args, extraconst = line:match("(~?[_%w%[%]=%*/%+%-]+)%s*(%b())(.*)")
	it.name = funcname
end

local par = {forced_opaque={}}
--recursive item parsing
	function par:parseItemsR2(txt, itparent,lineg)
		lineg = lineg or 1
		local itsarr,its,linegret = parseItems(txt,itparent,lineg)
		--clean protect
		if itparent and itparent.re_name == "class_re" then
			local first_private
			for j,child in ipairs(itsarr) do
				if child.item:match("^\n*%s*private:") or child.item:match("^\n*%s*protected:") then
					first_private = j
					break
				end
			end
			if first_private then
				for j=first_private,#itsarr do
					--print("private discards",it.childs[j].re_name,it.childs[j].name)
					itsarr[j] = nil
				end
			end
		end
		for i,it in ipairs(itsarr) do
			--clean class and get name
			if it.re_name == "class_re" then
				it.name = it.item:match("class%s+(%S+)")
				if not it.name then prtable(it) end
				print("cleaning class",it.name,"-------------------------------------")
				--it.item = it.item:gsub("private:.+};$","};")
				--it.item = it.item:gsub("private:","")
				it.item = it.item:gsub("public:","")
				it.item = it.item:gsub("enum%s*class","enum")
			elseif it.re_name == "struct_re" then
				it.name = it.item:match("struct%s+([^%s{]+)")
				assert(it.name)
				if self.name_conversion and self.name_conversion[it.name] then
					it.name = self.name_conversion[it.name]
					print("=========conversion",it.name)
				end
			elseif it.re_name == "namespace_re" then
				it.name = it.item:match("namespace%s+(%S+)")
			elseif it.re_name == "function_re" or it.re_name == "functionD_re" then
				parseFunction(it)
			end

			if not isLeaf(it.re_name) then
				local pre, inner = it.item:match("^([^{]+)(%b{})")
				local lineginner = it.lineg 
				for _ in pre:gmatch("\n") do
					lineginner = lineginner + 1
				end
				
				inner = strip_end_cr(inner:sub(2,-2))
				--print("=====parseItemsR2",it.name,it.re_name,it.lineg,lineginner)
				it.childs = par:parseItemsR2(inner, it,lineginner)
				
				if it.re_name == "struct_re" then
					local typename = it.item:match("^%s*template%s*<%s*typename%s*(%S+)%s*>")
					--local stname = it.item:match("struct%s+(%S+)")
					--local stname = it.item:match("struct%s+([^%s{]+)") --unamed
					local stname = it.name
					
					--local templa1,templa2 = it.item:match("^%s*template%s*<%s*(%S+)%s*(%S+)%s*>")
					local templa2 = it.item:match("^%s*template%s*<%s*([^<>]+)%s*>")
					if templa1 or templa2 then print("template found",stname,templa1,templa2,"typename",typename) end
					
					if typename or templa2 then -- it is a struct template
						self.typenames = self.typenames or {}
						self.typenames[stname] = typename or templa2
					end
				elseif it.re_name == "namespace_re" then

				elseif it.re_name == "class_re" then

				end
				
				--create opaque_struct
				if it.re_name == "struct_re" or it.re_name == "class_re" then
					local stname,derived = derived_check(it)
						if derived then
							local derived2 = derived:gsub("%b<>","") 
							derived2 = derived2:gsub("%w+::","")
							print("    --derived check",stname, derived, derived2)
							--M.prtable(self.opaque_structs)
							if self.opaque_structs[derived2] then
								print("    --make opaque opaque derived",it.name,derived,derived2)
								it.opaque_struct = get_parents_name(it)..it.name
								self.opaque_structs[it.name] = it.opaque_struct
							end
						end
					if derived and derived:match"std::" then
						print("    --make opaque std::derived",it.name,derived)
						--it.opaque_struct = (itparent and itparent.name .."::" or "")..it.name
						it.opaque_struct = get_parents_name(it)..it.name
						self.opaque_structs[it.name] = it.opaque_struct
					end
					if self.forced_opaque[it.name] then
						print("    --make forced opaque opaque derived",it.name)
						it.opaque_struct = get_parents_name(it)..it.name
						self.opaque_structs[it.name] = it.opaque_struct
					end
					for j,child in ipairs(it.childs) do
						-- if child.re_name == "vardef_re" and child.item:match"using" then
							-- print("=====using",child.item)
						-- end
						if (child.re_name == "vardef_re") and child.item:match"std::" then
							print("    --make opaque with child std::",it.name,child.item)
							--M.prtable(itparent)
							--it.opaque_struct = (itparent and itparent.name .."::" or "")..it.name
							it.opaque_struct = get_parents_name(it)..it.name
							print("    ===parents1",get_parents_name(it),"===parents2",(itparent and itparent.name .."::" or ""))
							print("    ===",it.opaque_struct)
							--cant do that as function is recursive
							--self.opaque_structs[it.name] = get_parents_name(it)..it.name--(itparent and itparent.name .."::" or "")..it.name
							self.opaque_structs[it.name] = it.opaque_struct
							break
						end
					end
				end
			end
		end
		return itsarr
	end
local function Listing(arr,ff)
	for i,it in ipairs(arr) do
		ff(it)
		if not isLeaf(it.re_name) then
			Listing(it.childs,ff)
		end
	end
end


local function findFunctionsCpp(str)

	local itarr = par:parseItemsR2(str)
	
	local tab_names = {}
	local func_t = {}
	-- we keep here functions not in struct or class
	local main_child_f = {}
	Listing(itarr, function(it)
		if it.re_name == "function_re" or it.re_name == "functionD_re" then
			assert(it.name)
			insert(func_t, {name = it.name, line = it.lineg})
			if not it.parent or (it.parent.re_name~="struct_re" and it.parent.re_name~="class_re") then 
				--if it.parent then print(it.parent.re_name) end
				insert(main_child_f,{name = it.name, line = it.lineg})
			end
		elseif it.re_name == "struct_re" or it.re_name == "class_re" then
			local child_f = {}
			for i,child in ipairs(it.childs) do
				if child.re_name == "function_re" or child.re_name == "functionD_re" then
					insert(child_f,{name = child.name, line = child.lineg})
				end
			end

			if not(it.name) then prtable(it) end
			insert(tab_names, {name = it.name, line = it.lineg, child_f = child_f})
		end
	end)
	local func_t_sorted = {}
    for i,v in ipairs(func_t) do
        func_t_sorted[i] = v
    end
    table.sort(func_t_sorted, function(a,b) return a.name < b.name end)
	insert(tab_names,{name="main", line = 1, child_f = main_child_f})
	table.sort(tab_names, function(a,b) return a.name < b.name end)
	return {funcs=func_t, funcs_sorted=func_t_sorted, tables = tab_names}
end

local function find_functions(txt, ext)
    if ext=="lua" then
        return findFunctionsLua(txt)
	elseif ext=="h" or ext=="c" or ext=="hpp" or ext=="cpp" then
		return findFunctionsCpp(txt)
    else
        print("find_functions still not implemented for ", ext)
    end
end

function M.find_functions(txt, ext)
	local ok, err = pcall(find_functions, txt, ext)
	if ok then
		return err
	else
		print("findFunctions",err)
	end
end
--[=[
local doc = [[C:\LuaGL\gitsources\anima\LuaJIT-ImGui\cimgui\imgui\imgui.h]] 
--local doc = [[C:\LuaGL\gitsources\anima\LuaJIT-ImGui\examples\apps\cimNotepad\scripts\ImVec2.h]] 
--local doc = [[C:\LuaGL\gitsources\anima\LuaJIT-ImGui\cimgui\generator\cpp2ffi.lua]]

local f,err = io.open(doc)
assert(f, err)
local str = f:read"*a"
f:close()
local rrr = findFunctionsCpp(str)
-- local rrr = findFunctionsLua(str)
require"anima.utils"
prtable(rrr)
---]=]
return M