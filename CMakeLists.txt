cmake_minimum_required(VERSION 3.20)

# -----------------------------------------------------------------------------
# luadch-ng/announcer - Phase 2 CMake build
#
# Adopts the parent luadch-ng/luadch repo's CMake pattern (the "big lever"
# from CLAUDE.md §4): vendor the C sources for lua / adclib / luasec /
# luasocket from the hub + lfs from upstream lunarmodules/luafilesystem,
# build everything in-tree, install to ${CMAKE_INSTALL_PREFIX} with the
# operator-runnable layout.
#
# Three-step build (same recipe as the hub):
#
#     cmake -B build -DCMAKE_BUILD_TYPE=Release [-DOPENSSL_ROOT_DIR=...]
#     cmake --build build -j
#     cmake --install build
#
# Output lands in ${CMAKE_BINARY_DIR}/install/announcer/ by default.
# Run via:  lua.exe frontends/cli/main.lua   (CLI, cross-platform target)
#           Announcer.exe (Win-only GUI, Phase 3)
# -----------------------------------------------------------------------------

# Default to Release for single-config generators (MinGW Makefiles, Make,
# Ninja). Without this we end up with debug-ish binaries 2-3x the size.
get_property(IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT IS_MULTI_CONFIG AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

project(announcer
    VERSION 1.0.0
    DESCRIPTION "luadch-ng release announcer - ADC OSNR scene-release announcer"
    LANGUAGES C CXX
)

# Strip symbols on Release builds with GCC/Clang link.
if(NOT MSVC AND CMAKE_BUILD_TYPE STREQUAL "Release")
    add_link_options(-s)
endif()

# Default install layout: build/install/announcer/ keeps the source tree
# clean. Override with -DCMAKE_INSTALL_PREFIX=... if needed.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install/announcer"
        CACHE PATH "announcer install root" FORCE)
endif()

# RPATH: on ELF platforms lua.exe + lua.dll + plugins all live in the
# install root and lib/ subdirs. $ORIGIN lets the binary find liblua.so as
# a sibling at runtime; plugins under lib/<name>/<name>.so resolve via
# package.cpath.
if(UNIX AND NOT APPLE)
    set(CMAKE_INSTALL_RPATH "$ORIGIN")
    set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
endif()

# PIC for everything (required for shared libs)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# -----------------------------------------------------------------------------
# OpenSSL: used by luasec. find_package finds the system install on Linux;
# on Windows pass -DOPENSSL_ROOT_DIR=C:/OpenSSL. Pinned to 3.0+ to match
# the hub's policy (1.1.1 EOL'd 2023-09-11).
# -----------------------------------------------------------------------------
find_package(OpenSSL 3.0 REQUIRED)
message(STATUS "announcer: OpenSSL ${OPENSSL_VERSION} at ${OPENSSL_INCLUDE_DIR}")

# -----------------------------------------------------------------------------
# C modules (each builds its plugin .so / .dll into lib/<name>/)
# -----------------------------------------------------------------------------
add_subdirectory(lua/src)
add_subdirectory(adclib)
add_subdirectory(luasocket)
add_subdirectory(luasec)
add_subdirectory(lfs)

# -----------------------------------------------------------------------------
# Optional: wxWidgets 3.2.10 (vendored as git submodule under wxwidgets/)
# for the announcer GUI. Phase 3 Tier 2a (#17).
#
# Opt-in via -DBUILD_GUI=ON. Default OFF because:
# - The CLI binary + worker process don't link wxWidgets at all
# - Building wxWidgets adds ~5 min to the CMake build (it has its own
#   ~1500 source files)
# - CI's CLI smoke chain shouldn't pay that cost on every push
#
# When enabled: builds the minimal feature set Announcer.wx.lua needs -
# wxbase (foundation), wxcore (controls + frame + dialog), wxadv
# (TaskBarIcon). Skip everything heavy we don't use (webview, aui,
# ribbon, propgrid, stc, media, html, richtext, xrc, gl, net, qa).
#
# wxLua (Tier 2b) will link against the wxbase + wxcore + wxadv targets
# exported here.
# -----------------------------------------------------------------------------
option(BUILD_GUI "Build the wxLua GUI runtime (vendored wxWidgets + wxLua)" OFF)

