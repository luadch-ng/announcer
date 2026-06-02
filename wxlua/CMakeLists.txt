# wxLua C extension - builds `wx.dll` (Lua C-module) against:
#   - vendored wxWidgets targets from wxwidgets/ subdir (wxbase, wxcore, wxadv)
#   - our existing shared `lua` target from lua/src/
#
# Source vendored from OneLuaPro/wxlua master (SHA c5e0cbbf, dated
# 2026-02-27). See ../BUNDLED.md for provenance + sync policy.
#
# This file replaces wxLua's own multi-stage CMake infrastructure with
# a single-target compile of the binding source set we need. wxLua's
# build/CMakeFunctions.cmake + build/CMakeProject.cmake expect to
# `find_package(wxWidgets)` (= external installation), which doesn't
# match our add_subdirectory(wxwidgets) model.

cmake_minimum_required(VERSION 3.20)

set(WXLUA_MOD ${CMAKE_CURRENT_SOURCE_DIR}/modules)

# wxLua core engine sources (modules/wxlua/*.cpp + the bit library).
# wxlstate.cpp registers a `bit` module via luaopen_bit; bit.c provides
# it (it's a Lua-version-agnostic wrapper, not a 5.1/5.2-only polyfill
# as a stale comment elsewhere suggested - reads the same on 5.4 with
# native bitwise operators).
set(WXLUA_CORE_SRC
    ${WXLUA_MOD}/wxlua/wxlbind.cpp
    ${WXLUA_MOD}/wxlua/wxlcallb.cpp
    # wxlconsole.cpp not compiled - it's the wxLua debug-console window
    # (a wxFrame that shows the Lua print output and stack on errors).
    # The announcer doesn't use it (we have our own log_window inside
    # Announcer.wx.lua). Dropping the source also avoids needing to
    # vendor wxLua's art/ subtree just to satisfy the XPM #include
    # at line 29.
    ${WXLUA_MOD}/wxlua/wxllua.cpp
    ${WXLUA_MOD}/wxlua/wxlobject.cpp
    ${WXLUA_MOD}/wxlua/wxlstate.cpp
    ${WXLUA_MOD}/wxlua/wxlua_bind.cpp
    ${WXLUA_MOD}/wxlua/bit.c
)

# Bindings - match the wxWidgets feature trim in the parent
# CMakeLists.txt. We build only wxbase / wxcore / wxadv; binding
# files for wxaui / wxgl / wxhtml / wxmedia / wxnet / wxpropgrid /
# wxrichtext / wxstc / wxwebview / wxxml / wxxrc are vendored on
# disk for upstream-sync hygiene but not compiled.
set(WXLUA_BIND_SRC
    ${WXLUA_MOD}/wxbind/src/wxadv_bind.cpp
    ${WXLUA_MOD}/wxbind/src/wxadv_wxladv.cpp
    ${WXLUA_MOD}/wxbind/src/wxbase_base.cpp
    ${WXLUA_MOD}/wxbind/src/wxbase_bind.cpp
    ${WXLUA_MOD}/wxbind/src/wxbase_config.cpp
    ${WXLUA_MOD}/wxbind/src/wxbase_data.cpp
    ${WXLUA_MOD}/wxbind/src/wxbase_datetime.cpp
    ${WXLUA_MOD}/wxbind/src/wxbase_file.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_appframe.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_bind.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_clipdrag.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_controls.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_core.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_defsutils.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_dialogs.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_event.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_gdi.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_geometry.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_graphics.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_help.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_image.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_mdi.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_menutool.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_picker.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_print.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_sizer.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_windows.cpp
    ${WXLUA_MOD}/wxbind/src/wxcore_wxlcore.cpp
)

# Lua-module entry point - provides luaopen_wx(L) so `require "wx"`
# from Lua resolves into this DLL.
set(WXLUA_MODULE_SRC
    ${WXLUA_MOD}/luamodule/luamodule.cpp
)

add_library(wx MODULE
    ${WXLUA_CORE_SRC}
    ${WXLUA_BIND_SRC}
    ${WXLUA_MODULE_SRC}
)

# Lua C-module naming: `wx.dll` on Windows / `wx.so` on Linux. Drop
# the default `lib` prefix that CMake adds to MODULE targets on Linux.
set_target_properties(wx PROPERTIES
    PREFIX ""
    OUTPUT_NAME "wx"
)

