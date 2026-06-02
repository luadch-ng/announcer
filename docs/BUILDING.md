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
- `libgtk-3-dev` (the wxWidgets Linux backend; Phase 3 Tier 2c).

### Clone (both platforms)

The wxWidgets source is a git submodule. Either:

```sh
git clone --recurse-submodules https://github.com/luadch-ng/announcer.git
```

Or after a plain clone:

```sh
cd announcer
git submodule update --init --recursive
```

Without this step `cmake -B build` fails at configure with a clear
error pointing at this section.

## Build (Windows)

From the repo root:

```sh
cmake -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=C:/OpenSSL
cmake --build build -j
cmake --install build
```

### Opting in to the GUI build

The wxLua-3.x GUI runtime is gated behind `-DBUILD_GUI=ON`. Default is
OFF so the CLI smoke + CI matrix don't pay the wxWidgets-build cost
(~5-10 min) on every push. To get a working GUI:

```sh
git submodule update --init --recursive   # one-time, pulls wxWidgets 3.2.10
cmake -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=C:/OpenSSL -DBUILD_GUI=ON
cmake --build build -j 2     # -j 2 on Windows: full -j OOMs on
                              # 16 GB runners; large wxcore TUs eat 1-2 GB each
cmake --install build
```

After `cmake --install build` the install tree contains a complete
self-sufficient GUI runtime: `lib/wx/wx.dll` (the Lua C-extension),
the wxWidgets shared libs at install root (`wxbase32u_*.dll`,
`wxmsw32u_core_*.dll`, etc), and the MinGW C/C++ runtime DLLs
(`libgcc_s_seh-1.dll`, `libstdc++-6.dll`, `libwinpthread-1.dll`).
Run the GUI with:

```sh
cd build/install/announcer
./lua.exe frontends/gui/Announcer.wx.lua
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
  lib/luasec/{lua/ssl.lua, ssl/ssl.dll}
  lib/luasocket/{lua/*.lua, mime/mime.dll, socket/socket.dll}
  lib/ressources/            GUI PNG assets
  lib/unicode/unicode.lua    pure-Lua utf-8 shim
  log/                        empty, populated at runtime
```

With `-DBUILD_GUI=ON` you additionally get:
```
build/install/announcer/
  lib/wx/wx.dll                   wxLua C-extension (3.6 MB)
  wxbase32u_*_custom.dll          wxWidgets base lib (~4 MB)
  wxmsw32u_core_*_custom.dll      wxWidgets core (~11 MB)
  wxmsw32u_adv_*_custom.dll       wxWidgets advanced (~16 KB; mostly moved to core in 3.x)
  wxmsw32u_html_*_custom.dll      wxWidgets HTML (~1 MB; pulled in by binding refs to wxBestHelpController)
  wxbase32u_net_*_custom.dll      wxWidgets net (~500 KB; pulled in by binding refs to wxInternetFSHandler)
  libgcc_s_seh-1.dll              MinGW C runtime (~900 KB)
  libstdc++-6.dll                 MinGW C++ runtime (~2.5 MB)
  libwinpthread-1.dll             MinGW pthreads (~70 KB)
```

## Run (Windows)

```sh
cd build/install/announcer
# First-time setup:
cd certs && make_cert.bat && cd ..    # OpenSSL on PATH; generates serverkey.pem + servercert.pem
notepad cfg/hub.lua                    # set addr / nick / pass / keyprint
notepad cfg/rules.lua                  # set watched directories
# Run:
lua.exe frontends/cli/main.lua         # CLI (always available)
lua.exe frontends/gui/Announcer.wx.lua # GUI (only when built with -DBUILD_GUI=ON)
```

## Build (Linux)

```sh
sudo apt-get install -y build-essential cmake libssl-dev libgtk-3-dev xvfb
git submodule update --init --recursive   # only needed for the GUI build
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j 2
cmake --install build
```

Linux uses the system's GTK3 + GLib + glibc, so no MinGW-style
runtime bundling. `libgtk-3-dev` is only required when building with
`-DBUILD_GUI=ON`. `xvfb` is only required if you want to load the wx
module without a real X11 display (e.g. CI smoke).

`-j 2` on the build line keeps RAM under control on 16 GB machines /
runners; the wxWidgets C++ TUs are heavy. Use `-j` unconstrained on
larger boxes.

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
- **Always run from the install dir, not the source tree.** The
  `frontends/gui/Announcer.wx.lua` integrity check (lines ~1108-1139)
  expects the post-install layout - `lib/adclib/adclib.dll`,
  `lib/lfs/lfs.dll` etc. live under `lib/<dep>/` after
  `cmake --install` but DO NOT exist in the source tree (they're
  CMake outputs). Trying to launch the GUI from the source root
  fails the integrity check. The CLI's `frontends/cli/main.lua`
  has the same `package.cpath`/`package.path` assumption via
  `core/init.lua` (the `././lib/...` prefixes resolve relative to
  CWD). PR-D (Phase 2) will refactor these to be exec-dir-relative;
  until then, the rule is: `cd build/install/announcer` first.

## Cross-platform (Phase 2 PR-B, queued)

The CMakeLists is portable; what's missing is CI verification on
Linux + GitHub Actions. PR-B will add that.
