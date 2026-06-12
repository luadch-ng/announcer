--[[

    core/cert_autogen.lua - first-run TLS cert generation (#62)

    Generates a self-signed announcer client cert (servercert.pem +
    serverkey.pem) if either file is missing, by invoking the
    bundled `openssl` CLI on the host system. Mirrors the openssl
    chain in `certs/make_cert.{bat,sh}` so the on-disk result is
    interchangeable.

    The cert is a self-signed leaf signed by a single-use CA. The
    CA private key + cert (`cakey.pem` / `cacert.pem`) are removed
    after signing - they are transient signing material with no
    runtime use, and leaving the CA private key next to the live
    server key on disk is bad practice. Same cleanup pattern as
    `make_cert.{bat,sh}` post-#56.

    `openssl` must be on PATH. The Windows release ships
    `libssl-3-x64.dll` + `libcrypto-3-x64.dll` for LuaSec but NOT
    the `openssl.exe` binary; operators on Windows without OpenSSL
    installed need to either install OpenSSL or run
    `certs/make_cert.bat` once before the first connect (which
    will work if they have OpenSSL via a different path).

    Cross-platform: detects Windows via `package.config` and picks
    the right `where` / `which` probe + the right redirect-to-null
    suffix. The actual openssl flags are identical on both
    platforms.

    Return contract:
        ensure(cert_path, key_path) -> true on success / cert
            already present, OR false + error message on failure.
        The caller decides whether to log / bail / display.

        - written 2026-06-12 for luadch-ng/announcer#62

]]--

local cert_autogen = { }

local function is_windows( )
    return package.config:sub( 1, 1 ) == "\\"
end

local function file_exists( path )
    local f = io.open( path, "r" )
    if f then f:close( ); return true end
    return false
end

-- We use io.popen + drain rather than os.execute + `>nul` because
-- Lua's os.execute on Windows can route through cmd.exe or sh
-- depending on the parent shell environment (msys2 / git-bash
-- inherits a sh-style env that breaks cmd.exe's `>nul` redirect
-- parser). io.popen captures stdout into a pipe regardless of
-- COMSPEC, and `2>&1` merges stderr into the same pipe -
-- functionally equivalent to /dev/null since we discard the
-- content, but with no shell-redirect-grammar dependency.
local function run( cmd )
    local fh = io.popen( cmd .. " 2>&1" )
    if not fh then return false, "io.popen failed" end
    fh:read( "*a" )    -- drain (otherwise close blocks on a full pipe)
    local ok, _, code = fh:close( )
    if ok == true then return true end
    if ok == 0 then return true end
    if type( ok ) == "number" and ok == 0 then return true end
    return false, code
end

-- The openssl command we shell out to. The bare token works both
-- ways:
--
--   * Windows: cmd.exe resolves command names by searching the
--     current directory FIRST, then PATH. CWD at this point is the
--     install root (frontends/bootstrap.lua chdirs there). The
--     Windows release zip ships openssl.exe next to the libssl-3 /
--     libcrypto-3 DLLs, so the bundled binary wins automatically
--     when it's present, and the operator's PATH-installed openssl
--     (Git for Windows, Node, Python, etc.) is the fallback when
--     it isn't.
--
--   * Linux: PATH lookup. We don't ship a bundled binary on Linux -
--     openssl is essentially universally pre-installed on the
--     distros we target.
local function openssl_cmd( )
    return "openssl"
end

local function openssl_available( )
    -- On Windows the bundled binary in CWD satisfies cmd.exe's
    -- cwd-first lookup but is NOT visible to `where openssl`
    -- (which only searches PATH). Special-case that so a clean
    -- Windows install with the bundled openssl.exe but no PATH
    -- entry doesn't fail the probe.
    if is_windows( ) and file_exists( "openssl.exe" ) then
        return true
    end
    return ( run( is_windows( ) and "where openssl" or "which openssl" ) )
end

-- Derive the cert dir from cert_path so the openssl outputs land
-- next to the existing layout (and so the CA artefacts we delete
-- afterward are in the same dir).
local function cert_dir_from( path )
    return path:match( "^(.+)[/\\][^/\\]+$" ) or "certs"
end

-- Read a single line from `openssl rand -hex 16`. Done via io.popen
-- so we capture the random CN directly instead of writing-then-reading
-- a uid.txt file (matches the streamlined make_cert.bat post-#56).
local function random_cn( )
    local fh = io.popen( openssl_cmd( ) .. " rand -hex 16" )
    if not fh then return nil, "io.popen openssl rand failed" end
    local cn = fh:read( "*l" )
    fh:close( )
    if not cn or #cn < 32 then
        return nil, "openssl rand returned short / empty output"
    end
    return cn
end

function cert_autogen.ensure( cert_path, key_path )
    if file_exists( cert_path ) and file_exists( key_path ) then
        return true
    end

    if not openssl_available( ) then
        return false, "openssl not on PATH; install OpenSSL or run "
            .. ( is_windows( ) and "certs/make_cert.bat" or "certs/make_cert.sh" )
            .. " manually before connecting"
    end

    local cn, err = random_cn( )
    if not cn then return false, err end

    local dir = cert_dir_from( cert_path )
    local cakey  = dir .. "/cakey.pem"
    local cacert = dir .. "/cacert.pem"
    local skey   = dir .. "/serverkey.pem"
    local scert  = dir .. "/servercert.pem"
    local subj   = "/CN=" .. cn
    local oc = openssl_cmd( )

    -- The same five-step chain make_cert.sh runs. Per-step output
    -- is captured + discarded by run() (io.popen drain + 2>&1
    -- merge), so the verbose "Generating an EC private key ..."
    -- lines under modern openssl don't swamp the announcer log.
    local steps = {
        ( oc .. ' ecparam -out "%s" -name prime256v1 -genkey' ):format( cakey ),
        ( oc .. ' req -new -x509 -days 3650 -key "%s" -out "%s" -subj %s' ):format( cakey, cacert, subj ),
        ( oc .. ' ecparam -out "%s" -name prime256v1 -genkey' ):format( skey ),
        ( oc .. ' req -new -key "%s" -out "%s" -subj %s' ):format( skey, scert, subj ),
        ( oc .. ' x509 -req -days 3650 -in "%s" -CA "%s" -CAkey "%s" -set_serial 01 -out "%s"' ):format( scert, cacert, cakey, scert ),
    }

    for i, cmd in ipairs( steps ) do
        if not run( cmd ) then
            return false, "openssl step " .. i .. " failed; check that OpenSSL is functional and the certs/ directory is writable"
        end
    end

    -- Drop transient CA material so the runtime cert dir holds only
    -- the announcer's own server key + cert. Errors here are
    -- non-fatal - leaving cakey.pem / cacert.pem behind is messy
    -- but the cert pair is already in place.
    os.remove( cakey )
    os.remove( cacert )

    return true
end

return cert_autogen
