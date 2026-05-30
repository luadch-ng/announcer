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

        - written 2026-05-30 for luadch-ng/announcer Phase 0

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
        list[ i ]( ... )
    end
end

events.clear = function( name )
    if name then
        handlers[ name ] = nil
    else
        handlers = { }
    end
end
