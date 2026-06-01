--[[

    Luadch Announcer - CLI frontend

    Cross-platform headless entry point. Bootstraps the core via
    dofile("core/init.lua") and drives net.loop() in a reconnect loop.

    No status-file writes (the GUI's file-IPC). The CLI relies on
    log.event output to log/logfile.txt for state visibility.

    Usage:

        # From any directory, given an absolute path to main.lua:
        /path/to/install/lua /path/to/install/frontends/cli/main.lua

        # From the install root, with a relative path:
        cd /path/to/install && ./lua frontends/cli/main.lua

    The relative-path form requires CWD = install root - the launcher
    has to be able to find main.lua to invoke it in the first place.
    The absolute-path form works from anywhere; PR-D's bootstrap
    anchors require()/dofile() on the install root regardless of CWD.

    Requires the bundled lib/ binaries to be present for your
    platform.

        - written 2026-05-30 for luadch-ng/announcer Phase 0
        - PR-D path-anchoring 2026-06-01

]]--

-- Anchor the runtime on the install root before any CWD-relative
-- dofile/require runs. See frontends/bootstrap.lua for the full
-- rationale. The bootstrap file itself has to be loaded via an
-- absolute path derived from arg[0] because at this exact moment
-- CWD is whatever the launcher set, not necessarily the install dir.
do
    local script = arg and arg[ 0 ] or ""
    local install_dir = script:match( "^(.+)[/\\]frontends[/\\][^/\\]+[/\\][^/\\]+$" ) or "."
    if install_dir:find( "[;?]" ) then
        io.stderr:write( "main: refusing to anchor on install_dir with `;` or `?`: " .. install_dir .. "\n" )
        os.exit( 1 )
    end
    local sep = package.config:sub( 1, 1 )
    dofile( install_dir .. sep .. "frontends" .. sep .. "bootstrap.lua" )
end

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
