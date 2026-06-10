#!/bin/sh
#
# Luadch-NG Announcer - CLI launcher.
#
# Thin wrapper around the bundled standalone Lua interpreter so users
# can start the announcer with `./announcer.sh` instead of typing
# `./lua frontends/cli/main.lua` by hand. Symmetric to the Windows
# `Announcer.exe` C launcher; the difference is that Windows needs a
# real PE binary to suppress the console window, while Linux is happy
# with a shell script.
#
# Strategy:
#   1. Resolve own dir via `readlink -f $0`. `readlink -f` follows any
#      symlink so `/usr/local/bin/announcer.sh -> /opt/announcer/...`
#      style installs work transparently.
#   2. `cd` to that dir = install root. Required because
#      `frontends/bootstrap.lua` + `Announcer.wx.lua` use CWD-relative
#      `package.path` entries (`././core/?.lua` etc.).
#   3. `exec` the bundled Lua on `frontends/cli/main.lua`, passing
#      through any caller args via `"$@"`.
#
# Falls back to `realpath` if `readlink -f` is unavailable (some
# minimal POSIX setups); ultimate fallback is `$0`-relative which
# breaks under symlinks but at least keeps the script runnable in
# weird environments.
#
# Exit code is whatever the announcer returns, by virtue of `exec`.

set -e

# Resolve script's own directory, following symlinks.
if command -v readlink >/dev/null 2>&1 && readlink -f / >/dev/null 2>&1; then
    SCRIPT_PATH=$(readlink -f "$0")
elif command -v realpath >/dev/null 2>&1; then
    SCRIPT_PATH=$(realpath "$0")
else
    # Fallback: $0 as-is. Works when called by absolute path or from
    # the install dir directly; breaks under symlinks.
    SCRIPT_PATH=$0
fi

SCRIPT_DIR=$(cd "$(dirname "$SCRIPT_PATH")" && pwd)

cd "$SCRIPT_DIR"
exec ./lua frontends/cli/main.lua "$@"
