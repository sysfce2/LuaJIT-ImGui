--[[-----------------------------------hack for being able to require in cimNotepad dir------
local sep = package.config:sub(1,1)
local currpath = debug.getinfo(1,'S').source
currpath = currpath:match("@(.+)[\\/]([^\\/]+)")
print("cimNotepad scriptpath:",currpath)
package.path = currpath..sep.."?.lua;"..package.path
print(package.path)
-------------------------------------------------------------------------------
--]]
local igwin = require"imgui.window"
local win = igwin:SDL(1000,600, "cimNotepad",{vsync=true,use_imgui_viewport=false, not_main_dock_space = true})
--local win = igwin:GLFW(1000,600, "cimNotepad",{vsync=true,use_imgui_viewport=false, not_main_dock_space = true})

local pathut = require"imgui.libs.path"
local currpath = pathut.file_path()
-------singleton app
local sing,err = io.open(pathut.chain(currpath,"singleton.log"),"r")
if sing then
    print"there is singleton open, on error delete 'singleton.log' from cimNotepad folder"
    sing:close()
    return
else
    --create singleton.log
    sing,err =io.open(pathut.chain(currpath,"singleton.log"),"w")
    assert(sing, err)
    sing:close()
end
----------------------------
local ig = win.ig
local CTE = dofile(pathut.chain(currpath,"CTEwindow.lua"))(win.ig)
local gui = require"imgui.libs.filebrowser"(win.ig)
local ffi = require"ffi"
--------Thread execute
--local Exec = require"executer"
local Exec = dofile(pathut.chain(currpath,"executer.lua"))
local ExecutePull, send_breakpoint = Exec.ExecutePull, Exec.send_breakpoint
------------------------------------------------------------------

local Log = win.ig.Log() -- app Log
--tab orderer docs
local opendocs = {}
local opendocfnames = {}
--set curr_opendoc in next draw
local set_tab = -1
local curr_opendoc = 1
local close_doc

local notifications = ig.Notifications()
local showhelp = false

local Stack = {}
local StackLevel = 1
local Vars = {}
local setStack

local addEditor

setStack = function(stack,err, vars)

    Vars = vars or {}
    for i,doc in ipairs(opendocs) do
        doc.editor:ClearMarkers();
    end

    Stack = stack
    --add error marker
    for i,v in ipairs(stack) do
        if v.source:match"^@" then
            StackLevel = i
            local doc = addEditor(v.source:sub(2), v.currentline)
            if doc then
                doc.editor:AddMarker( v.currentline-1, 0, ig.U32(128/255, 0, 32/255, 128/255), "", err or "Error detected on this line");
            end
            break
        end
    end
end

local function recursiveTree(k,v, look_up, parent_str)
    look_up = look_up or {}
    parent_str = parent_str or ""
    if look_up[v] then ig.TextUnformatted(tostring(k)..": recursion: "..look_up[v]) return end
    look_up[v] = parent_str.."["..k.."]"
    if ig.TreeNode(k) then
        for k2,v2 in pairs(v) do
            if type(v2)=="table" then
                recursiveTree(k2,v2,look_up,parent_str.."["..k.."]")
            else
                ig.TextUnformatted(tostring(k2)..": "..tostring(v2))
            end
        end
        ig.TreePop()
    end
end

local function renderVars()

    ig.TextUnformatted("StackLevel:"..tostring(StackLevel))
    ig.Separator()
    if Vars[StackLevel] then
        for k,v in pairs(Vars[StackLevel]) do
            if type(v)=="table" then
                recursiveTree(k,v)
            else
                ig.TextUnformatted(tostring(k)..": "..tostring(v))
            end
        end
    end

end


