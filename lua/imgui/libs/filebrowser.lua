local ffi = require "ffi"
---------------------------------------------FileBrowser---------------------------------------
-- plain luafilesystem
--local lfs = require"lfs"
-- or to get unicode lfs with luajit
-- https://github.com/sonoro1234/luafilesystem
local has_lfs_ffi, lfs = pcall(require,"lfs_ffi")
if not has_lfs_ffi then
    lfs = require"lfs"
end

local pathut = require"imgui.libs.path"

function loader(ig)
    -----------------------YesNo dialog ---------------
local gui = {pathut = pathut}
function gui.YesNo(msg)
    local D = {}
    function D.open() 
        ig.OpenPopup("yesno") 
    end
    function D.draw(doit)
        local resp = doit
        if ig.BeginPopupModal("yesno",nil,ig.lib.ImGuiWindowFlags_AlwaysAutoResize) then
            ig.Text(msg)
            if ig.Button("yes") then
                resp = true
                ig.CloseCurrentPopup(); 
            end
            ig.SameLine()
            if ig.Button("no") then
                resp = false
                ig.CloseCurrentPopup(); 
            end
            ig.EndPopup()
        end
        return resp
    end
    return D
end
--filename_p char pointer to get filename
-- funcOK function called on selection
--args.key, args.curr_dir, args.pattern, args.filename, args.check_existence
function gui.FileBrowser(filename_p, args, funcOK)
    
    args = args or {}
    args.key = args.key or "filechooser"
    local pattern_ed = ffi.new("char[32]",args.pattern or "" )
    --ffi.copy(pattern_ed, args.pattern or "" )
    --local pathut = M --require"anima.path"
    local curr_dir = args.curr_dir or pathut.this_script_path() 
    local curr_dir_ed = ffi.new("char[?]",256)
    ffi.copy(curr_dir_ed, curr_dir )
    
    local curr_dir_done = false
    local curr_dir_files = {}
    local curr_dir_dirs = {}
    local fullname
    
    local function funcdir(path, patt)
        for file in lfs.dir(path) do
            if file ~= "."  then --and file ~= ".." then
                    local f = pathut.chain(path, file)
                    local attr = lfs.attributes (f)
                    assert (type(attr) == "table")
                    if attr.mode == "directory" then
                        table.insert(curr_dir_dirs, {path=f,name=file,is_dir=true})
                    elseif (not patt) or file:match(patt) then
                        table.insert(curr_dir_files, {path=f,name=file,is_dir=false})
                    end
            end
        end
        -- needed in linux
        table.sort(curr_dir_dirs, function(a,b) return a.name < b.name end)
        table.sort(curr_dir_files, function(a,b) return a.name < b.name end)
    end
    
    local yesnoD = gui.YesNo("overwrite?")
    
    --local regionsize = ffi.new("ImVec2[1]")
    local save_file_name = ffi.new("char[256]",args.filename or "")
    local function filechooser(sfile)
        if sfile then save_file_name = ffi.new("char[256]",sfile) end

        ig.SetNextWindowSizeConstraints(ig.ImVec2(300,400), ig.ImVec2(ig.FLT_MAX,ig.FLT_MAX))
        if (ig.BeginPopupModal(args.key)) then --, nil, ffi.C.ImGuiWindowFlags_AlwaysAutoResize)) then

            local tsize = ig.CalcTextSize(curr_dir_ed, nil,false, -1.0);
            ig.PushItemWidth(tsize.x + ig.GetStyle().ItemInnerSpacing.x * 2)
            if ig.InputText("##dir",curr_dir_ed,256,0,nil,nil) then
                curr_dir = ffi.string(curr_dir_ed)
                curr_dir_done = false 
            end
            ig.PopItemWidth()
            
            if not curr_dir_done then
                curr_dir_files , curr_dir_dirs = {},{} 
                funcdir(curr_dir,ffi.string(pattern_ed))
                curr_dir_done = true
            end
            
            local regionsize = ig.GetContentRegionAvail()
            local desiredY = math.max(regionsize.y - ig.GetFrameHeightWithSpacing()*3,200)
            ig.BeginChild("files", ig.ImVec2(0,desiredY), true, 0)
            
            for i,v in ipairs(curr_dir_dirs) do
                if(ig.Selectable(v.name.." ->",false,ig.lib.ImGuiSelectableFlags_AllowDoubleClick,ig.ImVec2(0,0))) then 
                    if (ig.IsMouseDoubleClicked(0)) then
                            ffi.copy(save_file_name, "")
                            curr_dir = pathut.abspath(v.path)
                            ffi.copy(curr_dir_ed,curr_dir)
                            curr_dir_done = false
                    end
                end
            end
            for i,v in ipairs(curr_dir_files) do
                if(ig.Selectable(v.name,false,ig.lib.ImGuiSelectableFlags_AllowDoubleClick,ig.ImVec2(0,0))) then
                    if (ig.IsMouseDoubleClicked(0)) then
                        ffi.copy(save_file_name, v.name)
                    end
                end
                
            end
            ig.EndChild()
            
            if not args.choose_dir then
                ig.InputText("file",save_file_name,256)
                if ig.InputText("pattern",pattern_ed,32,ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then curr_dir_done = false end
            end
            local doit = false
            
            if ig.Button("OK") then
                local savefilename = save_file_name~=nil and ffi.string(save_file_name) or nil
                fullname = ""
                if #savefilename > 0 then
                    fullname = pathut.abspath(pathut.chain(curr_dir,savefilename))
                    if args.check_existence then
                        if lfs.attributes(fullname) then
                            print("check_existence true",fullname)
                            yesnoD.open()
                        else
                            print("check_existence false",fullname)
                            doit = true
                        end
                    else
                        doit = true
                    end
                elseif args.choose_dir then
                    doit = true
                else
                    ig.CloseCurrentPopup(); 
                end
            end
            doit = yesnoD.draw(doit)
            if doit then
                if funcOK then
                    funcOK(fullname, curr_dir, savefilename)
                else
                    filename_p[0] = fullname
                end
                ig.CloseCurrentPopup();
            end
            ig.SameLine()
            if ig.Button("CANCEL") then 
                ig.CloseCurrentPopup(); 
            end
            ig.EndPopup()
    
        end
    end
    return {draw = filechooser, open = function() curr_dir_done = false;ig.OpenPopup(args.key) end,func = funcOK}
end


function gui.TabReorder(reorder_func)
    assert(reorder_func, "TabReorder created without reorder_func")
    local drag_begun
    local just_reordered
    local M = {}
    M.Update = function()
            local TabBar = ig.GetCurrentTabBar()
            if TabBar.ReorderRequestTabId == 0 then
                -- drag just finished
                if drag_begun and ig.IsMouseReleased(0) then
                    local order_inv = {}
                    local order = {}
                    
                    local Tabs = TabBar.Tabs
                    for i=0, Tabs.Size-1 do
                        local tab = Tabs.Data[i]
                        order_inv[tab.BeginOrder + 1] = i + 1
                        order[i + 1] = tab.BeginOrder + 1
                    end
                    
                    just_reordered = true -- for just next frame ImGuiTabBarFlags_Reorderable will be unset
                    drag_begun = false
                    reorder_func(order, order_inv)
                end
            else --TabBar.ReorderRequestTabId == true
                drag_begun = true -- next frame will perform the action
            end
        end
	M.clear_next = function()
		just_reordered = true
	end
    M.flag = function()
        local flag = just_reordered and 0 or ig.lib.ImGuiTabBarFlags_Reorderable
        if just_reordered then just_reordered = false end
        return flag
    end
    return M
end

return gui
end

return loader