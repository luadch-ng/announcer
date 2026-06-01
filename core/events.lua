--[[

    Luadch Announcer - event dispatch

    Replaces the file-based IPC (core/status.lua via set_status writes
    in upstream announcer_client/core/net.lua) with an in-process
    event dispatch.

    Events the core emits:

        events.emit( "status", key, value )
            Hub-connection state machine updates (hubconnect /
            hubhandshake / hubkeyp / support / hubsupport / hubosnr /
            hubsid / hubinf / owninf / passwd / hubsalt / hublogin /
            cipher). Mirrors the keys of the upstream core/status.lua.

        events.emit( "announce", release )
            Fired for each release successfully sent to the hub.

        events.emit( "round", count )
            Fired after each announce round with the count of new
            releases in that round.

        events.emit( "fatal", err )
            Connection or login failed; the loop will return false
            and the frontend decides whether to retry.

    Frontends register handlers via events.on("name", handler). Multiple
    handlers per event are allowed and called in registration order.
    Without a handler, an event is a no-op.

    Handler dispatch is pcall-guarded (Phase 1 PR-B): a handler that
    errors is logged (via log.event if available, else stderr) and
    the remaining handlers in the chain still run. One buggy frontend
    handler cannot kill the chain.

        - written 2026-05-30 for luadch-ng/announcer Phase 0
        - pcall safety wrap added 2026-06-01 (Phase 1 PR-B)

]]--

local handlers = { }

events = { }

events.on = function( name, handler )
    handlers[ name ] = handlers[ name ] or { }
    table.insert( handlers[ name ], handler )
end

events.emit = function( name, ... )
    local list = handlers[ name ]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall( list[ i ], ... )
        if not ok then
            local msg = "events.emit('" .. tostring( name ) .. "'): handler #" .. i .. " error: " .. tostring( err )
            -- log.event is loaded after events.lua in init.lua but
            -- events.emit is only called at runtime (from net.lua's
            -- state machine), by which point log is up. Stderr is
            -- the fallback for edge cases (e.g. events.emit fired
            -- during early bootstrap before log.lua finished).
            if log and log.event then
                log.event( msg )
            else
                io.stderr:write( msg .. "\n" )
            end
        end
    end
end

events.clear = function( name )
    if name then
        handlers[ name ] = nil
    else
        handlers = { }
    end
end