local function renderStack()

    if ig.BeginTable("stack_levels", 4, ig.lib.ImGuiTableFlags_Borders 
    --+ ig.lib.ImGuiTableFlags_RowBg 
    --+ ig.lib.ImGuiTableFlags_ScrollY + ig.lib.ImGuiTableFlags_Resizable 
    --+ ig.lib.ImGuiTableFlags_SizingFixedFit
    + ig.lib.ImGuiTableFlags_SizingStretchProp 
    ) then
        ig.TableSetupColumn("name");
        ig.TableSetupColumn("what");
        ig.TableSetupColumn("namewhat");
        ig.TableSetupColumn("source");
        ig.TableHeadersRow();
        for i,lev in ipairs(Stack) do
            ig.TableNextRow()
            ig.TableNextColumn();ig.TextUnformatted(lev.name or "")
            ig.TableNextColumn();ig.TextUnformatted(lev.what or "")
            ig.TableNextColumn();ig.TextUnformatted(lev.namewhat or "")
            ig.TableNextColumn();
            if lev.source == "=[C]" then
                ig.TextUnformatted(lev.source..":"..tostring(lev.currentline))
            else
                local source = lev.source:sub(2)
                local shrt_name = source
                local doc = opendocfnames[source]
                if not doc then 
                    --print("not found",source)
                    shrt_name = source
                else
                    shrt_name = doc.shrt_name
                end
                if ig.Selectable(shrt_name..":"..tostring(lev.currentline),nil,ig.lib.ImGuiSelectableFlags_SpanAllColumns) then
                    StackLevel = i
                    addEditor(source, lev.currentline)
                end
            end
        end
        ig.EndTable()
    end

end

local function renderStackVars()
    ig.Begin"StackVars"
        if (ig.BeginTabBar("##TabsStackVars", ig.lib.ImGuiTabBarFlags_None)) then
            if ig.BeginTabItem("Stack") then
                renderStack()
                ig.EndTabItem();
            end
            if ig.BeginTabItem("Vars") then
                renderVars()
                ig.EndTabItem();
            end
        ig.EndTabBar();
        end
    ig.End()
end

local confirm_close = gui.YesNo("There are unsaved changes. Do you still want to close?")
local function CheckCloseEditor(id)
    local doc = opendocs[id]
    if doc.editor:CanUndo() then
        confirm_close.open()
        return false
    end
    return true
end


local fb = gui.FileBrowser(nil,{key="loader",pattern=nil},
    function(fullname,dir,fname)
        addEditor(fullname)
    end)
local fbs = gui.FileBrowser(nil,{key="saver",check_existence=true},
    function(fname)
        local doc = opendocs[curr_opendoc]
        doc:Save(fname)
    end)
    
--add editors
--add relative to this script path
--print("load:",gui.pathut.chain(currpath,"loop.lua"))
--addEditor(gui.pathut.chain(currpath,"loop.lua"))

local function showTabBar()
	local TabBar = ig.GetCurrentTabBar()
	local Tabs = TabBar.Tabs
	print"---ShowTabBar ---------------"
	for i=0, Tabs.Size-1 do
		local tab = Tabs.Data[i]
		print("tab",i + 1 ,tab.BeginOrder + 1, opendocs[tab.BeginOrder + 1].shrt_name)
	end
end

