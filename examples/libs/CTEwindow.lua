local ig
local ffi = require"ffi"
------------------- LuaCombo
local function LuaCombo(label,strs,action)
    action = action or function() end
    strs = strs or {"none"}
    local combo = {}
    local strings 
    combo.currItem = ffi.new("int[?]",1)
    local Items, anchors
    function combo:set(strs, ini)
        anchors = {}
        strings = strs
        self.currItem[0] = ini or 0
        Items = ffi.new("const char*[?]",#strs)
        for i = 0,#strs-1  do
            anchors[#anchors+1] = ffi.new("const char*",strs[i+1])
            Items[i] = anchors[#anchors]
        end
        action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
    end
    function combo:set_index(ind)
        self.currItem[0] = ind or 0
        action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
    end
    combo:set(strs)
    function combo:draw()
        if ig.Combo(label,self.currItem,Items,#strings,-1) then
            action(ffi.string(Items[self.currItem[0]]),self.currItem[0])
        end
    end
    function combo:get()
        return ffi.string(Items[self.currItem[0]]),self.currItem[0]
    end
    return combo
end
--local Lang_combo = LuaCombo("Lang",{"CPP","Lua","HLSL","GLSL","C","SQL","AngelScript"},function(a,b) print(a,b) end)
local function toint(x) return ffi.new("int",x) end
local function Render(self)
	local editor = self.editor
	local cpos = editor:GetCursorPosition()
	ig.Begin(self.ID, nil, ig.lib.ImGuiWindowFlags_HorizontalScrollbar + ig.lib.ImGuiWindowFlags_MenuBar);
		ig.SetWindowSize(ig.ImVec2(800, 600), ig.lib.ImGuiCond_FirstUseEver);
		if (ig.BeginMenuBar())
		then
			if (ig.BeginMenu("File"))
			then
				if (ig.MenuItem("Save"))
				then
					--auto textToSave = editor.GetText();
					--/// save text....
				end
				if (ig.MenuItem("Quit", "Alt-F4"))
				then
					print("quit")--break;
				end
				ig.EndMenu();
			end
	
			if (ig.BeginMenu("Edit"))
			then
				local ro = ffi.new("bool[?]",1,editor:IsReadOnly());
				if (ig.MenuItem("Read-only mode", nil, ro)) then
					editor:SetReadOnly(ro[0])
				end
				ig.Separator();

				if (ig.MenuItem("Undo", "ALT-Backspace", nil, not ro[0] and editor:CanUndo())) then
					editor:Undo()
				end
				if (ig.MenuItem("Redo", "Ctrl-Y", nil,not ro[0] and editor:CanRedo()))
				then
					editor:Redo();
				end
				ig.Separator();

				if (ig.MenuItem("Copy", "Ctrl-C", nil, editor:HasSelection())) then
					editor:Copy();
				end
				if (ig.MenuItem("Cut", "Ctrl-X", nil, not ro[0] and editor:HasSelection())) then
					editor:Cut();
				end
				if (ig.MenuItem("Delete", "Del", nil, not ro[0] and editor:HasSelection())) then
					editor:Delete();
				end
				if (ig.MenuItem("Paste", "Ctrl-V", nil, not ro[0] and ig.GetClipboardText() ~= nil)) then
					editor:Paste();
				end
				ig.Separator();

				if (ig.MenuItem("Select all", nil, nil)) then
					editor:SetSelection(ig.Coordinates(), ig.Coordinates(editor:GetTotalLines(), 0),ig.lib.Normal);
				end
				ig.EndMenu();
			end

			if (ig.BeginMenu("View")) then
			
				if (ig.MenuItem("Dark palette")) then
					editor:DarkPalette();
				end
				if (ig.MenuItem("Light palette")) then
					editor:LightPalette();
				end
				if (ig.MenuItem("Retro blue palette")) then
					editor:RetroBluePalette();
				end
				ig.EndMenu()
			end
			ig.EndMenuBar();
		end
		
		ig.Text("%6d/%-6d %6d lines  | %s | %s | %s | %s", toint(cpos.mLine + 1), toint(cpos.mColumn + 1), toint(editor:GetTotalLines()),
		editor:IsOverwrite() and "Ovr" or "Ins",
		editor:CanUndo() and "*" or " ",
		editor:GetLanguageDefinition():getName(),
		self.file_name)
		ig.SameLine()
		self.lang_combo:draw()
		editor:Render("texteditor")
	ig.End()
end
local function CTEwindow(file_name)
	local strtext = ""
	local ext = ""
	if file_name then
		local file,err = io.open(file_name,"r")
		assert(file,err)
		strtext = file:read"*a"
		file:close()
		ext = file_name:match("[^%.]+$")
	end

	local W = {file_name = file_name or ""}
	local editor = ig.TextEditor()
	W.editor = editor
	editor:SetText( strtext)
	--local lang
	local langF = {ig.LangDef, ig.LangDef_CPP, ig.LangDef_Lua, ig.LangDef_HLSL, ig.LangDef_GLSL, ig.LangDef_C, ig.LangDef_SQL, ig.LangDef_AngelScript}
	W.lang_combo = LuaCombo("Lang",{"none","CPP","Lua","HLSL","GLSL","C","SQL","AngelScript"},
				function(name,ind) 
					print(name,ind)
					if ind > 0 then
						editor:SetLangDef(langF[ind+1]())
					end
				end)
	if ext == "cpp" or ext == "hpp" then
		W.lang_combo:set_index(1)
		--lang = ig.LangDef_CPP();
	elseif ext == "lua" then
		W.lang_combo:set_index(2)
		--lang = ig.LangDef_Lua()
	else
		W.lang_combo:set_index(0)
		print"unknown language"
		--lang = nil --ig.LangDef_CPP()
	end
	--editor:SetLangDef(lang)
	W.Render = Render
	W.ID = "CTE##"..tostring(W)
	return W
end

return function(iglib)
	ig = iglib
	return {CTEwindow=CTEwindow}
end

