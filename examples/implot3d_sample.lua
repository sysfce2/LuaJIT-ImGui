local igwin = require"imgui.window"

--local win = igwin:SDL(800,400, "widgets",{vsync=true,use_implot=true})
local win = igwin:GLFW(800,400, "cimplot3d",{vsync=true})
win.ig.ImPlot3D_CreateContext()

local ffi = require"ffi"

local xs1, ys1, zs1 = ffi.new("float[?]",1001),ffi.new("float[?]",1001),ffi.new("float[?]",1001)
for  i = 0,1001-1 do
    xs1[i] = i * 0.001;
    ys1[i] = 0.5 + 0.5 * math.cos(50 * (xs1[i] + win.ig.GetTime() / 10));
    zs1[i] = 0.5 + 0.5 * math.sin(50 * (xs1[i] + win.ig.GetTime() / 10));
end


function win:draw(ig)
    ig.ImPlot3D_ShowDemoWindow()
    ig.Begin("Ploters")
    if (ig.ImPlot3D_BeginPlot("Line Plot", ig.ImVec2(0,0))) then
        ig.ImPlot3D_PlotLine("f(x)", xs1, ys1, zs1, 1001);
        ig.ImPlot3D_EndPlot();
    end
    ig.End()
end

local function clean()
    win.ig.ImPlot3D_DestroyContext()
end

win:start(clean)