-- uses internal API
local do_tab_action
local new_opendocs 
local new_curr_opendoc
local tab_reorder
local function getTabBar()
	local TabBar = ig.GetCurrentTabBar()
	if TabBar.ReorderRequestTabId == 0 then
		if do_tab_action then
			tab_reorder = {}
			new_opendocs = {}
			local Tabs = TabBar.Tabs
			local Tabs_reorder = {}
			print"---reordering ---------------"
			for i=0, Tabs.Size-1 do
				local tab = Tabs.Data[i]
				print("tab",i + 1 ,tab.BeginOrder + 1, opendocs[tab.BeginOrder + 1].shrt_name)
				tab_reorder[tab.BeginOrder + 1] = i + 1
				new_opendocs[i + 1] = opendocs[tab.BeginOrder + 1]
				--tab.BeginOrder = i -- -1
				Tabs_reorder[i] = {tab = tab, neworder = tab.BeginOrder}
			end
			-- do reorder TabBar.tabs
			print"do reorder TabBar.tabs"
			for i=0, Tabs.Size-1 do
				--local tab = Tabs.Data[i]
				print(Tabs_reorder[i].neworder + 1, "takes from", i + 1 )
				local tab = Tabs_reorder[i].tab
				--tab.BeginOrder = Tabs_reorder[i].neworder
				--print(Tabs_reorder[i].neworder + 1, "BeginOrder", tab.BeginOrder + 1 )
				Tabs.Data[Tabs_reorder[i].neworder] = tab
			end
			print"---check BeginOrder apply"
			for i=0, Tabs.Size-1 do
				local tab = Tabs.Data[i]
				tab.BeginOrder = i
				print("tab",i + 1 ,tab.BeginOrder + 1)
			end
			new_curr_opendoc = tab_reorder[curr_opendoc]
			curr_opendoc = new_curr_opendoc
			opendocs = new_opendocs
			print"-- new_opendocs"
			for i,v in ipairs(new_opendocs) do
				print(i,v.shrt_name)
			end
			print"--- after reordering ---------------"
			for i=0, Tabs.Size-1 do
				local tab = Tabs.Data[i]
				print("tab",i + 1 ,tab.BeginOrder + 1, opendocs[tab.BeginOrder + 1].shrt_name)
			end
			print("new curr_opendoc", new_curr_opendoc)
			do_tab_action = false
		end
	else
		if do_tab_action then print"repeat do_tab_action" end
		do_tab_action = true -- next frame will perform the action
	end
end

addEditor = function(fullname, line, is_new, breakpoints)
--print("---addEditor",fullname, line, is_new)
        if opendocfnames[fullname] then
            if line then
                for i,doc in ipairs(opendocs) do
                    if doc.file_name == fullname then 
                        doc.editor:SetCursor(ig.DocPos(line-1,0)[0])
                        doc.editor:ScrollToLine(line-1, ig.lib.alignTop)
                        doc.editor:SetFocus()
                        curr_opendoc = i
                        set_tab = i
                        return doc
                    end
                end
                print("Error not found",fullname)
            end
            return -- to avoid reopening
        end 
        
        local doc = CTE.CTEwindow(fullname,{Log = Log, is_new = is_new, notifications = notifications, send_breakpoint = send_breakpoint, breakpoints = breakpoints})
        -- set line
        if line then
            doc.editor:SetCursor(ig.DocPos(line-1,0)[0])
            doc.editor:ScrollToLine(line-1, ig.lib.alignTop)
            doc.editor:SetFocus()
        end
        opendocfnames[fullname] = doc
        table.insert(opendocs,doc);
        curr_opendoc = #opendocs
        set_tab = #opendocs
		if new_opendocs then
			table.insert(new_opendocs,doc);
		end
        doc.shrt_name = fullname:match([[([^/\]+)$]])
        return doc
end

local function CloseEditor(id)
	print("CloseEditor",id, opendocs[id].shrt_name)
    local doc = table.remove(opendocs,id)
	if new_opendocs then
		print("CloseEditor",tab_reorder[id],new_opendocs[tab_reorder[id]].shrt_name)
		table.remove(new_opendocs, tab_reorder[id])
	end
    opendocfnames[doc.file_name] = nil
end

local serializer = require"imgui.libs.serializer"
local function PersitenceSave()
    local persist = {curr_opendoc = tab_reorder and tab_reorder[curr_opendoc] or curr_opendoc}
    for i,doc in ipairs(new_opendocs or opendocs) do
        persist[i] = {file_name = doc.file_name, breakpoints = doc.breakpoints} 
    end
    local persist_str = serializer("persist", persist).."return persist;"
    local f,err =io.open(pathut.chain(currpath,"persistence.lua"),"w")
    assert(f, err)
    f:write(persist_str)
    f:close()
end

