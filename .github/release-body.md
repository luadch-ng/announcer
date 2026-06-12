# Luadch-NG Announcer v1.0.0-rc3

Third pre-release of the consolidated `luadch-ng/announcer` tree (replaces upstream [`luadch/announcer_client`](https://github.com/luadch/announcer_client) + [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot), both stale since 2022).

## ⚠️ Why you want rc3 over rc2

rc3 is a stabilisation + UX pass on rc2. Four concrete changes:

1. **First-run TLS certs are now auto-generated.** Previously the operator had to run `certs/make_cert.bat` / `certs/make_cert.sh` once before the first connect. rc3 shells out to OpenSSL automatically when `certs/servercert.pem` / `serverkey.pem` are missing. Mirrors the hub's first-boot cert behavior. Falls back to the manual hint only when OpenSSL is not on PATH.
2. **GUI tray exit no longer crashes.** Right-click tray → Exit on rc2 triggered a `wincmn.cpp(473)` wxWidgets assertion dialog. rc3 fixes the wxLua 3.x handler-lifetime + tray-popup-vs-frame-destroy interaction. Restore-from-tray (left-click on tray icon while window minimised) also works again.
3. **Worker stderr is captured into `log/logfile.txt`.** Pre-rc3, if the spawned GUI worker died with an uncaught Lua error, the diagnostic was swallowed (the GUI redirected stderr into a stream it never read). rc3 drains stderr at process-end into the logfile + surfaces it in the GUI log window in red. The next silent worker crash is diagnosable instead of needing 30 minutes of sleuthing.
4. **GUI cosmetics:** TLS RadioBox no longer truncates "TLSv1.3" under wxLua 3.x; Luadch-NG branded icon embedded in `Announcer.exe` so the Windows taskbar / Alt-Tab / Explorer shell shows the right logo; About window picks up a `Maintained since 2026 by Aybo` line + clickable repo URL.

End-to-end test still verified on the upstream hub-side ptx_freshstuff plugin (rc2 verification carries forward unchanged - rc3 doesn't touch the announce protocol path).

## ⚠️ Before installing

If you are migrating from upstream `luadch/announcer_client` or `luadch/announcer_bot`, or from rc1 / rc2, back up your existing config and state before swapping:

```sh
tar -czf "announcer-backup-$(date +%F).tar.gz" cfg log
```

The cfg directory layout is **byte-identical** to all upstream + earlier rc versions - `cfg.lua` / `sslparams.lua` / `hub.lua` / `rules.lua` / `categories.lua`. Drop them into the new install tree's `cfg/` directory and existing settings are picked up unchanged. The `log/announced.txt` state file (which releases were already announced) also carries over.

First-time user: no backup applies. With rc3, the cert is generated automatically on the first `lua.exe frontends/cli/main.lua` or first `Announcer.exe` launch (provided `openssl` is on PATH).

## What's new since rc2

- [#65](https://github.com/luadch-ng/announcer/pull/65) - **TLS RadioBox overflow + missing Windows .exe icon + About refresh (closes #63)**:
  - "TLSv1.3" radio item no longer truncates to "TLSv1." under wxLua 3.x. Outer box width stays at 100 px, the `wxSUNKEN_BORDER` style is dropped to recover the ~6-8 px of inner padding wxLua 3.x added.
  - Luadch-NG branded `applogo.ico` (multi-resolution 16/32/48/96/256) embedded into `Announcer.exe` via a new `frontends/gui/announcer.rc` + CMake `enable_language(RC)`. Windows taskbar / Alt-Tab / Explorer now show our logo instead of the generic GUI-exe glyph.
  - About window adds `Maintained since 2026 by Aybo` + a clickable `https://github.com/luadch-ng` link (`wxHyperlinkCtrl`); dialog height bumped 505 → 545 to accommodate.
  - All three runtime PNG sizes (`applogo_16x16/32x32/96x96.png`) refreshed with the new branding.
- [#66](https://github.com/luadch-ng/announcer/pull/66) - **GUI worker stderr capture (closes #59)**: on the `wxEVT_END_PROCESS` event the GUI now drains the spawned worker's stderr + stdout into `log/logfile.txt` with a `[worker stderr]` / `[worker stdout]` prefix; stderr lines also appear in the GUI log window in red. The pre-fix swallow caused the rc1 → rc2 adclib crash to be invisible to anyone looking only at the GUI; rc3 surfaces the next one.
- [#67](https://github.com/luadch-ng/announcer/pull/67) - **First-run TLS cert auto-generation (closes #62)**: new `core/cert_autogen.lua` module shells out to `openssl` to produce `certs/servercert.pem` + `certs/serverkey.pem` when either is missing. Mirrors `certs/make_cert.{bat,sh}` exactly (EC prime256v1 + single-use CA + 10-year validity, transient CA artefacts cleaned up post-signing). Hooked at module-load in `core/net.lua` (catches CLI + GUI worker) AND at GUI startup in `validate.cert` (silent regeneration instead of the legacy "please generate manually" error). Falls back to the operator-action hint only when `openssl` is unavailable.
- [#64](https://github.com/luadch-ng/announcer/pull/64) - **Tray exit crash + restore-from-tray (closes #61)**: three concrete fixes around the wxLua 3.x tray menu interaction:
  - `HandleAppExit` cleanup order reordered (worker → timer → taskbar → notebook_image_list → frame). Pre-fix did `frame:Destroy()` FIRST and tripped `~wxWindowBase` because the taskbar / timer handlers outlived the frame.
  - Tray Exit menu binding routed through `frame:Close(false)` + a 1 ms `wxTimer` defer. wxMSW's tray popup pushes an event handler onto the frame for the menu's lifetime; calling close synchronously from inside the menu's callback tripped the same assertion. The deferred timer lets the menu handler return cleanly, the pushed handler pops, then close runs in a clean stack.
  - Tray left-click restore reads `frame:IsIconized()` once and branches explicitly. Pre-fix's toggle-then-re-query pattern hit the event-queue-not-yet-processed race so the restore branch never fired and the window stayed hidden.

## Highlights (carried from rc1/rc2)

### Consolidation, Lua 5.4, CMake, wxLua 3.x

- One repo, two thin frontends (`frontends/cli/main.lua` + `frontends/gui/Announcer.wx.lua`), one shared `core/`
- Lua 5.1 → 5.4 with hub-vendored interpreter + deps (LuaSec 1.3.2, LuaSocket 3.1.0, LFS 1.9.0, adclib, basexx)
- Cross-platform CMake build (`cmake -B build && cmake --build build && cmake --install build`)
- wxLua 3.x + wxWidgets 3.2.10 vendored, cross-platform GUI build verified in CI

### Test surface

Smoke test runs on every push: validates the CMake pipeline produces a working binary on Linux and Windows. GUI builds also verified on both platforms. rc3 extends the smoke to verify cert_autogen via a `Certificates verified at` sentinel grep on `log/logfile.txt`.

## What it does

Logs into an ADC hub as a registered bot account (TLS only), watches one or more local directories, and posts new release folders to the hub's main chat using the ADC **OSNR** extension. Filters support blacklist, whitelist, age caps, NFO/SFV requirements, per-extension max-count, hidden-file skipping, day-directory matching, and freshstuff-style multi-category dispatch. Per-rule custom command templates allow operator-specific announce-line formatting.

## Downloads

| File | Platform | What's included |
|---|---|---|
| `announcer-v1.0.0-rc3-linux-x86_64.tar.gz` | Linux x86_64 (glibc 2.31+) | CLI + standalone Lua runtime + bundled deps |
| `announcer-v1.0.0-rc3-windows-x86_64.zip` | Windows x86_64 | CLI + GUI + standalone Lua runtime + bundled deps |

GUI on Linux is build-only at this time (`-DBUILD_GUI=ON`); no Linux GUI binary in the release asset. Source-build users on Linux desktop can get the GUI via CMake.

## Migration from upstream

| Step | What to do |
|---|---|
| 1. Back up upstream cfg + log | `tar -czf upstream-backup.tar.gz cfg log` |
| 2. Download this release | linux-x86_64 tarball OR windows-x86_64 zip |
| 3. Drop the new tree | extract somewhere fresh, do NOT overwrite the upstream install |
| 4. Copy your cfg + log | `cp -r /path/to/upstream/cfg/* /path/to/new/announcer/cfg/`<br>`cp /path/to/upstream/log/announced.txt /path/to/new/announcer/log/` |
| 5. First run | CLI: `./announcer.sh` (Linux) or `lua.exe frontends/cli/main.lua` (Windows). GUI: double-click `Announcer.exe` (Windows). Cert auto-generated if missing. |

The on-disk format of `cfg.lua` / `sslparams.lua` / `hub.lua` / `rules.lua` / `categories.lua` is byte-identical to upstream - existing settings carry over without edits.

## How to report issues

Open an issue at https://github.com/luadch-ng/announcer/issues with:

- Platform (Linux distro / Windows version)
- Frontend (CLI / GUI)
- Steps to reproduce
- Relevant lines from `log/logfile.txt` (including any `[worker stderr]` lines from the #59 capture)

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

Output lands in `build/install/announcer/`. Full prerequisites in [`README.md`](https://github.com/luadch-ng/announcer/blob/main/README.md#building).
