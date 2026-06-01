--[[

    Luadch-NG Announcer - frontend bootstrap helper

    Anchors require()/dofile() on the install root regardless of where
    lua.exe was launched from. Used by the CLI + GUI entry points.

    Hub solves the analogous problem with chdir_to_binary_dir() in
    hub/hub.c (its C launcher). The announcer ships vanilla lua.exe,
    so the equivalent fix lives at the Lua entry point.

    Strategy:
        1. Derive the install dir from `arg[0]` (the path to the
           entry-point script, e.g. frontends/cli/main.lua).
        2. Prepend ABSOLUTE entries to package.path / package.cpath
           for lib/lfs so we can require it before any chdir.
        3. lfs.chdir(install_dir) so the CWD-relative paths that
           core/init.lua + core/const.lua use after this resolve to
           the same install root.

    Callers must dofile this via an absolute path constructed from
    arg[0] - otherwise we hit the same CWD-relative trap this helper
    is here to solve.

        - written 2026-06-01 for luadch-ng/announcer Phase 2 PR-D

]]--

local script_path = ( arg and arg[ 0 ] ) or ""
local sep = package.config:sub( 1, 1 )
-- Mirror of the heuristic in core/init.lua. Kept in sync deliberately:
-- bootstrap runs strictly before core/init.lua loads, so we cannot
-- share a single definition. If you change one, change both.
local filetype = ( os.getenv "COMSPEC" and os.getenv "WINDIR" and ".dll" ) or ".so"

-- Match either separator since Windows accepts both `\` and `/` from
-- the shell. The pattern peels off `frontends/<type>/<file>.lua` from
-- the script path and yields everything before it as the install dir.
-- Fallback "." is correct for the `lua frontends/cli/main.lua` (and
-- the wxExecute relative-path) invocation: those only succeed when
-- the launcher's CWD already is the install root, so chdir(".") is
-- a no-op and the existing CWD-relative paths in core/init.lua
-- continue to resolve.
local install_dir = script_path:match( "^(.+)[/\\]frontends[/\\][^/\\]+[/\\][^/\\]+$" ) or "."

-- Reject suspicious chars in install_dir before interpolating into
-- package.path / package.cpath. `;` is the path-list separator and
-- `?` is the wildcard - either in install_dir would inject extra
-- module-search roots. POSIX permits both in directory names; we
-- refuse to operate from such a tree rather than silently hand out
-- extra search paths.
if install_dir:find( "[;?]" ) then
    io.stderr:write( "bootstrap: refusing to anchor on install_dir with `;` or `?`: " .. install_dir .. "\n" )
    os.exit( 1 )
end

-- Surface the anchoring decision so an unexpected fallback to "."
-- (e.g. launcher invoked with a shape we didn't anticipate) is
-- visible in logs rather than silently masked by a CWD that happens
-- to be the install root.
if install_dir == "." then
    io.stderr:write( "bootstrap: arg[0]='" .. script_path .. "' did not anchor; assuming CWD is install root\n" )
end

package.path =
    install_dir .. sep .. "core" .. sep .. "?.lua;" ..
    install_dir .. sep .. "lib" .. sep .. "?" .. sep .. "?.lua;" ..
    install_dir .. sep .. "lib" .. sep .. "luasocket" .. sep .. "lua" .. sep .. "?.lua;" ..
    install_dir .. sep .. "lib" .. sep .. "luasec" .. sep .. "lua" .. sep .. "?.lua;" ..
    package.path

package.cpath =
    install_dir .. sep .. "lib" .. sep .. "?" .. sep .. "?" .. filetype .. ";" ..
    install_dir .. sep .. "lib" .. sep .. "luasocket" .. sep .. "?" .. sep .. "?" .. filetype .. ";" ..
    install_dir .. sep .. "lib" .. sep .. "luasec" .. sep .. "?" .. sep .. "?" .. filetype .. ";" ..
    install_dir .. sep .. "lib" .. sep .. "lfs" .. sep .. "?" .. filetype .. ";" ..
    package.cpath

local lfs = require "lfs"
assert( lfs.chdir( install_dir ), "bootstrap: lfs.chdir to install dir failed: " .. install_dir )
