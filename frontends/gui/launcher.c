/*
 * Announcer.exe - Windows-only GUI launcher for the announcer wxLua GUI.
 *
 * Vanilla Lua 5.4 with the wx C module gets a thin C wrapper here so the
 * user can double-click `Announcer.exe` in the install root and the GUI
 * pops up - without a console window flashing, without typing
 * `lua.exe frontends/gui/Announcer.wx.lua` by hand, without a .bat
 * helper that defeats the purpose of having a Windows GUI build at all.
 *
 * Strategy:
 *   1. Resolve own .exe path via GetModuleFileNameW (Unicode-safe -
 *      handles install paths with non-ASCII chars like "C:\Programme\
 *      Announcer\" with umlauts) + strip filename.
 *   2. SetCurrentDirectoryW to that dir = install root.
 *   3. luaL_newstate + openlibs.
 *   4. luaL_loadfile("frontends/gui/Announcer.wx.lua") + lua_pcall.
 *      The .wx.lua script sets package.path / package.cpath itself
 *      (it expects CWD == install root, which we just ensured) and
 *      then `require "wx"` resolves to lib/wx/wx.dll. The script ends
 *      with `wx.wxGetApp():MainLoop()` which BLOCKS until the user
 *      closes the GUI window - so lua_pcall here does not return until
 *      the user quits.
 *   5. Any Lua error -> MessageBox with the traceback so the user
 *      sees what went wrong instead of a silent failure.
 *
 * Built only when -DBUILD_GUI=ON AND WIN32. Linked with WIN32 set on
 * the executable target so MinGW links it as a GUI subsystem binary
 * (no console window). See CMakeLists.txt.
 *
 * 2026-06-09 - first cut alongside v1.0.0-rc1 GUI packaging fix.
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

/* Show a Lua error message in a MessageBox. Pops the value off the
 * stack so the caller does not have to. */
static void show_lua_error( lua_State *L, const char *stage )
{
    const char *err = lua_tostring( L, -1 );
    char buf[ 4096 ];
    _snprintf( buf, sizeof buf,
        "Announcer %s failed:\r\n\r\n%s",
        stage, err ? err : "(no message)" );
    buf[ sizeof buf - 1 ] = '\0';
    MessageBoxA( NULL, buf, "Announcer launch error",
        MB_ICONERROR | MB_OK );
    lua_pop( L, 1 );
}

/* Lua error-message handler used as the msgh of lua_pcall. Appends a
 * traceback to the error string so the user sees where Announcer.wx.lua
 * blew up rather than just the top-of-stack reason. */
static int traceback( lua_State *L )
{
    const char *msg = lua_tostring( L, 1 );
    if ( msg )
        luaL_traceback( L, L, msg, 1 );
    else
        luaL_traceback( L, L, "(non-string error)", 1 );
    return 1;
}

int WINAPI WinMain( HINSTANCE hInst, HINSTANCE hPrev,
    LPSTR cmdLine, int nShow )
{
    /* 1. Resolve our own .exe path and chdir to its directory. The
     * .wx.lua script expects CWD == install root and uses
     * `././core/?.lua` style entries in package.path.
     *
     * Unicode-safe via GetModuleFileNameW + SetCurrentDirectoryW so
     * install paths containing non-ASCII characters (e.g. German
     * umlauts in "C:\Programme\Announcer\") work correctly. The ANSI
     * GetModuleFileNameA variant would mangle them under any code
     * page that is not UTF-8 (the default on most Windows installs is
     * still a regional code page in 2026).
     *
     * Buffer size: 32768 wchars matches the Windows "long path" limit
     * (UNC paths can exceed the legacy 260-char MAX_PATH). Stack-
     * allocated; ~64 KiB is well under the default 1 MiB stack. */
    wchar_t exe_path[ 32768 ];
    DWORD got = GetModuleFileNameW( NULL, exe_path,
        sizeof exe_path / sizeof exe_path[ 0 ] );
    if ( got == 0 || got >= sizeof exe_path / sizeof exe_path[ 0 ] )
    {
        MessageBoxA( NULL,
            "GetModuleFileNameW failed - cannot resolve install dir",
            "Announcer launch error", MB_ICONERROR );
        return 1;
    }
    wchar_t *last_slash = wcsrchr( exe_path, L'\\' );
    if ( last_slash )
        *last_slash = L'\0';
    if ( !SetCurrentDirectoryW( exe_path ) )
    {
        MessageBoxA( NULL,
            "SetCurrentDirectory to install root failed",
            "Announcer launch error", MB_ICONERROR );
        return 1;
    }

    /* 2. Bring up Lua + stdlib. */
    lua_State *L = luaL_newstate();
    if ( !L )
    {
        MessageBoxA( NULL,
            "luaL_newstate failed (out of memory?)",
            "Announcer launch error", MB_ICONERROR );
        return 1;
    }
    luaL_openlibs( L );

    /* 3. Push the traceback msgh, load Announcer.wx.lua, run it under
     * pcall. The .wx.lua sets package.path / package.cpath itself, so
     * we don't pre-populate them here. */
    lua_pushcfunction( L, traceback );
    int msgh = lua_gettop( L );

    if ( luaL_loadfile( L, "frontends/gui/Announcer.wx.lua" ) != LUA_OK )
    {
        show_lua_error( L, "loadfile Announcer.wx.lua" );
        lua_close( L );
        return 1;
    }
    if ( lua_pcall( L, 0, 0, msgh ) != LUA_OK )
    {
        show_lua_error( L, "Announcer.wx.lua" );
        lua_close( L );
        return 1;
    }

    lua_close( L );
    return 0;
}
