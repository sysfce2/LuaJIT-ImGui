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
local bold = ffi.new("bool[?]",1,false)

local Colors = require"imgui.enums".Color

local gui = require"imgui.libs.filebrowser"(ig)
local init_dir = jit.os=="Windows" and [[c:/windows/Fonts]] or "/"
local fB = gui.FileBrowser(nil,{curr_dir=init_dir,pattern=[[%.tt[cf]$]]},function(f)
    LoadFont(f)
end)

local open_style_editor = ffi.new("bool[?]",1,false)

----------coversion funcs
local max, min = math.max, math.min
local function RGB2HSV(r,g,b,h,s,v)
	local var_R = r;  
	local var_G = g;
	local var_B = b;

	local var_Min = min(min( var_R, var_G), var_B );    --//Min. value of RGB
	local var_Max = max(max( var_R, var_G), var_B );    --//Max. value of RGB
	local del_Max = var_Max - var_Min;             --//Delta RGB value

	local V = var_Max;
	local H,S;
	if ( del_Max == 0.0 )                     --//This is a gray, no chroma...
	then
		H = 0.0;                               --//HSV results from 0 to 1
		S = 0.0;
	else                                    --//Chromatic data...
		S = del_Max / var_Max;
		
		local del_R = ( ( ( var_Max - var_R ) / 6.0 ) + ( del_Max / 2.0 ) ) / del_Max;
		local del_G = ( ( ( var_Max - var_G ) / 6.0 ) + ( del_Max / 2.0 ) ) / del_Max;
		local del_B = ( ( ( var_Max - var_B ) / 6.0 ) + ( del_Max / 2.0 ) ) / del_Max;
		
		if      ( var_R == var_Max ) then H = del_B - del_G;
		elseif ( var_G == var_Max ) then H = ( 1.0 / 3.0 ) + del_R - del_B;
		elseif ( var_B == var_Max ) then H = ( 2.0 / 3.0 ) + del_G - del_R; end
		
		if ( H < 0.0 ) then H += 1.0 end
		if ( H > 1.0 ) then H -= 1.0; end
	end
	h[0],s[0],v[0] = H, S, V
end
local floor = math.floor
local function HSV2RGB(H,S,V,r,g,b)

	local var_r, var_g , var_b;
	
	if ( S == 0.0 )                       --//HSV from 0 to 1
	then
		var_r = V;
		var_g = V;
		var_b = V;
	else
		local var_h = H * 6.0;
		if ( var_h == 6.0 ) then var_h = 0.0; end     --//H must be < 1
		local var_i = floor( var_h );             --//Or ... var_i = floor( var_h )
		local var_1 = V * ( 1.0 - S );
		local var_2 = V * ( 1.0 - S * ( var_h - var_i ) );
		local var_3 = V * ( 1.0 - S * ( 1.0 - ( var_h - var_i ) ) );
		
		if      ( var_i == 0 ) then var_r = V     ; var_g = var_3 ; var_b = var_1; 
		elseif ( var_i == 1 )  then var_r = var_2 ; var_g = V     ; var_b = var_1; 
		elseif ( var_i == 2 )  then var_r = var_1 ; var_g = V     ; var_b = var_3; 
		elseif ( var_i == 3 )  then var_r = var_1 ; var_g = var_2 ; var_b = V;   
		elseif ( var_i == 4 )  then var_r = var_3 ; var_g = var_1 ; var_b = V;    
		else                        var_r = V     ; var_g = var_1 ; var_b = var_2; end
		
	end
	
	r[0],g[0],b[0] = var_r, var_g , var_b
end

--[[
local R,G,B = 0.31,0.75,1
local h,s,v = ffi.new("float[1]"),ffi.new("float[1]"),ffi.new("float[1]")
local r,g,b = ffi.new("float[1]"),ffi.new("float[1]"),ffi.new("float[1]")
RGB2HSV(R,G,B,h,s,v)
print("hsv",h[0],s[0],v[0])
--inv
--v[0] = 1 - 0.99*v[0]
v[0] = 1 - v[0]
v[0] = max(0.01,v[0])

print("hsv",h[0],s[0],v[0])
HSV2RGB(h[0],s[0],v[0],r,g,b)
print(R,r[0],G,g[0],B,b[0])
----------
RGB2HSV(r[0],g[0],b[0],h,s,v)
--inv
--v[0] = 1 - 0.99*v[0]
v[0] = (1 - v[0]) --/0.99
HSV2RGB(h[0],s[0],v[0],r,g,b)
print(R,r[0],G,g[0],B,b[0])
do return end
--]]
-------------------------Style ---------------------
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

local function getPaletteColors(pal)
	pal = pal or current_palette
	local cols = {}
    for i,v in ipairs(Colors) do
    if v.value < ig.lib.count then
		local col = pal:const_get(i-1)
		table.insert(cols, col)
    end
    end
	return cols
