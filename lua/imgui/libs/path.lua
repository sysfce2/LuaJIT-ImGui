--------------path utilities extracted from penligth (Steve Donovan)

----------------------------------------------------------------
-- plain luafilesystem
--local lfs = require"lfs"
-- or to get unicode lfs with luajit
-- https://github.com/sonoro1234/luafilesystem
local lfs = require"lfs_ffi"

local M = {}
local is_windows = package.config:sub(1,1) == '\\'
local function isabs(P)
    if is_windows then
        return P:sub(1,1) == '/' or P:sub(1,1)=='\\' or P:sub(2,2)==':'
    else
        return P:sub(1,1) == '/'
    end
end
local sep = is_windows and '\\' or '/'
M.sep = sep
local np_gen1, np_gen2 = '[^SEP]+SEP%.%.SEP?', 'SEP+%.?SEP'
local np_pat1, np_pat2 = np_gen1:gsub('SEP',sep) , np_gen2:gsub('SEP',sep)
local function normpath(P)
    if is_windows then
        if P:match '^\\\\' then -- UNC
            return '\\\\'..normpath(P:sub(3))
        end
        P = P:gsub('/','\\')
    end
    local k
    repeat -- /./ -> /
        P,k = P:gsub(np_pat2,sep)
    until k == 0
    repeat -- A/../ -> (empty)
        P,k = P:gsub(np_pat1,'')
    until k == 0
    if P == '' then P = '.' end
    return P
end
local function abspath(P)
    local pwd = lfs.currentdir()
	--print("CWD",pwd)
    if not isabs(P) then
        P = pwd..sep..P
    elseif is_windows  and P:sub(2,2) ~= ':' and P:sub(2,2) ~= '\\' then
        P = pwd:sub(1,2)..P -- attach current drive to path like '\\fred.txt'
    end
    return normpath(P)
end
M.abspath = abspath
function M.chain(...)
    local res={}
    for i=1, select('#', ...) do
        local t = select(i, ...)
        table.insert(res,t)
    end
    return table.concat(res,sep)
end
local function splitpath(P)
    return P:match("(.+)"..sep.."([^"..sep.."]+)")
end
function M.this_script_path()
    return splitpath(abspath(arg[0])) --.. sep
end

return M