# Luadch-NG Announcer

[![License: GPL v3](https://img.shields.io/badge/license-GPLv3.0-blueviolet.svg)](LICENSE)

Release announcer for [Luadch](https://github.com/luadch-ng/luadch) hubs. Logs into an ADC hub as a registered bot account (TLS only), scans configured local directories, and posts new release folders to the hub's main chat via the ADC **OSNR** extension.

This repo consolidates two stale upstream tools - [`luadch/announcer_client`](https://github.com/luadch/announcer_client) (Win32 wxLua GUI, last release 2022) and [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot) (Win32 headless CLI, last release 2022) - into a single tree with one shared core and two thin frontends (CLI + GUI).

## Status

**Phase 0** (current, v1.0.0-pre): consolidated tree, still on Lua 5.1. The CLI frontend works on Windows; the GUI continues to use upstream's wxLua 2.8.12.3 bootstrap and is Windows-only.

**Phase 1** (planned): migrate the core + CLI to Lua 5.4 (matches the hub, lets the announcer share the hub's vendored deps + CMake pipeline).

**Phase 2** (planned): real cross-platform CLI (Linux + Windows) via a CMake build matrix and bundled `.so`/`.dylib` deps. The bot's existing `.dll`/`.so` filetype detect (already merged into `core/init.lua`) is the seed.

**Phase 3** (planned, biggest risk): GUI on Lua 5.4. wxLua 2.8 is ancient; modern wxLua 3.x compatibility is unknown. The GUI may lag behind core+CLI, stay Windows-only, or be rebuilt later.

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

## Usage (CLI, Phase 0, Windows)

1. **Certificate** - generate a TLS cert (the hub requires bot accounts to connect over TLS):
   ```sh
   cd certs/
   make_cert.bat   # OpenSSL must be on PATH
   ```
   Or use [luadch-ng/certmanager](https://github.com/luadch-ng/certmanager).

2. **Configure** - edit `cfg/hub.lua` (hub addr / nick / pass / keyprint) and `cfg/rules.lua` (which directories to scan + announce).

3. **Run**:
   ```sh
   lua frontends/cli/main.lua
   ```

   Log output lands in `log/logfile.txt` and announced releases in `log/announced.txt`.

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