end

local function SaveStyle()
	local style = ig.GetStyle()
	--style = ffi.cast("struct ImGuiStyle[1]",style[0])
	style = ffi.new("struct ImGuiStyle[1]",style[0])
	
	local cols = getPaletteColors()
	local serializer = require"imgui.libs.serializer_c".autoser_cdata
	--print(serializer({style = style, custom_palette = cols}))
	
	local s_str = serializer({style = style, custom_palette = cols}) 
	
	local f, err = pathut.file_open_here()("saved_style.lua","w")
    if not f then print(err);error"opening file" end
    f:write(s_str)
    f:close()
	--take saved to custom
	ffi.copy(custom_ig_style, style,ffi.sizeof(custom_ig_style))
	for i, col in ipairs(cols) do
		custom_palette:set(col,i-1)
	end
	current_ig_style[0] = 2
	SetDocsStyle()
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
			--custom_palette:set(ig.U32(0,0,1,1),ig.lib.keyword)
			--custom_palette:set(ig.U32(0.5,0.5,0.5,1),ig.lib.string)
			custom_palette:set(ig.U32(0.5,1,0.5,0.4),ig.lib.selection)
end

local function initStyle()
	--------------load saved_style
	local f, err = pathut.file_open_here()("saved_style.lua","r")
	if not f then -- do default
			local style = ig.GetStyle()
			style.FrameRounding = 8
			style.GrabRounding = 8
			style.WindowRounding = 8
			style.FrameBorderSize = 1
			ig.StyleColorsLight()
			current_ig_style[0] = 2
			--current_palette = ig.TextEditor_GetLightPalette()
				------ custom palette
			cust_pal_default()
			current_palette = custom_palette
			custom_ig_style = ffi.new("ImGuiStyle[1]")
			ffi.copy(custom_ig_style, style,ffi.sizeof(custom_ig_style))
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

local function show_palette()
    ig.Separator()
    for i,v in ipairs(Colors) do
    if v.value < ig.lib.count then
        local col = ig.ColorConvertU32ToFloat4(current_palette:const_get(i-1))
        local colptr = ffi.new("float[4]",{col.x, col.y, col.z, col.w})
        ig.ColorButton(v.name.."###"..tostring(i), col)  
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
        fnt_cfg.FontLoaderFlags = bit.bor(fnt_cfg.FontLoaderFlags, monohinting[0] and ffi.C.ImGuiFreeTypeLoaderFlags_MonoHinting or 0, monochrome[0] and ffi.C.ImGuiFreeTypeLoaderFlags_Monochrome or 0,bold[0] and ig.lib.ImGuiFreeTypeLoaderFlags_Bold or 0) 
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

local ig_colors_copy = ffi.new("ImVec4[?]", ig.lib.ImGuiCol_COUNT)
local pal_colors_copy
local pal_colors_hsv
local ig_colors_hsv

local function get_ig_colors()
	local igcolors = ig.GetStyle().Colors
	ffi.copy(ig_colors_copy,igcolors,ffi.sizeof(ig_colors_copy))
	ig_colors_hsv = {}
	for i=0,ig.lib.ImGuiCol_COUNT-1 do
		local hsv = ffi.new("float[4]")
		local colf = ig_colors_copy[i]
		--ig.ColorConvertRGBtoHSV(colf.x, colf.y, colf.z, hsv, hsv+1, hsv+2);
		RGB2HSV(colf.x, colf.y, colf.z, hsv, hsv+1, hsv+2);
		hsv[3] = colf.w
		table.insert(ig_colors_hsv, hsv)
	end
	--palette
	pal_colors_copy = getPaletteColors()
	pal_colors_hsv = {}
    for i,v in ipairs(Colors) do
    if v.value < ig.lib.count then
		local col = pal_colors_copy[i]
		local colf = ig.ColorConvertU32ToFloat4(col)
		local hsv = ffi.new("float[4]")
		--ig.ColorConvertRGBtoHSV(colf.x, colf.y, colf.z, hsv, hsv+1, hsv+2);
		RGB2HSV(colf.x, colf.y, colf.z, hsv, hsv+1, hsv+2);
		hsv[3] = colf.w
		table.insert(pal_colors_hsv, hsv)
    end
    end
end

