# Build LuaFileSystem (lfs) as a Lua C module.
#
# Source: vendored from upstream `lunarmodules/luafilesystem` v1.9.0
# (https://github.com/lunarmodules/luafilesystem). The hub does NOT
# bundle lfs (it does not need it); the announcer needs lfs.dir and
# lfs.attributes for the release-dir scan in core/announce.lua and
# the log-size cap in core/log.lua.
#
# Output:
#   lib/lfs/lfs.so / .dll (C module)

set(LFS_SRC ${CMAKE_CURRENT_SOURCE_DIR}/src)

add_library(lfs MODULE ${LFS_SRC}/lfs.c)

target_include_directories(lfs PRIVATE ${LFS_SRC})
target_link_libraries(lfs PRIVATE lua)

# Lua C modules conventionally have no "lib" prefix on Linux either -
# require("lfs") looks for lfs.so directly, not liblfs.so.
set_target_properties(lfs PROPERTIES PREFIX "")

# Force .dll suffix on Windows so the file lands at lfs.dll.
if(WIN32)
    set_target_properties(lfs PROPERTIES SUFFIX ".dll")
endif()

install(TARGETS lfs LIBRARY DESTINATION lib/lfs
                    RUNTIME DESTINATION lib/lfs)

# Ship the upstream LICENSE alongside.
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/LICENSE DESTINATION lib/lfs)
