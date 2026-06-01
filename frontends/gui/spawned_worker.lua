--[[

    Luadch-NG Announcer - GUI spawned-worker entry point

    The wxLua GUI's "Connect" button executes this script via the
    bundled lua.exe (`wx.wxExecute("lua.exe frontends/gui/spawned_worker.lua")`).

    This is the file-IPC bridge between the announcer's in-process
    events dispatch (Phase 0 events.lua) and the GUI's status-poll
    UI updater (which reads core/status.lua at ~1Hz to colour the
    state widgets). On every `events.emit("status", key, value)`
    from core/net.lua we serialise the table to core/status.lua so
    the GUI's reader keeps seeing connection-state updates as
    before. The upstream luadch/announcer_client did this inline
    in core/net.lua via `set_status(file, key, value)`; Phase 0
    pulled it out via events.lua + this file is the matching
    sink.

    Then drive the reconnect loop the same way frontends/cli/main.lua
    does (incl. the explicit cfg.sleeptime backoff so post-login
    fatals don't hot-spin).

    Replaces the upstream `lib/ressources/client.dll` wxluafrozen
    Lua-5.1 bundle. That .dll is now orphaned and is deleted in
    this PR.

        - written 2026-06-01 for luadch-ng/announcer Phase 1 PR-C
        - PR-D path-anchoring 2026-06-01

]]--

-- Anchor the runtime on the install root before any CWD-relative
-- dofile/require runs. The wxLua GUI spawns this worker via
-- wx.wxExecute, which inherits the GUI's CWD - in current GUI builds
-- that is the install root by construction. See frontends/bootstrap.lua
-- for the rationale.
do
    local script = arg and arg[ 0 ] or ""
    local install_dir = script:match( "^(.+)[/\\]frontends[/\\][^/\\]+[/\\][^/\\]+$" ) or "."
    if install_dir:find( "[;?]" ) then
        io.stderr:write( "spawned_worker: refusing to anchor on install_dir with `;` or `?`: " .. install_dir .. "\n" )
        os.exit( 1 )
    end
    local sep = package.config:sub( 1, 1 )
    dofile( install_dir .. sep .. "frontends" .. sep .. "bootstrap.lua" )
end

dofile "core/init.lua"

local util = require( CORE_PATH .. "util" )
local socket = require "socket"

local status_file = CORE_PATH .. "status.lua"

--// GUI file-IPC bridge: turn every "status" event into a
--// status.lua serialisation. The handler runs inside events.emit's
--// pcall wrap (Phase 1 PR-B) so any I/O hiccup is logged + chain
--// continues; the GUI poller tolerates an occasional stale read.
events.on( "status", function( key, value )
    --// Ensure the file exists (first emit on a fresh install hits
    --// this path; subsequent loops have the file ready).
    local fh = io.open( status_file, "a+" )
    if fh then fh:close() end
    local tbl = util.loadtable( status_file ) or { }
    tbl[ key ] = value
    util.savetable( tbl, "status", status_file )
end )

log.event( "==============================================================================" )
log.event( "Starting announcer (GUI spawned worker)..." )

--// Reconnect loop. Mirrors frontends/cli/main.lua: net.loop()
--// returns false on fatal error; sleep cfg.sleeptime between
--// retries so a persistent fatal doesn't hot-spin.
repeat
    local terminated = net.loop()
    if not terminated then
        socket.sleep( ( tonumber( cfg.sleeptime ) or 10 ) )
    end
until terminated

log.event( "Announcer terminated." )
os.exit()
