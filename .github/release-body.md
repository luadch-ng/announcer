# Luadch-NG Announcer v1.0.0-rc1

Inaugural binary release of the consolidated `luadch-ng/announcer` tree, replacing the two upstream tools [`luadch/announcer_client`](https://github.com/luadch/announcer_client) (Win32 wxLua GUI) and [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot) (Win32 headless CLI), both stale since 2022.

## ⚠️ Before installing

If you are migrating from upstream `luadch/announcer_client` or `luadch/announcer_bot`, back up your existing config and state before swapping:

```sh
tar -czf "announcer-upstream-backup-$(date +%F).tar.gz" cfg log
```

The cfg directory layout in `luadch-ng/announcer` is **the same on-disk shape** as both upstream tools - `cfg.lua` / `sslparams.lua` / `hub.lua` / `rules.lua` / `categories.lua`. Drop them into the new install tree's `cfg/` directory and the existing settings are picked up byte-for-byte. The `log/announced.txt` state file (which releases were already announced) also carries over unchanged.

If you are a first-time user, no backup applies - the empty `cfg/` directory is initialised by the bundled example files.

## Highlights

### Consolidation ([Phase 0](https://github.com/luadch-ng/announcer/pull/3))

One repo, one core, two thin frontends:

- `core/` - canonical announcer code (Lua 5.4) shared by both CLI and GUI
- `frontends/cli/main.lua` - cross-platform headless entry point (Linux + Windows)
- `frontends/gui/Announcer.wx.lua` - wxLua GUI (Win32, optional)

Replaces upstream's status-file IPC between the GUI and the worker with an in-process event dispatch (`core/events.lua`). The GUI still spawns a worker process for isolation, but the worker writes its status to disk via a thin bridge instead of the worker code being aware of the GUI's polling protocol. Reduces the coupling that made upstream's split-repo lifecycle painful to maintain.

### Lua 5.4 migration ([Phase 1](https://github.com/luadch-ng/announcer/pull/4))

Core and CLI ported from Lua 5.1 (stale upstream baseline) to **Lua 5.4** with the hub's vendored interpreter and deps (LuaSec 1.3.2, LuaSocket 3.1.0, LFS 1.9.0, adclib, basexx). Two upstream parser bugs surfaced and fixed by the audit. Event-dispatch (`events.lua`) now wraps every listener in `pcall` so a buggy handler can't crash the loop.

### Cross-platform CMake build ([Phase 2](https://github.com/luadch-ng/announcer/pull/5))

The source tree is now build-anywhere:

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
cmake --install build
```

Output lands in `build/install/announcer/`. Same three-step pipeline on Linux and Windows. CI matrix verifies both per push. Entry points are path-anchored via `frontends/bootstrap.lua` so the tree is relocatable. Source-only repo, no binary artefacts in git.

### wxLua 3.x GUI ([Phase 3](https://github.com/luadch-ng/announcer/pull/6))

The GUI was on stale wxLua 2.x (with stale wxWidgets 3.0). This release vendors **wxLua source in-tree** and **wxWidgets 3.2.10 as a git submodule**, builds them via the same CMake pipeline behind `-DBUILD_GUI=ON`, and rewires `Announcer.wx.lua` to the wxLua 3.x API. PE-icon containers migrated to PNG. **Cross-platform GUI build (Linux + Windows) verified in CI** - upstream's GUI was Win32-only.

### Quick-wins (post-Phase-3 cleanup)

Seven follow-up PRs from an upstream-issues audit:

- [#35](https://github.com/luadch-ng/announcer/pull/35) - log-spam from announce-loop idle ticks
- [#37](https://github.com/luadch-ng/announcer/pull/37) - BINF cleanup + missing `US` field for hublist pingers
- [#39](https://github.com/luadch-ng/announcer/pull/39) - hidden-file filter + per-extension max-count filter
- [#40](https://github.com/luadch-ng/announcer/pull/40) - GUI input validation for ADC-illegal characters
- [#41](https://github.com/luadch-ng/announcer/pull/41) - cert-gen `UID` env-var collision (bash builtin) + CLI usage docs
- [#43](https://github.com/luadch-ng/announcer/pull/43) - large-logfile guard (announce-state log was unbounded)
- [#44](https://github.com/luadch-ng/announcer/pull/44) - `USERGUIDE.md` for end users

Plus [#7](https://github.com/luadch-ng/announcer/issues/7) (Phase 3 Tier 3) - `status.lua` poll race between the spawned worker and the GUI poller was closed.

### Test surface

Smoke test runs on every push: validates the CMake pipeline produces a working binary on Linux and Windows. GUI builds also verified on both platforms.

## What it does

Logs into an ADC hub as a registered bot account (TLS only), watches one or more local directories, and posts new release folders to the hub's main chat using the ADC **OSNR** extension. Filters support blacklist, whitelist, age caps, NFO/SFV requirements, per-extension max-count, hidden-file skipping, day-directory matching, and freshstuff-style multi-category dispatch. Per-rule custom command templates allow operator-specific announce-line formatting.

## Downloads

| File | Platform | What's included |
|---|---|---|
| `announcer-v1.0.0-rc1-linux-x86_64.tar.gz` | Linux x86_64 (glibc 2.31+) | CLI + standalone Lua runtime + bundled deps |
| `announcer-v1.0.0-rc1-windows-x86_64.zip` | Windows x86_64 | CLI + GUI + standalone Lua runtime + bundled deps |

GUI on Linux is build-only at this time (`-DBUILD_GUI=ON`); no Linux GUI binary in the release asset. Source-build users on Linux desktop can get the GUI via CMake.

## Migration from upstream

| Step | What to do |
|---|---|
| 1. Back up upstream cfg + log | `tar -czf upstream-backup.tar.gz cfg log` (in your old install dir) |
| 2. Download this release | linux-x86_64 tarball OR windows-x86_64 zip |
| 3. Drop the new tree | extract somewhere fresh, do NOT overwrite the upstream install |
| 4. Copy your cfg + log | `cp -r /path/to/upstream/cfg/* /path/to/new/announcer/cfg/`<br>`cp /path/to/upstream/log/announced.txt /path/to/new/announcer/log/` |
| 5. First run | CLI: `./announcer.sh` (Linux) or `lua.exe frontends/cli/main.lua` (Windows). GUI: double-click `Announcer.exe` (Windows) |

The on-disk format of `cfg.lua` / `sslparams.lua` / `hub.lua` / `rules.lua` / `categories.lua` is byte-identical to upstream - your existing settings carry over without edits.

## How to report issues

Open an issue at https://github.com/luadch-ng/announcer/issues with:

- Platform (Linux distro / Windows version)
- Frontend (CLI / GUI)
- Steps to reproduce
- Relevant lines from `log/logfile.txt`

## Build from source

```sh
git clone --recurse-submodules https://github.com/luadch-ng/announcer.git
cd announcer

# CLI only (smaller, Linux + Windows)
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
cmake --install build

# CLI + GUI (adds ~250 MB build dir for wxWidgets; Linux + Windows)
cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_GUI=ON
cmake --build build -j
cmake --install build
```

Output lands in `build/install/announcer/`. Run the binary from there.

Full prerequisites (compiler toolchain, OpenSSL, wxWidgets system deps for `-DBUILD_GUI=ON`) in [`README.md`](https://github.com/luadch-ng/announcer/blob/main/README.md#building).
