local function modulef(ig1, opendocs)

local ig = ig1
local ffi = require"ffi"
local pathut = require"imgui.libs.path"

local current_ig_style = ffi.new("int[?]",1)
local current_palette
local custom_palette = ig.Palette()
local custom_ig_style

--use dejavu font
local deja = ffi.new("void*[1]")
local dejasize = ig.GetDejavu(deja)
local has_freetype =  pcall(function() return ig.lib.ImGuiFreeType_GetFontLoader end)
--print("deja",dejasize,deja[0])
local usedeja = ffi.new("bool[?]",1,true)
local usefreetype = ffi.new("bool[?]",1,has_freetype)
local monohinting = ffi.new("bool[?]",1,true)
local monochrome = ffi.new("bool[?]",1,false)

local Colors = require"imgui.enums".Color

local gui = require"imgui.libs.filebrowser"(ig)
local init_dir = jit.os=="Windows" and [[c:/windows/Fonts]] or "/"
local fB = gui.FileBrowser(nil,{curr_dir=init_dir,pattern=[[%.tt[cf]$]]},function(f)
    LoadFont(f)
end)

local open_style_editor = ffi.new("bool[?]",1,false)

-------------------------Style ---------------------
local function getColors()
	local cols = {}
    for i,v in ipairs(Colors) do
    if v.value < ig.lib.count then
		local col = custom_palette:get(i-1)
		table.insert(cols, col)
    end
    end
	return cols
end
local function SaveStyle()
	local style = ig.GetStyle()
	--style = ffi.cast("struct ImGuiStyle[1]",style[0])
	style = ffi.new("struct ImGuiStyle[1]",style[0])
	
	local cols = getColors()
	local serializer = require"imgui.libs.serializer_c".autoser_cdata
	print(serializer({style = style, custom_palette = cols}))
	
	local s_str = serializer({style = style, custom_palette = cols}) 
	
	local f, err = pathut.file_open_here()("saved_style.lua","w")
    if not f then print(err);error"opening file" end
    f:write(s_str)
    f:close()
end
    ---------------- custom Palette
local function cust_pal_default()
			------ custom palette
			local lpal = ig.TextEditor_GetLightPalette()
			for i=0,ig.lib.count-1 do
			--print(i,ig.lib.count)
				local a = lpal:const_get(i)
				custom_palette:set(a, i)
			end
			custom_palette:set(ig.U32(0,0,1,1),ig.lib.keyword)
			custom_palette:set(ig.U32(0.5,0.5,0.5,1),ig.lib.string)
end

local function initStyle()
	--------------load saved_style
	local f, err = pathut.file_open_here()("saved_style.lua","r")
	if not f then -- do default
			local style = ig.GetStyle()
			style.FrameRounding = 8
			style.GrabRounding = 8
			style.WindowRounding = 8
			ig.StyleColorsDark()
			current_ig_style[0] = 0
			current_palette = ig.TextEditor_GetDarkPalette()
				------ custom palette
			cust_pal_default()
	else --we have file
		local s_str = f:read("*a")
		f:close()
		local fu,err = loadstring(s_str)
		if fu then
			local ok, styletab = pcall(fu)
			current_ig_style[0] = 2
			local style = ig.GetStyle()
			if ok and styletab then
				custom_ig_style = styletab.style
				ffi.copy(style,styletab.style,ffi.sizeof(styletab.style))
				print("style loaded",styletab.style,ffi.sizeof(styletab.style))
				--custom_palette
				local cols = styletab.custom_palette
				for i, col in ipairs(cols) do
					--print("set",col,i-1,ig.lib.count)
					custom_palette:set(col,i-1)
				end
				--cust_pal_default()
			else
				print("error loading style: no syletab", styletab)
			end
		else
			print("error loading style:", err)
		end
		current_palette = custom_palette
			
	end
	

end --init

local function SetDocsStyle()
    for i, doc in ipairs(opendocs) do
        doc.editor:SetPalette(current_palette)
        doc.diff:SetPalette(current_palette)
    end
    if current_ig_style[0] == 0 then
        ig.StyleColorsDark()
    elseif current_ig_style[0] == 1 then
        ig.StyleColorsLight()
    elseif current_ig_style[0] == 2 then
        local style = ig.GetStyle()
        ffi.copy(style,custom_ig_style,ffi.sizeof(custom_ig_style))
    end
end

local function custom_palette_Editor()
    ig.Separator()
    for i,v in ipairs(Colors) do
    if v.value < ig.lib.count then
        local col = ig.ColorConvertU32ToFloat4(custom_palette:get(i-1))
        local colptr = ffi.new("float[4]",{col.x, col.y, col.z, col.w})
        if ig.ColorEdit4(v.name.."###"..tostring(i), colptr, bit.bor(ig.lib.ImGuiColorEditFlags_NoInputs, ig.lib.ImGuiColorEditFlags_NoLabel, ig.lib.ImGuiColorEditFlags_AlphaBar)) then
            custom_palette:set(ig.U32(colptr[0], colptr[1], colptr[2], colptr[3]),i-1)
            SetDocsStyle()
        end
        ig.SameLine()
        ig.TextUnformatted(v.name)
    end
    end
