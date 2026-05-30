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

log.event( "==============================================================================" )
log.event( "Starting announcer (CLI frontend)..." )
repeat
until net.loop()
log.event( "Announcer terminated." )
os.exit()
