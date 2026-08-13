local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true})
local win = igwin:GLFW(800,400, "widgets",{vsync=true})
win.ig.ImPlot_CreateContext()

local ffi = require"ffi"

local xs2, ys2 = ffi.new("float[?]",11),ffi.new("float[?]",11)
for i = 0,10 do
    xs2[i] = i * 0.1;
    ys2[i] = xs2[i] * xs2[i];
end

local gettercb = ffi.cast("ImPlotPoint_getter", function(data,idx,ipp)
    local npoints = ffi.cast("int*",data)[0]
    local inv_n = 1/npoints
    ipp[0].x = idx*inv_n; 
    ipp[0].y=0.5 + 0.5 * math.sin(50 * ipp[0].x);
end)


local npoints = ffi.new("int[1]",256)

local sin,cos,pi = math.sin, math.cos, math.pi
local gettercb2 = ffi.cast("ImPlotPoint_getter", function(data,idx,ipp)
    local npoints = ffi.cast("int*",data)[0]
    local theta = pi*2*idx/npoints
    local rho = sin(2*theta)*cos(2*theta)
    ipp[0].x = cos(theta)*rho
    ipp[0].y = sin(theta)*rho
end)
-- example2 representin user functions

local mathf = [[
local abs  = math.abs
local acos  = math.acos
local asin  = math.asin
local atan  = math.atan
local atan2  = math.atan2
local ceil  = math.ceil
local cos  = math.cos
local cosh  = math.cosh
local deg  = math.deg
local exp  = math.exp
local floor  = math.floor
local fmod  = math.fmod
local frexp  = math.frexp
local huge  = math.huge
local ldexp  = math.ldexp
local log  = math.log
local log10  = math.log10
local max  = math.max
local min  = math.min
local modf  = math.modf
local pi  = math.pi
local pow  = math.pow
local rad  = math.rad
local random  = math.random
local randomseed  = math.randomseed
local sin  = math.sin
local sinh  = math.sinh
local sqrt  = math.sqrt
local tan  = math.tan
local tanh  = math.tanh
]]

local buffer = ffi.new("char[256]", "sin(x)/x")
local minx = ffi.new("double[?]",1,-20)
local maxx = ffi.new("double[?]",1,20)
local width = ffi.new("double[?]", 1, maxx[0] - minx[0])
local center = ffi.new("double[?]", 1, 0.5*(maxx[0] + minx[0]))
local infin = ffi.new("double[?]",1,math.huge)
local minfin = ffi.new("double[?]",1,-math.huge)
local luafun = function(x) return math.sin(x)/x end
local luafun_error = false
local gettercb3 = ffi.cast("ImPlotPoint_getter", function(data,idx,ipp)
    local npoints = ffi.cast("int*",data)[0]
    local inv_n = 1/npoints
    local width = maxx[0]-minx[0]
    ipp[0].x = minx[0]+idx*inv_n*width
    ipp[0].y= luafun(ipp[0].x)
end)

function win:draw(ig)
    local spec_circle = ig.ImPlotSpec()
    spec_circle.Marker = ig.lib.ImPlotMarker_Circle
    ig.ImPlot_ShowDemoWindow()
    
    local main_viewport = ig.GetMainViewport();
    ig.SetNextWindowPos(ig.ImVec2(main_viewport.WorkPos.x + 650, main_viewport.WorkPos.y + 20), ig.lib.ImGuiCond_FirstUseEver);
    ig.SetNextWindowSize(ig.ImVec2(550, 680), ig.lib.ImGuiCond_FirstUseEver);
    
    if ig.Begin("Ploters") then
    
    ig.PushItemWidth(75)
    ig.DragInt("npoints", npoints, nil, 0, 1024)
    ig.PopItemWidth()
    
    if ig.TreeNode("example1") then
        if ig.ImPlot_BeginPlot("Line Plot", ig.ImVec2(-1,-1)) then
            ig.ImPlot_PlotLineG("Line Plot",gettercb,npoints,npoints[0])
            ig.ImPlot_PlotLineG("Polar Plot",gettercb2,npoints,npoints[0])
            ig.ImPlot_Annotation(0.25,1.1,ig.ImPlot_GetLastItemColor(),ig.ImVec2(15,15),true,"function %f %s",1,"hello")
            ig.ImPlot_PlotLine("x^2", xs2, ys2, 11,spec_circle[0]);
            ig.ImPlot_EndPlot();
        end
        ig.TreePop()
    end
    
    if ig.TreeNode("example2") then
        ig.PushItemWidth(75)
        -- ig.DragScalar("min x", ig.lib.ImGuiDataType_Double, minx, nil, minfin, maxx)
        width[0] =  maxx[0] - minx[0]
        center[0] = 0.5*(maxx[0] + minx[0])
        if ig.DragScalar("center", ig.lib.ImGuiDataType_Double, center, nil, minfin, infin) then
        end
        ig.SameLine();
        --ig.DragScalar("max x", ig.lib.ImGuiDataType_Double, maxx, nil, minx, infin)
        if ig.DragScalar("width", ig.lib.ImGuiDataType_Double, width, nil, minfin, infin) then
        end
        maxx[0] = center[0] + 0.5*width[0]
        minx[0] = maxx[0] - width[0]
        ig.PopItemWidth()
        if ig.InputText("function(x)",buffer,ffi.sizeof(buffer),ig.lib.ImGuiInputTextFlags_EnterReturnsTrue) then
            local str = ffi.string(buffer)
            str = mathf .. "return function(x) return "..str.." end"
            local f = loadstring(str)
            if f then
                local ff = f()
                --test with 0
                local ok, err = pcall(ff,0)
                if not ok then
                    luafun_error = true
                else
                    luafun_error = false
                    luafun = ff
                    ig.ImPlot_SetNextAxisToFit(ig.lib.ImAxis_Y1)
                end
            else
                luafun_error = true
            end
        end
        if luafun_error then ig.SetTooltip("bad function declaration") end
        if ig.ImPlot_BeginPlot("func Plot", ig.ImVec2(-1,-1)) then
            ig.ImPlot_SetupAxisLinks(ig.lib.ImAxis_X1,minx, maxx);
            ig.ImPlot_PlotLineG("function Plot",gettercb3,npoints,npoints[0])
            ig.ImPlot_EndPlot();
        end
        ig.TreePop()
    end
    end
    ig.End()
end

win:start()

win.ig.ImPlot_DestroyContext()