local function PersistenceLoad()
    local f,err =io.open(pathut.chain(currpath,"persistence.lua"),"r")
    if f then
        f:close()
        local persist = dofile(pathut.chain(currpath,"persistence.lua"))
        for i, v in ipairs(persist) do
            addEditor(v.file_name, nil, nil, v.breakpoints)
        end
        curr_opendoc = persist.curr_opendoc or 1
        set_tab = curr_opendoc
    else -- have initial example
        addEditor(gui.pathut.chain(currpath,"loop.lua"))
    end
end

local function getBreakPoints()
    local bp = {}
    for i, doc in ipairs(opendocs) do
        for k,v in pairs(doc.breakpoints) do
            bp[k] = bp[k] or {}
            bp[k]["@"..doc.file_name] = true
        end
    end
    return {breakpoints = bp}
end
local this = {ig = ig, Log = Log, setStack = setStack, opendocs = opendocs, notifications = notifications, getBreakPoints = getBreakPoints}
win.ig.GetIO().IniFilename = "cimNotepad.ini"
local done_docking
--use dejavu font
win.ig.lib.SetDejavu()
-- load persistence
PersistenceLoad()

function win:draw(ig)
    --ig.ShowDemoWindow()
        ----check execute
    ExecutePull(this)
    
    local lib = ig.lib
    
    local viewport = ig.GetMainViewport();
    local dockspace_id = ffi.new("ImGuiID[?]",1,ig.GetID("My Dockspace"));
    if not done_docking then
        ig.DockBuilderAddNode(dockspace_id[0], lib.ImGuiDockNodeFlags_DockSpace);
        ig.DockBuilderSetNodeSize(dockspace_id[0], viewport.Size);
        local dock_id_main = ffi.new("ImGuiID[?]",1,dockspace_id[0])--dockspace_id;
        local dock_id_top = ffi.new("ImGuiID[?]",1,0);
        local dock_id_bottom = ffi.new("ImGuiID[?]",1,0);
        local dock_id_bottom_left = ffi.new("ImGuiID[?]",1,0);
        local dock_id_bottom_right = ffi.new("ImGuiID[?]",1,0);
        ig.DockBuilderSplitNode(dock_id_main[0], lib.ImGuiDir_Up, 0.80, dock_id_top, dock_id_bottom);
        ig.DockBuilderSplitNode(dock_id_bottom[0], lib.ImGuiDir_Left, 0.50, dock_id_bottom_left, dock_id_bottom_right);
        ig.DockBuilderDockWindow("Documents", dock_id_top[0]);
        ig.DockBuilderDockWindow("comments", dock_id_bottom_left[0]);
        ig.DockBuilderDockWindow("StackVars", dock_id_bottom_right[0]);
        ig.DockBuilderFinish(dockspace_id[0]);
        done_docking = true
    end
    ig.DockSpaceOverViewport(dockspace_id[0], viewport, lib.ImGuiDockNodeFlags_PassthruCentralNode + lib.ImGuiDockNodeFlags_NoTabBar);
    
    local openfilepopup = false
    local savefilepopup = false
    local doclosefile = false
    
    --Not needed with dock_builder
    --Submit a window filling the entire viewport
    -- ig.SetNextWindowPos(viewport.WorkPos);
    -- ig.SetNextWindowSize(viewport.WorkSize);
    -- ig.SetNextWindowViewport(viewport.ID);
    
    local host_window_flags = bit.bor( ig.lib.ImGuiWindowFlags_NoTitleBar , ig.lib.ImGuiWindowFlags_NoCollapse, --ig.lib.ImGuiWindowFlags_NoResize ,
    --ig.lib.ImGuiWindowFlags_NoMove , 
    ig.lib.ImGuiWindowFlags_NoBringToFrontOnFocus, ig.lib.ImGuiWindowFlags_NoNavFocus,ig.lib.ImGuiWindowFlags_MenuBar)
    
    -- main menu
    ig.Begin("Documents",nil, host_window_flags)
        if (ig.BeginMenuBar()) then
            if (ig.BeginMenu("File")) then
                if (ig.MenuItem("New")) then
                    local fname = "new1.lua"
                    while true do
                        if not opendocfnames[fname] then break
                        else 
                            local number = fname:match("%d+")
                            fname = "new"..tostring(number + 1)..".lua"
                        end
                    end
                    addEditor(fname, nil, true)
                end
                if (ig.MenuItem("Load")) then
                    openfilepopup = true
                end
                if (ig.MenuItem("Save")) then
                    local doc = opendocs[curr_opendoc]
                    doc:Save(doc.file_name)
                end
                if (ig.MenuItem("Save As")) then
                    savefilepopup = true
                end
                if (ig.MenuItem("Close")) then
                   doclosefile = true
                   close_doc = curr_opendoc
                end
                ig.EndMenu();
            end
            ig.EndMenuBar()
        end

    if openfilepopup then fb.open() end
    fb.draw()

    if savefilepopup then fbs.open() end
    fbs.draw(opendocs[curr_opendoc] and opendocs[curr_opendoc].shrt_name)

