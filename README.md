# Luadch-NG Announcer

[![License: GPL v3](https://img.shields.io/badge/license-GPLv3.0-blueviolet.svg)](LICENSE)

Release announcer for [Luadch](https://github.com/luadch-ng/luadch) hubs. Logs into an ADC hub as a registered bot account (TLS only), scans configured local directories, and posts new release folders to the hub's main chat via the ADC **OSNR** extension.

This repo consolidates two stale upstream tools - [`luadch/announcer_client`](https://github.com/luadch/announcer_client) (Win32 wxLua GUI, last release 2022) and [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot) (Win32 headless CLI, last release 2022) - into a single tree with one shared core and two thin frontends (CLI + GUI).

## Status

**Phase 0** (current, v1.0.0-pre): consolidated tree, still on Lua 5.1. The CLI frontend works on Windows; the GUI continues to use upstream's wxLua 2.8.12.3 bootstrap and is Windows-only.

**Phase 1** (SHIPPED 2026-06-01): core + CLI migrated to Lua 5.4. Hub-vendored 5.4 deps + `lfs.dll` built fresh + `lua.exe`/`lua.dll` + OpenSSL bundled at install root. Events dispatch + GUI file-IPC bridge in place.

**Phase 2** (IN PROGRESS): CMake build pipeline. PR-A (this PR) adopts the hub's CMake 1:1 + adds a standalone `lua.exe` build target + vendors lfs source. Outputs at `build/install/announcer/`. PR-B is Linux build verification; PR-C is GitHub Actions CI matrix; PR-D is the 2 TODO(phase-2) source markers; PR-E replaces GUI resource `.dll` blobs with PNG loading.

**Phase 3** (planned, biggest risk): GUI on Lua 5.4 + wxLua 3.x. wxLua 2.8 is ancient. The GUI may lag behind core+CLI, stay Windows-only, or be rebuilt later. Closes [#7](https://github.com/luadch-ng/announcer/issues/7) (status.lua poll race window).

## Layout

```
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
  cli/main.lua            Standalone headless entry point. Drives net.loop()
                          in a reconnect loop. Cross-platform target.
  gui/Announcer.wx.lua    wxLua GUI (Win32 only). Inherits the existing
                          control panel + status display. Spawns the
                          announcer as a separate process - phase-0
                          integration TBD.

lib/          Bundled deps shipped with the repo
  basexx/     Pure-Lua base32/base64
  luasec/     TLS (binary + Lua)
  luasocket/  TCP/UDP (binary + Lua)
  adclib/     ADC tiger-hash + escape (Win-only .dll for Phase 0)
  lfs/        LuaFileSystem (Win-only .dll for Phase 0; CLI path)
  lfs_wx/     LuaFileSystem (Win-only .dll for Phase 0; GUI path)
  ressources/ GUI icons + .dll resource bundles
```

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
