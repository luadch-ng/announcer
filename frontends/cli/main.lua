--[[

    Luadch Announcer - CLI frontend

    Cross-platform headless entry point. Bootstraps the core via
    dofile("core/init.lua") and drives net.loop() in a reconnect loop.

    No status-file writes (the GUI's file-IPC). The CLI relies on
    log.event output to log/logfile.txt for state visibility.

    Usage (from the repo root):

        lua frontends/cli/main.lua

    Requires the bundled lib/ binaries to be present for your
    platform. Win32: .dll ships with the repo. Linux/macOS .so/.dylib
    are Phase 2 (CMake + CI matrix).

        - written 2026-05-30 for luadch-ng/announcer Phase 0

]]--

dofile "core/init.lua"

local socket = require "socket"

log.event( "==============================================================================" )
log.event( "Starting announcer (CLI frontend)..." )

-- Reconnect loop. net.loop() returns false on fatal error (auth fail,
-- send error etc.); add a small sleep between retries so we don't
-- hot-spin on a persistent fatal. The connect-path failure inside
-- net.loop() already sleeps cfg.sleeptime via socket.sleep, but
-- post-login failures bail out immediately - guard at the outer
-- level too.
repeat
    local terminated = net.loop()
    if not terminated then
        socket.sleep( tonumber( cfg.sleeptime ) or 10 )
    end
until terminated

log.event( "Announcer terminated." )
os.exit()