ig.TextUnformatted("curr_opendoc: "..tostring(curr_opendoc))


    if (ig.BeginTabBar("##Tabs", ig.lib.ImGuiTabBarFlags_Reorderable)) then
		--getTabBar()
        local opened =  ffi.new("bool[?]",1,true)
        for i,v in ipairs(opendocs) do
            --if set_tab ~= -1 then print("settint_tab",i,set_tab,curr_opendoc) end
            local opentab = ig.BeginTabItem(v.shrt_name.."##"..i, opened,(i==set_tab) and ig.lib.ImGuiTabItemFlags_SetSelected or 0)
            if ig.IsItemHovered() then ig.SetTooltip(v.file_name) end
            if opentab then
                if set_tab == -1 or set_tab == i then
                    set_tab = -1
                    curr_opendoc = i
					if ig.Button("showTabBar") then showTabBar() end
                    v:Render()
                end
                ig.EndTabItem();
            end
            if not opened[0] then 
                close_doc = i
                doclosefile = true
                break
            end
        end
		getTabBar()
        ig.EndTabBar();
    end
    local doit = false
    if doclosefile then 
        doit = CheckCloseEditor(close_doc)
    end
    if confirm_close.draw(doit) then
        CloseEditor(close_doc)
    end
    
    if (ig.BeginMenuBar()) then
        Exec.renderMenuExecute(this, curr_opendoc)
            
        if ig.BeginMenu("Help") then
            if (ig.MenuItem("Show")) then
                showhelp = true
            end
            ig.EndMenu()
        end
        ig.EndMenuBar()
    end

    ig.End() --documents
    
    ig.Begin("comments")
        Log:Draw()
    ig.End()
    
    renderStackVars()
    
    -- render notifications
    local style = ig.GetStyle()
    local statusBarHeight = ig.GetFrameHeight() + 2.0 * style.WindowPadding.y;
    local mainWindowSize = ig.GetMainViewport().Size;
    local mainWindowPos = ig.GetMainViewport().Pos;
    local offset = statusBarHeight + style.ItemSpacing.y * 2.0;

    notifications:Render(ig.ImVec2(
    mainWindowPos.x + mainWindowSize.x - ig.GetStyle().ItemSpacing.x,
    mainWindowPos.y + mainWindowSize.y - ig.GetStyle().ItemSpacing.y - offset));
    
    if showhelp then
        ig.SetNextWindowSize(ig.ImVec2(500,200));
        ig.OpenPopup("Help##p")
        if ig.BeginPopupModal("Help##p") then 
            ig.TextWrapped(help_txt)
            if ig.Button("OK") then
                ig.CloseCurrentPopup()
                showhelp = false
            end
            ig.EndPopup()
        end
    end
end

win:start()

-- after start finishes
-- persistence
PersitenceSave()
-- remove singleton.log
os.remove(pathut.chain(currpath,"singleton.log"))