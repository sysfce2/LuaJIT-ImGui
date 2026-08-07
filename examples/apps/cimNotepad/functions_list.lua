local M = {}
local insert = table.insert

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
    local func_t_sorted = {}
    for i,v in ipairs(func_t) do
        func_t_sorted[i] = v
        local tnam = v.name:match("([^%.:]+)[%.:]")
        if tnam then tab_nam[tnam] = true end
        --print(i, v.name, v.line, tnam)
    end
    table.sort(func_t_sorted, function(a,b) return a.name < b.name end)
    --print"tab names"
    --for k,v in pairs(tab_nam) do print(k) end
    return {funcs=func_t, funcs_sorted=func_t_sorted, tables = tab_nam}
end

function M.find_functions(txt, ext)
    if ext=="lua" then
        return findFunctionsLua(txt)
    else
        print("find_functions still not implemented for ", ext)
    end
end

return M