if(BUILD_GUI)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/wxwidgets/CMakeLists.txt")
        message(FATAL_ERROR
            "wxwidgets submodule not initialised. Run:\n"
            "  git submodule update --init --recursive")
    endif()

    # Build flags: shared libs (Phase 2 model = dynamic where it makes
    # sense; static wxWidgets would be ~50 MB per target and unique per
    # build flag set).
    set(wxBUILD_SHARED      ON  CACHE BOOL "Build wxWidgets as shared libraries")
    set(wxBUILD_MONOLITHIC  OFF CACHE BOOL "One wx DLL or split per-component")
    set(wxBUILD_PRECOMP     OFF CACHE BOOL "Skip PCH - fragile across compilers")
    set(wxBUILD_SAMPLES     OFF CACHE STRING "")
    set(wxBUILD_DEMOS       OFF CACHE BOOL "")
    set(wxBUILD_TESTS       OFF CACHE STRING "")
    set(wxBUILD_BENCHMARKS  OFF CACHE BOOL "")
    set(wxBUILD_INSTALL     OFF CACHE BOOL "Don't install wxWidgets headers/libs into our tree")
    # Feature trim - things the announcer's Announcer.wx.lua never touches.
    set(wxUSE_WEBVIEW       OFF CACHE BOOL "")
    set(wxUSE_MEDIACTRL     OFF CACHE BOOL "")
    set(wxUSE_RIBBON        OFF CACHE BOOL "")
    set(wxUSE_PROPGRID      OFF CACHE BOOL "")
    set(wxUSE_STC           OFF CACHE BOOL "")
    set(wxUSE_AUI           OFF CACHE BOOL "")
    set(wxUSE_XRC           OFF CACHE BOOL "")
    set(wxUSE_OPENGL        OFF CACHE BOOL "")
    # wxLua's pre-generated wxcore bindings reference wxBestHelpController
    # (which falls through to wxHtmlHelpController on platforms without
    # WinHelp) + wxWindow::GetHelpText() - both require wxUSE_HTML +
    # wxUSE_HELP. Keeping HTML off triggers undeclared-symbol errors in
    # the binding source set we can't easily patch around.
    set(wxUSE_HTML          ON  CACHE BOOL "")
    set(wxUSE_HELP          ON  CACHE BOOL "")
    set(wxUSE_WXHTML_HELP   ON  CACHE BOOL "")
    set(wxUSE_RICHTEXT      OFF CACHE BOOL "")
    set(wxUSE_QA            OFF CACHE BOOL "")
    # wxNet has to stay ON: wxLua's wxbase_file.cpp binding unconditionally
    # references wxInternetFSHandler which lives in wxNet. The announcer
    # itself never touches sockets through wxLua (file-poll IPC via lfs),
    # but the binding source references the type and we can't easily
    # exclude wxbase_file.cpp.
    set(wxUSE_NET           ON  CACHE BOOL "")
    # wxAdv must stay ON: wxTaskBarIcon lives there.
    set(wxUSE_ADV           ON  CACHE BOOL "")

    add_subdirectory(wxwidgets EXCLUDE_FROM_ALL)

    # wxLua C-module on top: builds lib/wx/wx.dll against the wxWidgets
    # targets above + our existing `lua` target. Phase 3 Tier 2b (#17).
    add_subdirectory(wxlua)
endif()

# -----------------------------------------------------------------------------
# Pure-Lua bundled helpers (flat copies; no compilation)
# -----------------------------------------------------------------------------
install(FILES basexx/basexx.lua            DESTINATION lib/basexx)
install(FILES slnunicode/unicode.lua       DESTINATION lib/unicode)

# -----------------------------------------------------------------------------
# Runtime trees: pure-Lua + GUI assets, copied flat into the install root.
# -----------------------------------------------------------------------------
install(DIRECTORY core/        DESTINATION core)
# cfg/: exclude id.lua - it is the bot's tiger-hash PID/CID secret,
# regenerated per-install by core/adc.lua on first run. Local dev
# trees may contain one from smoke-testing; never install it.
install(DIRECTORY cfg/         DESTINATION cfg PATTERN "id.lua" EXCLUDE)
install(DIRECTORY certs/       DESTINATION certs)
# Unix-only: ship the CLI wrapper script (announcer.sh) at the install
# root so users can `./announcer.sh` instead of `./lua
# frontends/cli/main.lua`. EXCLUDE'd from the recursive frontends/
# copy below to avoid a duplicate at `frontends/cli/announcer.sh`;
# install(PROGRAMS) here preserves the executable bit (install(FILES)
# would strip it on some hosts; install(DIRECTORY) USE_SOURCE_PERMISSIONS
# default is reliable on Linux but install(PROGRAMS) is the documented
# CMake idiom). #53.
if(UNIX)
    install(PROGRAMS frontends/cli/announcer.sh DESTINATION .)
    install(DIRECTORY frontends/   DESTINATION frontends
        PATTERN "announcer.sh" EXCLUDE)
