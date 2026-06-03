--[[

    - written by blastbeat, 20141008
        - rewritten by pulsar for Luadch Announcer Client

]]--

package.path = package.path .. ";"
    .. "././core/?.lua;"
    .. "././lib/?/?.lua;"
    .. "././lib/luasocket/lua/?.lua;"
    .. "././lib/luasec/lua/?.lua;"

package.cpath = package.cpath .. ";"
    .. "././lib/?/?" .. ".dll" .. ";"
    .. "././lib/luasocket/?/?" .. ".dll" .. ";"
    .. "././lib/luasec/?/?" .. ".dll" .. ";"
    .. "././lib/lfs/?" .. ".dll" .. ";"

local lfs = require( "lfs" )
local util = require( CORE_PATH .. "util" )

local cfg_tbl = util.loadtable( CFG_PATH .. "cfg.lua" )
local maxlogsize = cfg_tbl[ "logfilesize" ] or 2097152

local logfile, content
local releasefile, releases

--// check if logfile reaches the maximum allowable size and if then clear it
local check_filesize = function( file )
    local logsize = lfs.attributes( file ).size or 0
    if logsize > maxlogsize then
        local f = io.open( file, "w+" ); f:close()
        --// #42: clear `releases` in-place rather than rebinding to a new
        --// empty table. core/announce.lua caches the reference at module
        --// load (`local alreadysent = log.getreleases()`); a rebind would
        --// leave announce.lua holding the pre-rotation table while the
        --// new entries go to a fresh post-rotation one - dedup would
        --// silently break for post-rotation releases until next restart.
        --// `content` is a string (immutable), so rebind is the only path
        --// and no external module holds a reference.
        if file:find( "logfile" ) then content = "" end
        if file:find( "announced" ) then
            for k in pairs( releases ) do releases[ k ] = nil end
        end
        return true
    end
    return false
end

--// #30: pre-startup rotation. The existing check_filesize fires only
--// INSIDE log.event / log.release - i.e. on next write. If the file
--// grew unbounded while the announcer was offline (crash mid-write,
--// disk-fill incident, third-party tooling, ...), the read("*a") below
--// would slurp the entire file into Lua memory before any rotation
--// logic could run. That blocked auto-login on a 526 MB logfile in
--// the upstream report. Truncate up-front so the read is bounded.
local pre_rotate = function( file )
    if lfs.attributes( file, "mode" ) ~= "file" then return end
    local size = lfs.attributes( file ).size or 0
    if size > maxlogsize then
        local f = io.open( file, "w+" )
        if f then f:close() end
        io.stderr:write( "log.lua: startup truncated oversized " .. file
            .. " (" .. size .. " bytes > " .. maxlogsize .. ", historical data discarded)\n" )
    end
end
pre_rotate( LOG_PATH .. "logfile.txt" )
pre_rotate( LOG_PATH .. "announced.txt" )

--// #42: do NOT redeclare `content` / `releases` with `local` here.
--// The outer locals on lines 26-27 are captured by the check_filesize
--// closure above (which resets them on rotation). A `local` here would
--// shadow them - check_filesize would then reset the orphaned outer
--// while log.event/log.find/log.getreleases keep reading the inner,
--// so the in-memory buffers would never actually reset after a
--// rotation. Plain assignment binds to the outer.
local err
logfile, err = io.open( LOG_PATH .. "logfile.txt", "a+" )
assert( logfile, "Fail: " .. tostring( err ) )
content = logfile:read( "*a" )

releasefile, err = io.open( LOG_PATH .. "announced.txt", "a+" )
assert( releasefile, "Fail: " .. tostring( err ) )
releases = { }
for line in releasefile:lines() do releases[ line ] = true end

log = { }

log.getreleases = function()
    return releases
end

log.release = function( buf )
    local cleared = false
    local timestamp = "[ " .. os.date( "%Y-%m-%d / %H:%M:%S" ) .. "] "
    if check_filesize( LOG_PATH .. "announced.txt" ) then cleared = true end
    releases[ buf ] = true
    releasefile:write( buf .. "\n" )
    releasefile:flush()
    if cleared then
        logfile:write( timestamp .. "cleared 'announced.txt' because of max logfile size: " .. util.formatbytes( maxlogsize ) .. "\n" )
        logfile:flush()
    end
end

log.event = function( buf )
    local cleared = false
    local timestamp = "[ " .. os.date( "%Y-%m-%d / %H:%M:%S" ) .. " ] "
    if check_filesize( LOG_PATH .. "logfile.txt" ) then cleared = true end
    buf = timestamp .. buf
    logfile:write( buf .. "\n" )
    logfile:flush()
    content = content .. buf
    if cleared then
        logfile:write( timestamp .. "cleared 'logfile.txt' because of max logfile size: " .. util.formatbytes( maxlogsize ) .. "\n" )
        logfile:flush()
    end
end

function log.find( buf )
    return content:find( buf, 1, true )
end