# Linux RPATH: wx.so lives at lib/wx/, but the wxGTK shared libs
# (libwx_baseu-3.2.so, libwx_gtk3u_core-3.2.so, libwx_gtk3u_html-3.2.so,
# libwx_baseu_net-3.2.so) ship at install root. The global
# CMAKE_INSTALL_RPATH="$ORIGIN" (set at top-level CMakeLists for
# install-root .so consumers like adclib via parent RPATH) is not
# enough here - we need to look two levels up. Adding $ORIGIN/../..
# resolves to install root for wx.so.
#
# Windows DLLs use a different search mechanism (no RPATH); wx.dll
# finds wxbase32u_*.dll via the normal Windows DLL search since
# lua.exe (the process binary) sits at install root and Windows
# searches the loading executable's directory before %PATH%.
if(UNIX AND NOT APPLE)
    set_target_properties(wx PROPERTIES
        INSTALL_RPATH "$ORIGIN;$ORIGIN/../.."
    )
endif()

target_include_directories(wx PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${WXLUA_MOD}
    ${WXLUA_MOD}/wxbind/include
    ${WXLUA_MOD}/wxbind/setup   # wxluasetup.h - per-build feature toggles
)

# DLL export macros. Upstream wxLua's CMake builds wxLua as multiple
# separate DLLs (wxlua_core.dll, wxbindwxbase.dll, wxbindwxcore.dll,
# wxbindwxadv.dll, luamodule = wx.dll). Each gets one WXMAKINGDLL_*
# define so its public symbols are dllexport when building that DLL
# and dllimport when consumed from another DLL.
#
# We collapse all of them into a SINGLE wx.dll, so we must define
# every WXMAKINGDLL_* that any source file in our target needs - else
# the static-data-member definitions trip a "definition of dllimport'd
# class" compile error.
target_compile_definitions(wx PRIVATE
    WXMAKINGDLL_WXLUA           # modules/wxlua/*.cpp
    WXMAKINGDLL_BINDWXBASE      # modules/wxbind/src/wxbase_*.cpp
    WXMAKINGDLL_BINDWXCORE      # modules/wxbind/src/wxcore_*.cpp
    WXMAKINGDLL_BINDWXADV       # modules/wxbind/src/wxadv_*.cpp
    WXMAKINGDLL_LUAMODULE       # modules/luamodule/luamodule.cpp
    WXLUA_USE_wxLuaSocket=0     # we don't ship wxNet bindings
    # Gate wxLUA_DECLARE/IMPLEMENT_BIND_* in wxbinddefs.h - luamodule.cpp
    # uses WXLUA_DECLARE_BIND_ALL which would otherwise reference init
    # functions for bindings we don't compile (linker errors).
    wxLUA_USEBINDING_WXLUADEBUGGER=0
    wxLUA_USEBINDING_WXAUI=0
    wxLUA_USEBINDING_WXGL=0
    wxLUA_USEBINDING_WXHTML=0
    wxLUA_USEBINDING_WXMEDIA=0
    wxLUA_USEBINDING_WXNET=0
    wxLUA_USEBINDING_WXPROPGRID=0
    wxLUA_USEBINDING_WXRICHTEXT=0
    wxLUA_USEBINDING_WXSTC=0
    wxLUA_USEBINDING_WXWEBVIEW=0
    wxLUA_USEBINDING_WXXML=0
    wxLUA_USEBINDING_WXXRC=0
)

# Link against the vendored wxWidgets targets + our lua shared lib.
# wxWidgets targets (wxbase / wxcore / wxadv) are exported by the
# add_subdirectory(wxwidgets) call in the parent CMakeLists. They
# carry INTERFACE include directories so consumers get the right
# wx/setup.h automatically.
# wxhtml + wxnet are pulled in because wxLua's wxcore_bind.cpp references
# wxBestHelpController (from wxhtml) and wxbase_file.cpp references
# wxInternetFSHandler (from wxnet). Annoying but unavoidable without
# patching the generated bindings.
target_link_libraries(wx PRIVATE lua wxbase wxcore wxadv wxhtml wxnet)

# Install to lib/wx/wx.dll so the package.cpath entry `././lib/?/?.dll`
# in frontends/gui/Announcer.wx.lua resolves it via `require "wx"`.
install(TARGETS wx
    RUNTIME DESTINATION lib/wx
    LIBRARY DESTINATION lib/wx
)

# Bundle the wxWidgets shared libs that wx.dll imports. They live at
# install root (same as lua.dll + OpenSSL) so Windows' DLL search
# finds them when wx.dll loads. wxWidgets's own install rules were
# disabled (wxBUILD_INSTALL=OFF) so we install the build outputs by
# hand.
install(TARGETS wxbase wxcore wxadv wxhtml wxnet
    RUNTIME DESTINATION .
    LIBRARY DESTINATION .
)
