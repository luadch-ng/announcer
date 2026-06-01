# Building luadch-ng/announcer

## Prerequisites

### Windows (Win64)

- **MinGW-w64 / UCRT64** with `gcc` on PATH. Tested with `gcc 16.1.0
  UCRT64` (the same toolchain the parent luadch repo uses).
- **OpenSSL 3.0+** at a known location. The CMake configure requires
  `-DOPENSSL_ROOT_DIR=...`. Tested with `C:\OpenSSL` (flat layout: DLLs
  + headers at the root).
- **CMake 3.20+**.

### Linux

- `gcc` and `cmake >= 3.20`.
- `libssl-dev` (OpenSSL 3.0+) + `zlib1g-dev` (matches the hub's deps).

Linux build is Phase 2 PR-B scope; the source compiles under POSIX
already but is not CI-verified yet.

## Build (Windows)

From the repo root:

```sh
cmake -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=C:/OpenSSL
cmake --build build -j
cmake --install build
```

Output lands at `build/install/announcer/`:

```
build/install/announcer/
  lua.exe              Lua 5.4 standalone interpreter
  lua.dll              Lua 5.4 runtime
  libssl-3-x64.dll     OpenSSL 3 (bundled from OPENSSL_ROOT_DIR)
  libcrypto-3-x64.dll  OpenSSL 3 (bundled from OPENSSL_ROOT_DIR)
  core/                announcer core (Lua)
  cfg/                 default config templates (operator edits)
  certs/               cert-generation scripts
  frontends/cli/main.lua
  frontends/gui/Announcer.wx.lua + spawned_worker.lua
  lib/adclib/adclib.dll      ADC tiger-hash module
  lib/basexx/basexx.lua      base32/base64 helpers
  lib/lfs/lfs.dll            LuaFileSystem
  lib/lfs_wx/lfs.dll         (still Lua-5.1, GUI-only; Phase 3 will replace)
  lib/luasec/{lua/ssl.lua, ssl/ssl.dll}
  lib/luasocket/{lua/*.lua, mime/mime.dll, socket/socket.dll}
  lib/ressources/            GUI assets
  lib/unicode/unicode.lua    pure-Lua utf-8 shim
  log/                        empty, populated at runtime
```

## Run (Windows)

```sh
cd build/install/announcer
# First-time setup:
cd certs && make_cert.bat && cd ..    # OpenSSL on PATH; generates serverkey.pem + servercert.pem
notepad cfg/hub.lua                    # set addr / nick / pass / keyprint
notepad cfg/rules.lua                  # set watched directories
# Run:
lua.exe frontends/cli/main.lua         # CLI
# or:
# Phase 3 will reintroduce a wxLua-3 GUI; until then use the spawned_worker via the legacy wxLua 2.8 Announcer.exe (Phase 0 inheritance, separately built).
```

## Vendored sources

The C dependencies are vendored from luadch-ng/luadch (the hub) +
upstream `lunarmodules/luafilesystem` (for lfs). See [`BUNDLED.md`](../BUNDLED.md)
for the per-dependency provenance + version tags.

To sync a vendored C dep against an updated hub version, copy the
relevant source tree from `luadch-ng/luadch` and re-run the build;
the CMakeLists are deliberately byte-equivalent to the hub's where
possible.

## Caveats

- The first build downloads nothing; everything is in-tree.
- OpenSSL DLLs are bundled at the install root from
  `OPENSSL_ROOT_DIR`. If that path doesn't contain
  `libssl-3-x64.dll` / `libcrypto-3-x64.dll` (e.g. a system OpenSSL
  layout), CMake fails with a clear message.
- `lib/lfs_wx/lfs.dll` is still a Lua-5.1 build (the GUI's separate
  wxLua-2.8 binary depends on it). Phase 3 will replace this with a
  modern wxLua-3 GUI on Lua 5.4 + drop the lfs_wx subdir.

## Cross-platform (Phase 2 PR-B, queued)

The CMakeLists is portable; what's missing is CI verification on
Linux + GitHub Actions. PR-B will add that.
