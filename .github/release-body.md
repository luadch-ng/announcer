# Luadch-NG Announcer v1.0.0-rc2

Second pre-release of the consolidated `luadch-ng/announcer` tree (replaces upstream [`luadch/announcer_client`](https://github.com/luadch/announcer_client) + [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot), both stale since 2022).

## ⚠️ Why you want rc2 over rc1

v1.0.0-rc1 had a **latent crash that prevented every hub login** - `core/net.lua` referenced `adclib` as a global, but only `core/adc.lua` had `local adclib = require "adclib"`. The worker process died silently at BINF construction (immediately after the `Provided SID` log line). GUI users only saw the misleading "No INF provided, closing..." downstream verdict; the actual error was swallowed because `wx.wxProcess:Redirect()` captures worker stderr into a stream the GUI doesn't read.

If you tried rc1 and saw the login fail with "No INF provided, closing...", rc2 fixes it. **rc2 is the first build that actually completes a hub login.**

End-to-end test verified 2026-06-11: cert-gen → TLS handshake → OSNR login → bot auth → directory watch → release announcement via `ptx_freshstuff` on a live hub.

## ⚠️ Before installing

If you are migrating from upstream `luadch/announcer_client` or `luadch/announcer_bot`, OR from rc1, back up your existing config and state before swapping:

```sh
tar -czf "announcer-backup-$(date +%F).tar.gz" cfg log
```

The cfg directory layout is **byte-identical** to both upstream tools - `cfg.lua` / `sslparams.lua` / `hub.lua` / `rules.lua` / `categories.lua`. Drop them into the new install tree's `cfg/` directory and existing settings are picked up. The `log/announced.txt` state file (which releases were already announced) also carries over unchanged.

First-time user: no backup applies, the empty `cfg/` directory is initialised by the bundled example files.

## What's new since rc1

- [#57](https://github.com/luadch-ng/announcer/pull/57) - **`net.lua`: missing `require "adclib"`** - the critical login-crash fix. Latent since Phase 0; surfaced at first real hub login attempt against the rc1 binary.
- [#56](https://github.com/luadch-ng/announcer/pull/56) - **certs cleanup + stale GUI docs path**:
  - `Announcer.wx.lua` cert-missing error pointed at `docs/README.txt` (does not exist) - now points at `docs/USERGUIDE.md` plus names the actual scripts (`make_cert.bat` / `.sh`).
  - `certs/make_cert.bat` rewritten: dropped obsolete `RANDFILE=tmp.rnd`, dropped `uid.txt` roundtrip (now reads `openssl rand` stdout directly), variable name aligned with `.sh` (`CERT_CN`).
  - Both `.bat` and `.sh` now delete `cakey.pem` + `cacert.pem` after signing (transient CA material, no runtime use; leaving the private CA key next to the live server key on disk is bad practice).
  - Deleted legacy `certs/make_cert` (no extension, RSA-1024 one-liner; unused, no docs ref).
- [#58](https://github.com/luadch-ng/announcer/issues/58) - **ISTA tolerance in login state machine** closed as wontfix. The 95%-case (hub `usr_slots` / `usr_share` / `usr_nick_length` thresholds) is covered by the announcer's own `cfg.botslots` / `cfg.botshare` / `cfg.hub.nick` knobs; matching the BINF advertise to the target hub's thresholds at install time is the right level of abstraction. Edge cases (HN/HR/HO hardcoded to `"0"` in `net.lua`, custom hub plugins that emit ISTA 1xx welcome broadcasts pre-IGPA) stay as-is until a real user report surfaces them.
- [#59](https://github.com/luadch-ng/announcer/issues/59) - **GUI worker stderr capture** opened as follow-up. `wx.wxProcess:Redirect()` captures stderr into a stream nothing reads; any worker Lua error is silently swallowed. This made #57 very hard to diagnose. Fix is to tail-pipe worker stderr into logfile.txt. Not in rc2; landing in a follow-up.

## Highlights (carried from rc1)

### Consolidation ([Phase 0](https://github.com/luadch-ng/announcer/pull/3))

One repo, one core, two thin frontends:

- `core/` - canonical announcer code (Lua 5.4) shared by both CLI and GUI
- `frontends/cli/main.lua` - cross-platform headless entry point (Linux + Windows)
- `frontends/gui/Announcer.wx.lua` - wxLua GUI (Win32, optional)

Replaces upstream's status-file IPC between the GUI and the worker with an in-process event dispatch (`core/events.lua`).

### Lua 5.4 migration ([Phase 1](https://github.com/luadch-ng/announcer/pull/4))

Core and CLI ported from Lua 5.1 to **Lua 5.4** with the hub's vendored interpreter and deps (LuaSec 1.3.2, LuaSocket 3.1.0, LFS 1.9.0, adclib, basexx). Two upstream parser bugs surfaced and fixed by the audit. Event-dispatch (`events.lua`) wraps every listener in `pcall` so a buggy handler can't crash the loop.

### Cross-platform CMake build ([Phase 2](https://github.com/luadch-ng/announcer/pull/5))

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
cmake --install build
```

Output in `build/install/announcer/`. Same three-step pipeline on Linux and Windows. CI matrix verifies both per push.

### wxLua 3.x GUI ([Phase 3](https://github.com/luadch-ng/announcer/pull/6))

GUI was on stale wxLua 2.x. rc2 ships wxLua source in-tree, wxWidgets 3.2.10 as a git submodule, builds them via the same CMake pipeline behind `-DBUILD_GUI=ON`. Cross-platform GUI build verified in CI (upstream's GUI was Win32-only).

### Quick-wins (post-Phase-3)

Seven follow-up PRs from an upstream-issues audit:

- [#35](https://github.com/luadch-ng/announcer/pull/35) - log-spam from announce-loop idle ticks
- [#37](https://github.com/luadch-ng/announcer/pull/37) - BINF cleanup + missing `US` field for hublist pingers
- [#39](https://github.com/luadch-ng/announcer/pull/39) - hidden-file filter + per-extension max-count filter
- [#40](https://github.com/luadch-ng/announcer/pull/40) - GUI input validation for ADC-illegal characters
- [#41](https://github.com/luadch-ng/announcer/pull/41) - cert-gen `UID` env-var collision (bash builtin) + CLI usage docs
- [#43](https://github.com/luadch-ng/announcer/pull/43) - large-logfile guard
- [#44](https://github.com/luadch-ng/announcer/pull/44) - `USERGUIDE.md` for end users

Plus [#7](https://github.com/luadch-ng/announcer/issues/7) (Phase 3 Tier 3) - `status.lua` poll race between the spawned worker and the GUI poller, closed.

## What it does

Logs into an ADC hub as a registered bot account (TLS only), watches one or more local directories, and posts new release folders to the hub's main chat using the ADC **OSNR** extension. Filters support blacklist, whitelist, age caps, NFO/SFV requirements, per-extension max-count, hidden-file skipping, day-directory matching, and freshstuff-style multi-category dispatch. Per-rule custom command templates allow operator-specific announce-line formatting.

## Downloads

| File | Platform | What's included |
|---|---|---|
| `announcer-v1.0.0-rc2-linux-x86_64.tar.gz` | Linux x86_64 (glibc 2.31+) | CLI + standalone Lua runtime + bundled deps |
| `announcer-v1.0.0-rc2-windows-x86_64.zip` | Windows x86_64 | CLI + GUI + standalone Lua runtime + bundled deps |

GUI on Linux is build-only at this time (`-DBUILD_GUI=ON`); no Linux GUI binary in the release asset. Source-build users on Linux desktop can get the GUI via CMake.

## Migration from upstream

| Step | What to do |
|---|---|
| 1. Back up upstream cfg + log | `tar -czf upstream-backup.tar.gz cfg log` |
| 2. Download this release | linux-x86_64 tarball OR windows-x86_64 zip |
| 3. Drop the new tree | extract somewhere fresh, do NOT overwrite the upstream install |
| 4. Copy your cfg + log | `cp -r /path/to/upstream/cfg/* /path/to/new/announcer/cfg/`<br>`cp /path/to/upstream/log/announced.txt /path/to/new/announcer/log/` |
| 5. First run | CLI: `./announcer.sh` (Linux) or `lua.exe frontends/cli/main.lua` (Windows). GUI: double-click `Announcer.exe` (Windows) |

The on-disk format of `cfg.lua` / `sslparams.lua` / `hub.lua` / `rules.lua` / `categories.lua` is byte-identical to upstream - existing settings carry over without edits.

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

Output in `build/install/announcer/`. Full prerequisites in [`README.md`](https://github.com/luadch-ng/announcer/blob/main/README.md#building).
