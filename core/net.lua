--[[

    - written by blastbeat, 20141008
        - rewritten by pulsar for the Luadch Announcer Client
        - net.loop() auto-run removed (frontend invokes); set_status
          file-IPC replaced with events.emit( "status", key, value )
          (see core/events.lua) - 2026-05-30 for luadch-ng/announcer

]]--


--// imports
local socket = require( "socket" )
local ssl = require( "ssl" )
local basexx = require( "basexx" )

--// assert sslparams
local sslctx, err = ssl.newcontext( sslparams )
assert( sslctx, "Fail: " .. tostring( err ) )


--// botname
local bottag = "Announcer"

local run = true
net = { }

net.loop = function()
    --// #36: cfg.botshare flows into a multiplication and then concatenated
    --// as the BINF SS field. A nil / string value would crash the arithmetic
    --// (nil) or emit a non-integer field rejected by ADC's `^-?\d+$` parser
    --// (string). tonumber-wrap so an operator typo degrades to a 0 claim
    --// instead of a hard fail or wire-protocol violation.
    local bshare = ( tonumber( cfg.botshare ) or 0 ) * 1024 * 1024
    local client, err = socket.tcp()
    assert( client, "Fail: " .. tostring( err ) )
    log.event( "Try to connect to hub '" .. hub.name .. "' via " .. hub.nick .. "@" .. hub.addr .. ":" .. hub.port .. " with timeout " .. cfg.sockettimeout .. " seconds..." )
    client:settimeout( cfg.sockettimeout )
    repeat
        local succ, err = client:connect( hub.addr, hub.port )
        run = true
        if err then
            log.event( "Fail: " .. tostring( err ) )
            -- Phase 1 fix: was `tonumber( cfg.sleeptime ) or 10 .. " seconds..."`
            -- which parses as `tonumber(x) or (10 .. " seconds...")` because
            -- `..` binds tighter than `or`. When cfg.sleeptime was nil the
            -- arg became the literal string "10 seconds..." and socket.sleep
            -- would error. Now parenthesised at all sites.
            local _sleep = ( tonumber( cfg.sleeptime ) or 10 )
            log.event( "Try to reconnect in " .. _sleep .. " seconds..." )
            events.emit( "status", "hubconnect", "Fail: " .. tostring( err ) .. " | Try to reconnect in " .. _sleep .. " seconds..." )
            socket.sleep( _sleep )
            run = false
        end
    until succ
    log.event( "Connected. Try a SSL handshake..." )
    if run then events.emit( "status", "hubconnect", "Connected. Try a SSL handshake..." ) end
    local client, err = ssl.wrap( client, sslctx )
    assert( client, "Fail: " .. tostring( err ) )
    client:settimeout( cfg.sockettimeout )
    local succ, err = client:dohandshake()
    if err then
        log.event( "Fail: " .. tostring( err ) )
        events.emit( "status", "hubhandshake", "Fail: " .. tostring( err ) )
        run = false
        return false
    end
    local cert = client:getpeercertificate()
    log.event( "Generate keyprint..." )
    if run then events.emit( "status", "hubhandshake", "Generate keyprint..." ) end
    local fingerprint = basexx.to_base32( basexx.from_hex( cert:digest( "sha256" ) ) ):gsub( "=", "" )
    if hub.keyp ~= "" then
        if fingerprint ~= hub.keyp then
            log.event( "Fail: Keyprint mismatch" )
            events.emit( "status", "hubkeyp", "Fail: Keyprint mismatch" )
            run = false
            client:close()
            return true
        else
            log.event( "Connection with Keyprint verification..." )
            events.emit( "status", "hubkeyp", "Connection with Keyprint verification..." )
        end
    else
        log.event( "Connection without Keyprint verification..." )
        events.emit( "status", "hubkeyp", "Connection without Keyprint verification..." )
    end
    log.event( "Connection established. Try now to login..." )
    if run then events.emit( "status", "hubkeyp", "Connection established. Try now to login..." ) end
    log.event( "Sending support..." )
    local succ, err = client:send( "HSUP ADBASE ADTIGR ADOSNR ADKEYP ADADCS ADADC0\n" )
    if err then
        log.event( "Fail: " .. tostring( err ) )
        events.emit( "status", "support", "Fail: " .. tostring( err ) )
        run = false
        return false
    end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "CLIENT 2 HUB: HSUP ADBASE ADTIGR ADOSNR ADKEYP ADADCS ADADC0" ) --------------------- DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    log.event( "Waiting for hub support..." )
    if run then events.emit( "status", "support", "Waiting for hub support..." ) end
    local buf, err = client:receive( "*l" )
    if err then
        log.event( "Fail: " .. tostring( err ) )
        events.emit( "status", "hubsupport", "Fail: " .. tostring( err ) )
        run = false
        return false
    end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "HUB 2 CLIENT: " .. tostring( buf ) ) ------------------------------------------------ DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    log.event( "Check for OSNR support..." )
    if run then events.emit( "status", "hubsupport", "Check for OSNR support..." ) end
    if not buf:find( "ADOSNR" ) then
        log.event( "Fail: No OSNR support, closing..." )
        events.emit( "status", "hubosnr", "Fail: No OSNR support, closing..." )
        run = false
        client:close()
        return true
    end
    log.event( "Hub has OSNR support, waiting for SID..." )
    if run then events.emit( "status", "hubosnr", "Hub has OSNR support, waiting for SID..." ) end
    local buf, err = client:receive( "*l" )
    if err then
        log.event( "Fail: " .. tostring( err ) )
        events.emit( "status", "hubsid", "Fail: " .. tostring( err ) )
        return false
    end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "HUB 2 CLIENT: " .. tostring( buf ) ) ------------------------------------------------ DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    local sid
    if buf:find( "ISID" ) then
        sid = buf:sub( 6, 9 )
        log.event( "Provided SID: " .. sid )
        if run then events.emit( "status", "hubsid", "Provided SID: " .. sid ) end
    else
        log.event( "No SID provided, closing..." )
        client:close()
        run = false
        return true
    end
    --// client BINF login string
    --// #25: had a duplicate " I40.0.0.0" field below SU that was a
    --// no-op against luadch's first-wins parser but syntactically
    --// malformed per ADC (one named-param appearance per frame).
    --// #26: US (max upload speed in bytes/sec) added so hub-side
    --// stats / top-uploader / freshstuff scripts count the announcer.
    --// Default 0 = no claim; operators can raise via cfg.botupload.
    local CLIENT_BINF = "BINF " ..
                        sid ..
                        " NI" .. adclib.escape( tostring( hub.nick ) ) ..
                        " DE" .. adclib.escape( tostring( cfg.botdesc ) ) ..
                        " AP" .. adclib.escape( bottag ) ..
                        " VE" .. adclib.escape( _VERSION ) ..
                        " PD" .. id.pid ..
                        " ID" .. id.cid ..
                        " SS" .. bshare ..
                        --// #36: same defensive tonumber treatment as US (#26)
                        --// + bshare above; cfg.botslots as a non-integer
                        --// would emit e.g. "SLabc" / "SL5" (string-typed)
                        --// that luadch's ADC parser rejects with a kick.
                        " SL" .. ( tonumber( cfg.botslots ) or 0 ) ..
                        " US" .. ( tonumber( cfg.botupload ) or 0 ) ..
                        " HN" .. "0" ..
                        " HR" .. "0" ..
                        " HO" .. "0" ..
                        " AW" .. "2" ..
                        " SU" .. "OSNR,ADC0,ADCS,TCP4,UDP4" ..
                        " I40.0.0.0\n"

    --// client BINF keeping alive string
    local CLIENT_KEEPING_ALIVE = "BINF " ..
                                 sid ..
                                 " AP" .. adclib.escape( bottag ) ..
                                 " VE" .. adclib.escape( _VERSION ) ..
                                 "\n"

    log.event( "Waiting for hub INF..." )
    local buf, err = client:receive( "*l" )
    if err then
        log.event( "Fail: " .. tostring( err ) )
        events.emit( "status", "hubinf", "Fail: " .. tostring( err ) )
        run = false
        return false
    end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "HUB 2 CLIENT: " .. tostring( buf ) ) ------------------------------------------------ DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    if not buf:find( "IINF" ) then
        log.event( "No INF provided, closing..." )
        client:close()
        run = false
        return true
    else
        log.event( "Hub INF provided, try to send own INF..." )
        if run then events.emit( "status", "hubinf", "Hub INF provided, try to send own INF..." ) end
        local succ, err = client:send( CLIENT_BINF )
        if err then
            log.event( "Fail: " .. tostring( err ) )
            events.emit( "status", "owninf", "Fail: " .. tostring( err ) )
            run = false
            return false
        end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "CLIENT 2 HUB: " .. tostring( CLIENT_BINF ) ) ---------------------------------------- DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    end
    log.event( "Own INF sended, waiting for password request..." )
    if run then events.emit( "status", "owninf", "Own INF sended, waiting for password request..." ) end
    local buf, err = client:receive( "*l" )
    if err then
        log.event( "Fail: " .. tostring( err ) )
        events.emit( "status", "passwd", "Fail: " .. tostring( err ) )
        run = false
        return false
    end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "HUB 2 CLIENT: " .. tostring( buf ) ) ------------------------------------------------ DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    local salt
    if not buf:find( "GPA" ) then
        log.event( "No password request, closing..." )
        events.emit( "status", "passwd", "Fail: No password request, closing..." )
        client:close()
        run = false
        return true
    else
        salt = buf:sub( 6, -1 ):match( "^([A-Z2-7]+)" )
    end
    log.event( "Salt provided, try to send password..." )
    if run then events.emit( "status", "passwd", "Salt provided, try to send password..." ) end
    local pas = adclib.hashpas( hub.pass, salt )
    local succ, err = client:send( "HPAS " .. pas .. "\n" )
    if err then
        log.event( "Fail: " .. tostring( err ) )
        events.emit( "status", "hubsalt", "Fail: " .. tostring( err ) )
        client:close()
        run = false
        return false
    end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "CLIENT 2 HUB: HPAS " .. pas ) ------------------------------------------------------- DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    log.event( "Waiting for login..." )
    if run then events.emit( "status", "hubsalt", "Waiting for login..." ) end
    local buf, err = client:receive( "*l" )
    if err then
        log.event( "Fail: " .. tostring( err ) )
        --events.emit( "status", "hublogin", "Fail: " .. tostring( err ) )
        return false
    end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "HUB 2 CLIENT: " .. tostring( buf ) ) ------------------------------------------------ DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    if not buf:find( "BINF" ) then
        log.event( "Login failed. Last hub message: " .. buf )
        events.emit( "status", "hublogin", "Fail: Login failed. Last hub message: " .. buf )
        client:close()
        run = false
        return true
    end
    local hubcount = "HR1"
    -- Phase 1 fix: was `buf:find( "CT4" or "CT8" or "CT16" or "OP1" )`
    -- which short-circuits to `buf:find("CT4")` (the `or` returns the
    -- first truthy string). The CT8/CT16/OP1 branches were dead.
    if buf:find( "CT4" ) or buf:find( "CT8" ) or buf:find( "CT16" ) or buf:find( "OP1" ) then
        hubcount = "HO1"
    end
    local succ, err = client:send( "BINF " .. sid .. " " .. hubcount .. "\n" )
    if err then
        log.event( "Fail: " .. tostring( err ) )
        client:close()
        return false
    end
    -------------------------------------------------------------------------------------------------------
    log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    log.event( "CLIENT 2 HUB: BINF " .. sid .. " " .. hubcount ) ------------------------------------ DEBUG
    --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
    -------------------------------------------------------------------------------------------------------
    log.event( "Login complete." )
    if run then events.emit( "status", "hublogin", "Login complete." ) end
    --// sslinfo
    local sslinfo, err = client:info()
    if sslinfo then
        local cipher = sslinfo[ "cipher" ]
        if cipher then
            log.event( "=============================================" )
            log.event( "   Cipher: " .. cipher )
            log.event( "=============================================" )
            events.emit( "status", "cipher", cipher )
        end
    end
    log.event( "Waiting " .. ( tonumber( cfg.sleeptime ) or 10 ) .. " seconds before starting the announcer..." )
    socket.sleep( tonumber( cfg.sleeptime ) or 10 )
    while true do
        local found = announce.update()
        local c = 0
        log.event( "Start announcing..." )
        for release, cfg in pairs( found ) do
            local command = cfg.command
            local alibicheck = cfg.alibicheck
            local alibinick = cfg.alibinick
            if alibicheck then
                command = command .. " " .. alibinick
            end
            local category = cfg.category
            if ( type( category ) ~= "string" ) or ( type( command ) ~= "string" ) then
                log.event( "Your rules.lua is broken. No valid category/command given for release '" .. release .. "' given." )
            else
                command = command .. " " .. category .. " " .. release
                command = adclib.escape( command )
                local succ, err = client:send( "BMSG " .. sid .. " " .. command .. "\n" )
                if err then
                    log.event( "Fail: " .. tostring( err ) )
                    return false
                else
                    log.release( release )
                    --log.event( "Announced '" .. release .. "'.")
                    c = c + 1
                end
            end
        end
        log.event( "...finished. Announced " .. c .. " new releases." )
        socket.sleep( tonumber( cfg.announceinterval ) or 5 * 60 )
        local succ, err = client:send( CLIENT_KEEPING_ALIVE ) -- send some keeping alive ping
        if err then log.event( "Fail: " .. tostring( err ) ) return false end
        -------------------------------------------------------------------------------------------------------
        log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
        log.event( "CLIENT 2 HUB (KEEP ALIVE): " .. tostring( CLIENT_KEEPING_ALIVE ) ) ------------------ DEBUG
        --log.event( "-------------------------------------------------------------------------------" ) -- DEBUG
        -------------------------------------------------------------------------------------------------------
    end
end

--// net.loop() is no longer auto-run here. The active frontend
--// (frontends/cli/main.lua or the GUI's spawned worker) is
--// responsible for invoking it after dofile("core/init.lua") returns.
