# Luadch-NG Announcer

[![License: GPL v3](https://img.shields.io/badge/license-GPLv3.0-blueviolet.svg)](LICENSE)

Release announcer for [Luadch](https://github.com/luadch-ng/luadch) hubs. Logs into an ADC hub as a registered bot account (TLS only), scans configured local directories, and posts new release folders to the hub's main chat via the ADC **OSNR** extension.

This repo consolidates two stale upstream tools - [`luadch/announcer_client`](https://github.com/luadch/announcer_client) (Win32 wxLua GUI, last release 2022) and [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot) (Win32 headless CLI, last release 2022) - into a single tree with one shared core and two thin frontends (CLI + GUI).

## Status

**Phase 0** (SHIPPED 2026-05-30, v1.0.0-pre): consolidated tree, Lua 5.1. CLI + GUI moved into one repo; events dispatch replaces upstream's file-IPC.

**Phase 1** (SHIPPED 2026-06-01, v1.0.0-dev): core + CLI migrated to Lua 5.4. Hub-vendored 5.4 deps (binary copies from hub's build); 2 upstream parser bugs fixed; events.lua pcall safety; wxLua-GUI file-IPC bridge via `frontends/gui/spawned_worker.lua`.

**Phase 2** (IN PROGRESS): CMake build pipeline. PR-A (this PR) adopts the hub's CMake 1:1 + adds a standalone `lua.exe` build target + vendors lfs source from upstream. **After this PR the announcer ships source-only**: `lua.exe`, `lua.dll`, OpenSSL DLLs, and the `lib/<dep>/<artefact>` C-extension binaries are CMake outputs at `build/install/announcer/` rather than committed blobs. PR-B is Linux build verification; PR-C is GitHub Actions CI matrix; PR-D is the 2 TODO(phase-2) source markers; PR-E replaces GUI resource `.dll` blobs with PNG loading.

**Phase 3** (planned, biggest risk): GUI on Lua 5.4 + wxLua 3.x. wxLua 2.8 is ancient. The GUI may lag behind core+CLI, stay Windows-only, or be rebuilt later. Closes [#7](https://github.com/luadch-ng/announcer/issues/7) (status.lua poll race window).

## Layout

```
--- Runtime code (Lua) ---
core/         Canonical announcer core (shared by CLI + GUI)
  init.lua    Bootstrap - sets package.path + dofiles all modules
  const.lua   Paths + version
  events.lua  In-process event dispatch (replaces status-file IPC)
  log.lua     Two-file logger (logfile.txt + announced.txt)
  adc.lua     ADC PID/CID helpers
  announce.lua Directory-scan + filter logic (blacklist / whitelist /
              NFO / SFV / max-age / daydir / freshstuff-categories)
  net.lua     Connect + login + announce loop (TLS, OSNR)
  util.lua    Table serialise / loadtable / savetable / formatbytes

cfg/          Per-install configuration (operator edits)
  cfg.lua         Bot settings (interval / sleeptime / sockettimeout / ...)
  sslparams.lua   LuaSec ssl.newcontext params (cert path, protocol, ciphers)
  hub.lua         Hub address / nick / pass / keyprint
  rules.lua      Watched directories + per-rule command + filters
  categories.lua  Category metadata for freshstuff-style multi-category announces

frontends/
  cli/main.lua             Standalone headless entry point. Drives net.loop()
                           in a reconnect loop. Cross-platform target.
  gui/Announcer.wx.lua     wxLua GUI (Win32 only).
  gui/spawned_worker.lua   GUI's spawned-worker (events.on(status, ...) ->
                           writes core/status.lua for the GUI poller).

--- Vendored C / pure-Lua sources (Phase 2; build inputs) ---
lua/src/      Lua 5.4 stdlib + standalone interpreter source (vendored from hub).
adclib/       ADC tiger-hash + base32 + escape (vendored from hub).
luasec/       TLS C module (vendored from hub, upstream LuaSec 1.3.2).
luasocket/    TCP/UDP C module (vendored from hub, upstream LuaSocket 3.1.0).
lfs/src/      LuaFileSystem (vendored from upstream lunarmodules/luafilesystem v1.9.0).
basexx/       Pure-Lua base32/base64 (vendored from hub).
slnunicode/   Pure-Lua utf-8 shim (vendored from hub).
CMakeLists.txt + per-dep CMakeLists.txt in each source dir.

--- Committed binaries still in source tree (Phase 2 transitional) ---
lib/lfs_wx/lfs.dll       Lua-5.1 build used by the wxLua-2.8 GUI; Phase 3 replaces.
lib/ressources/*.dll     wxLua icon-resource bundles; Phase 2 PR-E replaces with PNG.
lib/ressources/png/*.png GUI app icon + license-badge PNGs.

--- Other ---
certs/        OpenSSL cert-generation scripts (.bat + .sh).
docs/         BUILDING.md + future docs.
log/          Empty runtime log dir (gitignored except .gitkeep).
```

After `cmake --install build` the runtime tree at `build/install/announcer/`
adds `lua.exe`, `lua.dll`, the OpenSSL DLLs, and the `lib/<dep>/<artefact>`
C-extension binaries on top of the source layout above.

## Build + run (CLI, Windows)

After Phase 2 the announcer ships **source-only**; build with the in-tree
CMake pipeline (mirrors the parent luadch repo's recipe). See
[`docs/BUILDING.md`](docs/BUILDING.md) for prerequisites + full details.

```sh
# From the repo root:
cmake -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=C:/OpenSSL
cmake --build build -j
cmake --install build

# Output lands at build/install/announcer/. From there:
cd build/install/announcer

# 1. Generate a TLS cert (hub requires TLS):
cd certs/ && make_cert.bat && cd ..

# 2. Edit cfg/hub.lua (addr / nick / pass / keyprint) and cfg/rules.lua (dirs to scan).

# 3. Run:
lua.exe frontends/cli/main.lua
```

Log output lands in `log/logfile.txt` and announced releases in `log/announced.txt`.

For a no-build alternative (release zip with the binaries pre-built),
watch the [GitHub releases](https://github.com/luadch-ng/announcer/releases)
page once Phase 2 PR-C ships the CI build artefacts.

## Usage (GUI, Phase 0, Windows)

Existing upstream workflow still applies for Phase 0. The freeze recipe (using `wxluafreeze`) is in [docs/BUILDING_GUI.md](docs/BUILDING_GUI.md) (TBD).

## Requirements

- **Hub** must be a Luadch (or compatible) ADC hub with the **OSNR** protocol extension.
- **Hub account** must be a registered nick (not a guest).
- **TLS** is mandatory - no plain-text fallback.

## Origins + credits

- Original Win32 GUI: [`luadch/announcer_client`](https://github.com/luadch/announcer_client) by pulsar (with jrock).
- Original headless bot: [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot) by blastbeat.
- This consolidation: luadch-ng org (this repo), 2026.

## License

GPL-3.0. See [LICENSE](LICENSE).
