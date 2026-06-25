---[[-----------------------------------hack for being able to require in cimNotepad dir------
local sep = package.config:sub(1,1)
local currpath = debug.getinfo(1,'S').source
currpath = currpath:match("@(.+)[\\/]([^\\/]+)")
print("cimNotepad scriptpath:",currpath)
package.path = currpath..sep.."?.lua;"..package.path
print(package.path)
-------------------------------------------------------------------------------
--]]
local igwin = require"imgui.window"
--local win = igwin:SDL(1000,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=false, not_main_dock_space = true})
local win = igwin:GLFW(1000,600, "ColorTextEditor",{vsync=true,use_imgui_viewport=false, not_main_dock_space = true})

local ig = win.ig
local CTE = require"CTEwindow"(win.ig)
local gui = require"imgui.libs.filebrowser"(win.ig)
local ffi = require"ffi"
--------Thread execute
local Exec = require"executer"
local Execute, ExecutePull, hasThread, executable, debuggerlinda = Exec.Execute, Exec.ExecutePull, Exec.hasThread, Exec.executable, Exec.debuggerlinda
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
local setStack

local function addEditor(fullname, line, is_new)
--print("addEditor",fullname, line, is_new)
        if opendocfnames[fullname] then
			if line then
				for i,doc in ipairs(opendocs) do
					if doc.file_name == fullname then 
						--print("ScrollToLine", line,i)
						doc.editor:SetCursor(ig.DocPos(line-1,0)[0])
						doc.editor:ScrollToLine(line-1, ig.lib.alignTop)
						doc.editor:SetFocus()
						curr_opendoc = i
						set_tab = i
						return doc
					else
						--print(doc.file_name)
					end
				end
				print("Error not found",fullname)
			end
			return -- to avoid reopening
		end 
        opendocfnames[fullname] = true
		--print"open"
        local doc = CTE.CTEwindow(fullname,{Log = Log, is_new = is_new, setStack = setStack, line = line, notifications = notifications})
        table.insert(opendocs,doc);
		curr_opendoc = #opendocs
        set_tab = #opendocs
        doc.shrt_name = fullname:match([[([^/\]+)$]])
		return doc
end

setStack = function(stack)
	for i,doc in ipairs(opendocs) do
		doc.editor:ClearMarkers();
	end
	Stack = stack
	for i,v in ipairs(stack) do
		if v.source:match"^@" then
			local doc = addEditor(v.source:sub(2), v.currentline)
			if doc then
				doc.editor:AddMarker( v.currentline-1, 0, ig.U32(128/255, 0, 32/255, 128/255), "", "Error detected on this line");
			end
			break
		end
	end
end

local function renderStack()
	ig.Begin("callStack")--,nil,ig.lib.ImGuiWindowFlags_NoMove)
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
				if ig.Button(source..":"..tostring(lev.currentline)) then
					addEditor(source, lev.currentline)
				end
			end
			--ig.TableNextColumn();ig.TextUnformatted(tostring(lev.currentline))
		end
		ig.EndTable()
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
local function CloseEditor(id)
    local doc = table.remove(opendocs,id)
    opendocfnames[doc.file_name] = nil
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
--addEditor(gui.pathut.abspath([[../cimgui/imgui/imgui.cpp]]))

--add relative to CWD
-- print("load:",gui.pathut.abspath("examples/loop.lua"))
-- addEditor(gui.pathut.abspath("examples/loop.lua"),5)

--add relative to this script path
print("load:",gui.pathut.chain(currpath,"loop.lua"))
addEditor(gui.pathut.chain(currpath,"loop.lua"),5)

--addEditor(gui.pathut.abspath("CTE_sample.lua"),77)
--addEditor(gui.pathut.abspath("CTE_sample.lua"),29)
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
function win:draw(ig)
    --ig.ShowDemoWindow()
    --Log:Add("another frame\n")
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
        ig.DockBuilderDockWindow("callStack", dock_id_bottom_right[0]);
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

    --ig.SetWindowSize(ig.ImVec2(800, 600), ig.lib.ImGuiCond_FirstUseEver);
    --ig.TextUnformatted("curr_opendoc: "..tostring(curr_opendoc).." set_tab: "..tostring(set_tab))
    if (ig.BeginTabBar("##Tabs", ig.lib.ImGuiTabBarFlags_None)) then
        local opened =  ffi.new("bool[?]",1,true)
        for i,v in ipairs(opendocs) do
			--if set_tab ~= -1 then print("settint_tab",i,set_tab,curr_opendoc) end
            local opentab = ig.BeginTabItem(v.shrt_name.."##"..i, opened,(i==set_tab) and ig.lib.ImGuiTabItemFlags_SetSelected or 0)
            if ig.IsItemHovered() then ig.SetTooltip(v.file_name) end
            if opentab then
				--if set_tab ~= -1 then print("opentab",i,set_tab,curr_opendoc, "render",set_tab == -1 or set_tab == i) end
				if set_tab == -1 or set_tab == i then
					--if set_tab == i then set_tab = -1 end
					set_tab = -1
					curr_opendoc = i
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
			if (ig.MenuItem("goto29")) then
				editor:SetCursor(ig.DocPos(29-1,0)[0])
				editor:ScrollToLine(29-1, ig.lib.alignTop)
			end
			if (ig.MenuItem("iterate")) then
				--ig.lib.IterateIdentifiers(editor,it_cb)
				editor:IterateIdentifiers(it_cb)
			end
			ig.EndMenu()
		end
		ig.EndMenuBar()
	end

    ig.End() --documents
    
    ig.Begin("comments")--,nil,ig.lib.ImGuiWindowFlags_NoMove)
        Log:Draw()
    ig.End()
	
	renderStack()
    
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