end
-------------------------Fonts

local function LoadFont(file)
    --print("Loadfont", usedeja[0],usefreetype[0])
    local style = ig.GetStyle();
    style.FontSizeBase = 15.0;
    local FontsAt = ig.GetIO().Fonts
    FontsAt:Clear()
    local fnt_cfg = ig.ImFontConfig()
    if usefreetype[0] then
        fnt_cfg.FontLoaderFlags = bit.bor(fnt_cfg.FontLoaderFlags, monohinting[0] and ffi.C.ImGuiFreeTypeLoaderFlags_MonoHinting or 0, monochrome[0] and ffi.C.ImGuiFreeTypeLoaderFlags_Monochrome or 0) 
    end
    if file then
        local theFont = FontsAt:AddFontFromFileTTF(file, 0, fnt_cfg)
        if theFont~=nil then
            usedeja[0] = false
        else
            print("failed loading font",file); 
            local theFont = FontsAt:AddFontDefault(fnt_cfg) 
        end
    elseif usedeja[0] then
        ffi.copy(fnt_cfg.Name, "DejaVu")
        fnt_cfg.FontDataOwnedByAtlas = false;
        local theFont = FontsAt:AddFontFromMemoryCompressedTTF(deja[0], dejasize, 15.0, fnt_cfg);
    else
        local theFont = FontsAt:AddFontDefault(fnt_cfg)
    end
    if usefreetype[0] then
        FontsAt:SetFontLoader(ig.ImGuiFreeType_GetFontLoader())
    else
        FontsAt:SetFontLoader(ig.ImFontAtlasGetFontLoaderForStbTruetype())
    end

end


local function renderMenuFonts()
    if (ig.BeginMainMenuBar()) then
        if ig.BeginMenu"Style" then
		--ig.Checkbox("open editor",open_style_editor)
		ig.MenuItem("show style editor", nil, open_style_editor)
		if ig.SmallButton("save style") then
			SaveStyle()
		end
        if (ig.BeginMenu("Fonts")) then
            if ig.Button("Load") then
                fB.open()
            end
            fB.draw()
            ig.SameLine()
            local font0 = ig.GetIO().Fonts.Fonts.Data[0]
            local loaded_font = ffi.string(font0:GetDebugName() or "")
            ig.TextUnformatted(loaded_font)
            if ig.MenuItem("Dejavu",nil, usedeja) then
                LoadFont()
            end
            if ig.MenuItem("freetype",nil, usefreetype, has_freetype) then
                LoadFont()
            end
            ig.Separator()
            if ig.MenuItem("MonoHinting", nil, monohinting, usefreetype[0]) then
                LoadFont()
            end
            if ig.MenuItem("Monochrome", nil, monochrome, usefreetype[0]) then
                LoadFont()
            end
            ig.Separator()
            local FontScaleMain = ffi.cast("float*", ffi.cast("char*",ig.GetStyle()) + ffi.offsetof("ImGuiStyle","FontScaleMain"))
            ig.SetNextItemWidth(75)
            ig.DragFloat("font scale", FontScaleMain, 0.005, 0.3, 2 , "%.2f", ig.lib.ImGuiSliderFlags_AlwaysClamp)
            ig.EndMenu();
        end
        if (ig.BeginMenu("Color Palette"))  then 
		--[[
                if (ig.MenuItem("Dark"))  then 
                    current_ig_style = 0;
                    current_palette = ig.TextEditor_GetDarkPalette(); 
                    SetDocsStyle()
                end 
                if (ig.MenuItem("Light"))  then  
                    current_ig_style = 1;
                    current_palette = ig.TextEditor_GetLightPalette(); 
                    SetDocsStyle()
                end 
                if (ig.MenuItem("Custom"))  then 
                    current_ig_style = 1;
                    current_palette = custom_palette
                    SetDocsStyle()
                end
			--]]
				if ig.RadioButton("Dark", current_ig_style , 0) then
                    current_palette = ig.TextEditor_GetDarkPalette(); 
                    SetDocsStyle()
				end
                if ig.RadioButton("Light", current_ig_style , 1) then
                    current_palette = ig.TextEditor_GetLightPalette(); 
                    SetDocsStyle()
				end
                if ig.RadioButton("Custom", current_ig_style , 2) then
                    current_palette = custom_palette
                    SetDocsStyle()
				end
                if current_palette == custom_palette then
                    custom_palette_Editor()
                end
                ig.EndMenu();
        end 
        ig.EndMenu()
        end
        ig.EndMainMenuBar()
    end
	
	if open_style_editor[0] then
		ig.Begin("style edit")
			ig.ShowStyleEditor() 
		ig.End()
	end
end

	--check colors is correct
for i,v in ipairs(Colors) do
    assert(v.value == ig.lib[v.name])
end

initStyle()

-- SaveStyle()
-- print"done"

	return {renderMenuFonts = renderMenuFonts, LoadFont = LoadFont, current_palette = current_palette}
end

-- local igwin = require"imgui.window"
-- local win = igwin:GLFW(1000,600, "cimNotepad",{fps=30,vsync=true,use_imgui_viewport=false, not_main_dock_space = true})
-- the_module = modulef(win.ig,{})

return modulef