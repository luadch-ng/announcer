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
install(DIRECTORY frontends/   DESTINATION frontends)

# GUI's separate wxLua lfs build (still 5.1 - Phase 3 GUI rework replaces)
install(DIRECTORY lib/lfs_wx/  DESTINATION lib/lfs_wx)

# GUI resource bundles (.dll + .png; Phase 2 PR-E will convert .dll -> PNG)
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
endif()