local function process_colors(cuus)
	local curv = cuus[3]
	local igstyle = ig.GetStyle()
	local igcolors = igstyle.Colors
	for i,col in ipairs(ig_colors_hsv) do
		local H = cuus[1]:calc(col[0])
		local S = cuus[2]:calc(col[1])
		local V = cuus[3]:calc(col[2])
		local colvec = ffi.new("float[4]")
		--ig.ColorConvertHSVtoRGB(H,S,V,colvec,colvec+1,colvec+2)
		HSV2RGB(H,S,V,colvec,colvec+1,colvec+2)
		colvec[3] = col[3]
		ffi.copy(igcolors[i-1], colvec, ffi.sizeof("float[4]"))
		ffi.copy(custom_ig_style, igstyle,ffi.sizeof(custom_ig_style))
	end
	for i,col in ipairs(pal_colors_hsv) do
		local H = cuus[1]:calc(col[0])
		local S = cuus[2]:calc(col[1])
		local V = cuus[3]:calc(col[2])
		local colvec = ffi.new("float[4]")
		--ig.ColorConvertHSVtoRGB(H,S,V,colvec,colvec+1,colvec+2)
		HSV2RGB(H,S,V,colvec,colvec+1,colvec+2)
		colvec[3] = col[3]
		local cv2 = ffi.new("ImVec4",colvec[0],colvec[1],colvec[2],colvec[3])
		--local colp = ig.ColorConvertFloat4ToU32(ffi.cast("struct ImVec4_c",colvec))
		local colp = ig.ColorConvertFloat4ToU32(cv2)
		custom_palette:set(colp,i-1)
	end
	current_palette = custom_palette
	current_ig_style[0] = 2
	SetDocsStyle()
end
local show_color_processer = ffi.new("bool[?]",1,false)

-- processer
local strs = {"identity","inversion","inversionV"}
local action = function(LC) return function(it,id)
    if it=="identity" then
        LC:setpoints({[0]={x=0,y=0},{x=1,y=1}})
    elseif it == "inversion" then
        LC:setpoints({[0]={x=0,y=1},{x=1,y=0}})
	elseif it == "inversionV" then
        LC:setpoints({[0]={x=0,y=1},{x=1,y=0.01}})
    end
end
end
local curr_curve = 1
local curve_labels = {"H","S","V"}
local LUTsize = 256
local cux = ig.LuaCurve(curve_labels[1],LUTsize)
local cuy = ig.LuaCurve(curve_labels[2],LUTsize)
local cuz = ig.LuaCurve(curve_labels[3],LUTsize)
cux:preset_set(strs,1,action(cux))
cuy:preset_set(strs,1,action(cuy))
cuz:preset_set(strs,1,action(cuz))
local cuus = {cux,cuy,cuz}
local function color_processer()
		if ig.Begin("color processer") then
			for i=1,3 do
				local dopop = false
				if i == curr_curve then
					ig.PushStyleColor(ig.lib.ImGuiCol_Button, ig.ImVec4(1,0,0,1)); dopop = true
				end
				if ig.SmallButton(curve_labels[i].."##tab") then curr_curve = i end
				if dopop then ig.PopStyleColor(1); end
				ig.SameLine()
			end
			ig.NewLine()
			local scpos = ig.GetCursorScreenPos()
			ig.SetCursorScreenPos(scpos)
			ig.BeginDisabled()
			for i=1,3 do
				if i~=curr_curve then
					ig.SetCursorScreenPos(scpos)
					--ig.PushStyleColor(ig.lib.ImGuiCol_PlotLinesHovered, ig.ImVec4(0,0,1,1));
					ig.PushID(i)
					cuus[i]:draw()
					ig.PopID()
					--ig.PopStyleColor(1)
				end
			end
			ig.EndDisabled()
			ig.SetCursorScreenPos(scpos)
			if cuus[curr_curve]:draw() then
				process_colors(cuus)
			end

			if ig.SmallButton("Keep") then
				show_color_processer[0] = false
			end
			ig.SameLine()
			if ig.SmallButton("Discard") then
				show_color_processer[0] = false
				local igstyle = ig.GetStyle()
				local igcolors = igstyle.Colors
				ffi.copy(igcolors,ig_colors_copy,ffi.sizeof(ig_colors_copy))
				ffi.copy(custom_ig_style, igstyle,ffi.sizeof(custom_ig_style))
				for i,col in ipairs(pal_colors_copy) do
					custom_palette:set(col,i-1)
				end
				SetDocsStyle()
			end
		end
		ig.End()
end


local function renderMenuFonts()
    if (ig.BeginMainMenuBar()) then
        if ig.BeginMenu"Style" then
		--ig.Checkbox("open editor",open_style_editor)
		ig.MenuItem("show style editor", nil, open_style_editor)
		if ig.MenuItem("show color processer", nil, show_color_processer) then 
			if show_color_processer[0] then
				get_ig_colors()
				cux:preset_init()
				cuy:preset_init()
				cuz:preset_init()
			end
		end
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
            if ig.MenuItem("Bold", nil, bold, usefreetype[0]) then
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
				else
					show_palette()
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
	if show_color_processer[0] then
		color_processer()
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