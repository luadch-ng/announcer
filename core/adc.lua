--[[

    - written by blastbeat, 20141008

]]--

local adclib = require "adclib"

adc = { }

adc.createid = function( )
    -- adclib.hashpas's SECOND arg (the salt) must produce <= 64 bytes of
    -- base32-decoded data, i.e. salt string length <= 102 chars. The
    -- upstream construction (os.date() .. os.clock() .. os.time() .. fixed-60)
    -- is platform-dependent: on Windows os.date() returns ~24 chars (just
    -- fits), on Linux/locale C.UTF-8 it can return 30+ chars (pushes the
    -- total over 102 and triggers "hashpas: salt length X out of range"
    -- at adclib.cpp:217). Cap the variable component so the salt always
    -- fits.
    local salt = "GHKZUGFTDFLIHLHGKGVKHGGH545FGFKH43754KHFKHKHGKDDSWSGDJKGUK6758"
    local str = ( os.date( ) .. os.clock( ) .. os.time( ) ):sub( 1, 30 )
    local pid = adclib.hashpas( salt .. str, str .. salt )
    return pid, adclib.hash( pid )
end

local idfile = loadfile( CFG_PATH .. "id.lua" )
if idfile then
  idfile( )
else
  local idfile, err = io.open( CFG_PATH .. "id.lua", "a+" )
  assert( idfile, "Fail: " .. tostring( err ) )
  local pid, cid = adc.createid( ) 
  idfile:write( "id = { }\nid.pid = '" .. pid .. "'\nid.cid = '" .. cid .. "'\n" )
  idfile:flush( )
  idfile:close( ) 
  id = { pid = pid, cid = cid }
end 
