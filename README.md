# Luadch-NG Announcer

[![License: GPL v3](https://img.shields.io/badge/license-GPLv3.0-blueviolet.svg)](LICENSE)

Release announcer for [Luadch](https://github.com/luadch-ng/luadch) hubs. Logs into an ADC hub as a registered bot account (TLS only), scans configured local directories, and posts new release folders to the hub's main chat via the ADC **OSNR** extension.

This repo consolidates two stale upstream tools - [`luadch/announcer_client`](https://github.com/luadch/announcer_client) (Win32 wxLua GUI, last release 2022) and [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot) (Win32 headless CLI, last release 2022) - into a single tree with one shared core and two thin frontends (CLI + GUI).

## Status

**Phase 0** (SHIPPED 2026-05-30): consolidated tree, Lua 5.1. CLI + GUI moved into one repo; events dispatch replaces upstream's file-IPC.

**Phase 1** (SHIPPED 2026-06-01): core + CLI migrated to Lua 5.4. Hub-vendored 5.4 deps; 2 upstream parser bugs fixed; events.lua pcall safety; wxLua-GUI file-IPC bridge via `frontends/gui/spawned_worker.lua`.

**Phase 2** (SHIPPED 2026-06-01): CMake build pipeline; source-only repo (every C-extension is a build artefact); Linux+Windows CI matrix; path-anchored entry points via `frontends/bootstrap.lua`.

**Phase 3** (SHIPPED Tier 1+2 on 2026-06-01/02): GUI on Lua 5.4 + wxLua 3.x. Tier 1 ported Announcer.wx.lua to the wxLua-3.x API + migrated PE-icon containers to PNG. Tier 2 vendored wxWidgets 3.2.10 (submodule) + wxLua source (in-tree), wired the wxLua C-extension into the same CMake pipeline, gated behind `-DBUILD_GUI=ON`. Cross-platform GUI build (Linux + Windows) verified in CI. Tier 2e (docs, this update) closes the modernisation programme. Optional Tier 3 closes [#7](https://github.com/luadch-ng/announcer/issues/7) (status.lua poll race window).

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

--- GUI assets ---
lib/ressources/png/*.png GUI app icon (3 sizes), license badge, 5 tab icons.

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
see [GitHub releases](https://github.com/luadch-ng/announcer/releases).

## Usage (GUI, Linux + Windows)

Build the GUI explicitly with `-DBUILD_GUI=ON`:

```sh
git submodule update --init --recursive   # pulls wxWidgets 3.2.10
cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_GUI=ON   # add -G "MinGW Makefiles" -DOPENSSL_ROOT_DIR=... on Windows
cmake --build build -j 2                  # -j 2 keeps RAM under control during wxWidgets compile
cmake --install build
cd build/install/announcer
lua frontends/gui/Announcer.wx.lua        # lua.exe on Windows
```

Linux needs `libgtk-3-dev` (build) + optionally `xvfb` for headless smoke. The install tree is self-sufficient on both platforms (no system wxWidgets / wxLua required). Full build recipe: [docs/BUILDING.md](docs/BUILDING.md).

## Requirements

- **Hub** must be a Luadch (or compatible) ADC hub with the **OSNR** protocol extension.
- **Hub account** must be a registered nick (not a guest).
- **TLS** is mandatory - no plain-text fallback.

## Configuration

Edit these files under `cfg/` after a successful build. Each is a Lua
file that returns a table; comments inline explain each field.

| File | Purpose |
|---|---|
| `cfg/cfg.lua` | Global bot settings: announce interval, sleep / socket timeouts, log-rotation size, slots / share / upload-speed claims |
| `cfg/hub.lua` | Target hub: address, port, nick, password, TLS keyprint |
| `cfg/sslparams.lua` | LuaSec `ssl.newcontext` params: cert path, TLS protocol, ciphers |
| `cfg/rules.lua` | List of watched directories. Each rule = `{ path, category, command, filters }`. Filters: `blacklist`, `whitelist`, `checkspaces`, `checkage`, `checkdirsnfo`, `checkdirssfv`, `skip_hidden`, `max_per_extension` |
| `cfg/categories.lua` | Category metadata for freshstuff-style multi-category announces |
| `cfg/id.lua` | **Auto-generated on first run**, gitignored. Holds the bot's ADC PID + CID (tiger-hash secret). DO NOT copy between deployments - each announcer needs its own identity, shared identity = two bots fight over the same nick on the hub. Delete the file to regenerate a fresh identity. |

### Path syntax (`cfg/rules.lua`)

The `path` field in each rule **must use forward slashes on all
platforms**, including Windows. The Win32 API accepts both `/`
and `\`, but Lua string literals require backslashes to be escaped
(`\\`), which is error-prone.

```lua
-- Correct (cross-platform):
[ "path" ] = "C:/MyReleases",
[ "path" ] = "/home/user/releases",

-- Avoid (Lua-string-literal issue, "\M" is not a valid Lua escape):
[ "path" ] = "C:\MyReleases",

-- Workable but ugly:
[ "path" ] = "C:\\MyReleases",
```

### About OSNR

OSNR is an ADC **SUP feature flag** for hub-side release-announce
handling. The bot negotiates `ADOSNR` in its `HSUP` and disconnects
if the hub does not advertise it back in `ISUP`. Once negotiated,
the bot announces each release as a regular `BMSG` to the hub,
prefixed with the per-rule `command` keyword (e.g. `+addrel <release>`).
OSNR-aware hub scripts pick these tagged broadcasts out of the main-chat
stream and render them as a structured release feed for clients that
display one. Your hub must support OSNR - Luadch enables it by default.
Without it, the bot refuses to log in.

## Origins + credits

- Original Win32 GUI: [`luadch/announcer_client`](https://github.com/luadch/announcer_client) by pulsar (with jrock).
- Original headless bot: [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot) by blastbeat.
- This consolidation: luadch-ng org (this repo), 2026.

## License

GPL-3.0. See [LICENSE](LICENSE).
