--[[

    util.lua written by blastbeat
    
    based on "luadch/core/util.lua"

]]--

local sortserialize
local savearray
local savetable
local savetable_atomic
local loadtable
local formatbytes

sortserialize = function( tbl, name, file, tab, r )
    tab = tab or ""
    local temp = { }
    for key, k in pairs( tbl ) do
        --if type( key ) == "string" or "number" then
            table.insert( temp, key )
        --end
    end
    table.sort( temp )
    local str = tab .. name
    if r then
        file:write( str .. "return {\n\n" )
    else
        file:write( str .. " = {\n\n" )
    end
    for k, key in ipairs( temp ) do
        if ( type( tbl[ key ] ) ~= "function" ) then
            local skey = ( type( key ) == "string" ) and string.format( "[ %q ]", key ) or string.format( "[ %d ]", key )
            if type( tbl[ key ] ) == "table" then
                sortserialize( tbl[ key ], skey, file, tab .. "    " )
                file:write( ",\n" )
            else
                local svalue = ( type( tbl[ key ] ) == "string" ) and string.format( "%q", tbl[ key ] ) or tostring( tbl[ key ] )
                file:write( tab .. "    " .. skey .. " = " .. svalue )
                file:write( ",\n" )
            end
        end
    end
    file:write( "\n" )
    file:write( tab .. "}" )
end
 
savetable = function( tbl, name, path )
    local file, err = io.open( path, "w+" )
    if file then
        if not name or name == "" then
            sortserialize( tbl, name, file, "", true )
        else
            sortserialize( tbl, name, file, "" )
            file:write( "\n\nreturn " .. name )
        end
        file:close( )
        return true
    else
        return false, err
    end
end

-- Write-then-rename atomic variant of savetable.
-- Phase 3 Tier 3 (#7): the original savetable opens the target file
-- with "w+" which truncates immediately - a concurrent reader (the
-- GUI status poll) hitting the file mid-write sees an empty or
-- partial table and util.loadtable returns nil + a "load error".
-- This variant writes to <path>.tmp, then atomically replaces the
-- target via os.rename. POSIX rename(2) is atomic across the file;
-- Windows MoveFileEx falls back to delete+rename and has a tiny
-- gap between the os.remove and the os.rename - still orders of
-- magnitude smaller than the previous "file truncated for the
-- entire serialise duration" race.
savetable_atomic = function( tbl, name, path )
    local tmp = path .. ".tmp"
    local ok, err = savetable( tbl, name, tmp )
    if not ok then
        return false, err
    end
    -- os.rename refuses to overwrite an existing file on Windows.
    -- Best-effort: remove the target first if present. POSIX rename
    -- silently replaces, so this is a no-op there.
    os.remove( path )
    local renamed, rerr = os.rename( tmp, path )
    if not renamed then
        os.remove( tmp )
        return false, rerr
    end
    return true
end
 
loadtable = function( path )
    local file, err = io.open( path, "r" )
    if not file then
        return nil, err
    end
    local content = file:read "*a"
    file:close( )
    -- Lua 5.4: `loadstring` removed; `load` accepts a string directly.
    local chunk, err = load( content )
    if chunk then
        local ret = chunk( )
        if ret and type( ret ) == "table" then
            return ret
        else
            return nil, "invalid table"
        end
    end
    return nil, err
end
 
savearray = function( array, path )
    array = array or { }
    local file, err = io.open( path, "w+" )
    if not file then
        return false, err
    end
    local iterate, savetbl
    iterate = function( tbl )
        local tmp = { }
        for key, value in pairs( tbl ) do
            tmp[ #tmp + 1 ] = tostring( key )
        end
        table.sort( tmp )
        for i, key in ipairs( tmp ) do
            key = tonumber( key ) or key
            if type( tbl[ key ] ) == "table" then
                file:write( ( ( type( key ) ~= "number" ) and tostring( key ) .. " = " ) or " " )
                savetbl( tbl[ key ] )
            else
                file:write( ( ( type( key ) ~= "number" and tostring( key ) .. " = " ) or "" ) .. ( ( type( tbl[ key ] ) == "string" ) and string.format( "%q", tbl[ key ] ) or tostring( tbl[ key ] ) ) .. ", " )
            end
        end
    end
    savetbl = function( tbl )
        local tmp = { }
        for key, value in pairs( tbl ) do
            tmp[ #tmp + 1 ] = tostring( key )
        end
        table.sort( tmp )
        file:write( "{ " )
        iterate( tbl )
        file:write( "}, " )
    end
    file:write( "return {\n\n" )
    for i, tbl in ipairs( array ) do
        if type( tbl ) == "table" then
            file:write( "    { " )
            iterate( tbl )
            file:write( "},\n" )
        else
            file:write( "    " .. string.format( "%q", tostring( tbl ) ) .. ",\n" )
        end
    end
    file:write( "\n}" )
    file:close( )
    return true
end

formatbytes = function( bytes )
    local err
    local bytes = tonumber( bytes )

    --if ( not bytes ) or ( not type( bytes ) == "number" ) or ( bytes < 0 ) or ( bytes == 1 / 0 ) then
    if not bytes then
        err = "util.lua: error: number expected, got nil"
        return nil, err
    end
    if not type( bytes ) == "number" then
        err = "util.lua: error: number expected, got " .. type( bytes )
        return nil, err
    end
    if ( bytes < 0 ) or ( bytes == 1 / 0 ) then
        err = "util.lua: error: parameter not valid"
        return nil, err
    end
    if bytes == 0 then return "0 B" end
    local i, units = 1, { "B", "KB", "MB", "GB", "TB", "PB", "EB", "YB" }
    while bytes >= 1024 do
        bytes = bytes / 1024
        i = i + 1
    end
    
    if units[ i ] == "B" then
        return string.format( "%.0f", bytes ) .. " " .. ( units[ i ] or "?" )
    else
        return string.format( "%.2f", bytes ) .. " " .. ( units[ i ] or "?" )
    end
end

return {

    savetable = savetable,
    savetable_atomic = savetable_atomic,
    loadtable = loadtable,
    savearray = savearray,
    formatbytes = formatbytes,

}