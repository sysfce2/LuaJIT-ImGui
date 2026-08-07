:: this is used to rebuild imgui.lua
:: after generated adjust ffi.load path with basedir and move to lua directory

:: set your PATH if necessary for gcc and lua5.1 or luajit with:
::set PATH=%PATH%;C:\mingws\i686-7.2.0-release-posix-dwarf-rt_v5-rev1\mingw32\bin;C:\anima;
:: set PATH=%PATH%;C:\luaGL;C:\i686-7.2.0-release-posix-dwarf-rt_v5-rev1\mingw32\bin;
set PATH=%PATH%;C:\mingws\x86_64-14.2.0-release-posix-seh-msvcrt-rt_v12-rev0\mingw64\bin;C:\anima64;
:: options wchar32 and freetype
luajit.exe ./generator.lua "wchar32 freetype"

cmd /k