else()
    install(DIRECTORY frontends/   DESTINATION frontends)
endif()

# GUI resources (PNG icons + GPL badge). The lib/lfs_wx Lua-5.1-ABI lfs
# duplicate and the lib/ressources/res{1,2}.dll PE-icon containers were
# removed in Phase 3 Tier 1 (#15); the GUI now loads icons from PNG and
# the Tier-2 runtime bundle ships its own lfs.dll for the GUI process.
install(DIRECTORY lib/ressources/ DESTINATION lib/ressources)

# Empty log dir (the announcer writes log files here at runtime)
install(DIRECTORY DESTINATION log)

# -----------------------------------------------------------------------------
# Windows: bundle OpenSSL DLLs at install root so the announcer can load
# them without OPENSSL_ROOT_DIR being on PATH at runtime. Mirror the hub's
# search both flat (WinLibs/ShiningLight) and standard (msys2 UCRT64) layouts.
# -----------------------------------------------------------------------------
if(WIN32)
    if(NOT DEFINED OPENSSL_ROOT_DIR)
        message(FATAL_ERROR
            "OPENSSL_ROOT_DIR must be set on Windows so we can install "
            "libssl-3-x64.dll and libcrypto-3-x64.dll alongside lua.exe. "
            "Pass -DOPENSSL_ROOT_DIR=C:/OpenSSL on the cmake command line."
        )
    endif()
    foreach(_dll libssl-3-x64.dll libcrypto-3-x64.dll)
        string(MAKE_C_IDENTIFIER "${_dll}" _dll_var)
        find_file(_openssl_${_dll_var}
            NAMES ${_dll}
            HINTS "${OPENSSL_ROOT_DIR}" "${OPENSSL_ROOT_DIR}/bin"
            NO_DEFAULT_PATH
            REQUIRED
        )
        install(FILES "${_openssl_${_dll_var}}" DESTINATION .)
        unset(_openssl_${_dll_var} CACHE)
    endforeach()

    # When BUILD_GUI=ON the wxLua shared module (lib/wx/wx.dll) and the
    # wxWidgets shared libs pull in the MinGW C/C++ runtime. Bundle those
    # too so the install tree is self-sufficient (no PATH-leak from the
    # builder's MinGW installation).
    if(BUILD_GUI)
        get_filename_component(_mingw_bindir "${CMAKE_CXX_COMPILER}" DIRECTORY)
        foreach(_rt libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll)
            find_file(_mingw_rt_${_rt}
                NAMES ${_rt}
                HINTS "${_mingw_bindir}"
                NO_DEFAULT_PATH
            )
            if(_mingw_rt_${_rt})
                install(FILES "${_mingw_rt_${_rt}}" DESTINATION .)
            endif()
            unset(_mingw_rt_${_rt} CACHE)
        endforeach()
    endif()
endif()

# -----------------------------------------------------------------------------
# Windows-only GUI launcher executable (Announcer.exe). Thin C wrapper around
# `lua + frontends/gui/Announcer.wx.lua` so the user can double-click an .exe
# in the install root instead of typing `lua.exe frontends/gui/Announcer.wx.lua`.
# Built only when BUILD_GUI=ON AND the host is Windows. The `WIN32` keyword on
# add_executable produces a GUI-subsystem binary (no console window flash on
# launch). Links against the embedded Lua 5.4 shared lib defined in
# lua/src/CMakeLists.txt.
# -----------------------------------------------------------------------------
if(BUILD_GUI AND WIN32)
    add_executable(announcer_gui_launcher WIN32
        frontends/gui/launcher.c
    )
    set_target_properties(announcer_gui_launcher PROPERTIES
        OUTPUT_NAME "Announcer"
    )
    target_link_libraries(announcer_gui_launcher PRIVATE lua)
    install(TARGETS announcer_gui_launcher RUNTIME DESTINATION .)
endif()
