--[[

    Luadch Announcer - core bootstrap

    Loads all modules (cfg + core) in dependency order. Does NOT start
    the announcer loop - the active frontend (CLI or GUI) calls
    net.loop() after this returns. This is the change vs upstream
    luadch/announcer_*, where net.lua auto-ran the loop at module
    load.

    Bundled deps: basexx, luasec, luasocket. Win-only adclib + lfs
    binaries ship under lib/. Cross-platform Linux/macOS binaries are
    Phase 2 (CMake + CI matrix) - the filetype detect below is the
    seed for that.

        - written by blastbeat, 20141008
        - mod for cross-platform filetype detect from announcer_bot
        - consolidated 2026-05-30 for luadch-ng/announcer

]]--

local filetype = ( os.getenv "COMSPEC" and os.getenv "WINDIR" and ".dll" ) or ".so"

-- The "././lib/..." entries below are CWD-relative; the active frontend
-- (frontends/cli/main.lua, frontends/gui/spawned_worker.lua) chdirs to
-- the install root before reaching this file so they always resolve to
-- the bundled binaries. Keeping the relative form means a stripped-down
-- `lua core/init.lua` from the install root still bootstraps even when
-- the frontend layer is bypassed.
package.path = package.path .. ";"
    .. "././core/?.lua;"
    .. "././lib/?/?.lua;"
    .. "././lib/luasocket/lua/?.lua;"
    .. "././lib/luasec/lua/?.lua;"

package.cpath = package.cpath .. ";"
    .. "././lib/?/?" .. filetype .. ";"
    .. "././lib/luasocket/?/?" .. filetype .. ";"
    .. "././lib/luasec/?/?" .. filetype .. ";"
    .. "././lib/lfs/?" .. filetype .. ";"

dofile "core/const.lua"
dofile "core/events.lua"
dofile "cfg/cfg.lua"
dofile "cfg/sslparams.lua"
dofile "cfg/hub.lua"
dofile "core/log.lua"
dofile "core/adc.lua"
dofile "core/announce.lua"
dofile "cfg/rules.lua"
dofile "core/net.lua"
