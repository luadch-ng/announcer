# CLAUDE.md

Context for Claude Code (and any AI assistant) working on the
`luadch-ng/announcer` repo. Read this before making changes - it captures
the working agreement, layout, and phasing that span sessions.

User communication is in **German**; all written artifacts (this file,
code, comments, commits, PRs, issues) stay in **English** so other
contributors can read them.

This file inlines the working-agreement rules from the parent
`luadch-ng/luadch` repo's CLAUDE.md. Keep the two in sync when rules
change upstream.

---

## 1. Working agreement (non-negotiable)

### 1a. Per-change discipline (every PR, no size exemption)

1. **Security and consistency come first.** Treat any change touching
   the ADC protocol (BINF/HSUP/GPA/HPAS/BMSG/OSNR), TLS setup
   (sslctx, keyprint verification), or the events dispatch as
   security-sensitive. When fixing a pattern in one place, grep for
   the same pattern across the repo and fix it everywhere - divergent
   code paths are a defect.
2. **No spaghetti.** Prefer small, focused functions. `core/net.lua`
   is the elephant (the full ADC state-machine in one loop); if new
   logic doesn't have an obvious home, propose a new module before
   growing it further.
3. **Deep-dive before implementation.** Analyse the issue from the
   source outward before writing code, even when it costs more
   tokens. Cross-check against the ADC spec and the upstream
   client/bot reference at `d:\Projekte\announcer_client_upstream` /
   `d:\Projekte\announcer_bot_upstream`. Do NOT modify the upstream
   clones - they are read-only reference.
4. **An issue/plan is a hypothesis, not ground truth.** Always
   re-derive from current source + spec. If the plan is wrong,
   correct the plan; do not implement the wrong thing.
5. **Verify every assumption** against the current code/spec before
   building on it. Recalled memory and old docs are point-in-time;
   confirm before relying.
6. **Mandatory two-pass pre-merge review.** Before any merge -
   regardless of how small the diff - run: (a) an independent
   reviewer (subagent / fresh perspective) and (b) a maintainer-side
   spot-check. Covers security, new bugs, breaking behaviour,
   consistency. The Phase 0 review caught a real secret leak
   (`cfg/id.lua` not gitignored) that would have shipped the bot's
   PID/CID secret on first run.
7. **Regression tests must provably fail pre-fix.** A test green on
   both old and new code proves nothing. For every fix, demonstrate
   the new test FAILS on the unpatched code and PASSES patched.
   This repo has no test harness yet (Phase 1+ scope); for now,
   manual smoke at hub-install time. Even without a harness, the
   fix description must demonstrate that the failure reproduces
   on the unpatched code (e.g. "before this PR, sending an INF
   with no PD field crashes at line X with error Y").
8. **Small reviewable PRs.** One logical change per PR. The
   initial-import is the only exception (by definition).
9. **No wall of text.** Chat answers, issues, PR bodies, release
   notes: minimal, technical, complete - result first. Detail
   belongs in code comments or this file, not in summaries.

### 1b. Phase discipline

10. **One phase at a time** (see §4). Don't pull tickets forward from
    a later phase even if they look trivial.
11. **Review gate between phases.** Before declaring a phase
    complete: security audit (TLS / ADC protocol / file paths) +
    consistency audit + smoke build per supported platform.
12. **Fix-then-advance.** Anything found in the gate must be fixed
    before the next phase begins. No "we'll get back to it." If
    something is genuinely out of scope, open a tracking issue.

When uncertain whether a change fits the current phase, stop and ask
the maintainer.

---

## 2. Project overview

luadch-ng/announcer is a **scene/warez release announcer** for
[Luadch](https://github.com/luadch-ng/luadch) ADC hubs. Logs into a
hub as a registered bot account (TLS only), scans configured local
directories, posts new release folders to the hub's main chat via the
ADC **OSNR** extension. Dir-scan filters: blacklist, whitelist, NFO,
SFV, max-age, daydir, freshstuff-categories.

NOT a hublist/registration tool. Do NOT confuse with the
`etc_regserver_announce.lua` plugin in `luadch-ng/luadch`, which
registers the hub TO hublists - completely different concern.

- **Current version:** `v1.0.0-dev` on `main` (the default branch is
  `main`, NOT `master` - lesson from Phase 0).
- **Latest release:** none yet; Phase 0 just shipped (PR #1, commit
  `622dbbe`, 2026-05-30).
- **License:** GPL-3.0.

Origins (preserved in source headers):
- pulsar + jrock - original Win32 GUI ([`luadch/announcer_client`](https://github.com/luadch/announcer_client), 2014-2022, stale).
- blastbeat - original headless bot ([`luadch/announcer_bot`](https://github.com/luadch/announcer_bot), 2014-2022, stale).
- luadch-ng org (this repo) - consolidation, 2026.

---

## 3. Architecture

```
core/              Canonical announcer core (shared by CLI + GUI)
  init.lua         Bootstrap: package.path + dofile chain. Does NOT
                   auto-run net.loop() (that was the upstream pattern);
                   the active frontend invokes it.
  const.lua        Paths + PROGRAM_NAME + _VERSION.
  events.lua       In-process event dispatch (events.on / .emit /
                   .clear). Replaces upstream's file-IPC pattern
                   where set_status(file, k, v) serialised
                   core/status.lua repeatedly per state update.
  log.lua          Two-file logger (logfile.txt + announced.txt).
  adc.lua          ADC PID/CID helpers. Generates cfg/id.lua on
                   first run - that file IS the bot's tiger-hash
                   secret. Already in .gitignore from Phase 0.
  announce.lua     Directory-scan + filter logic.
  net.lua          Connect + login + announce loop (TLS, OSNR).
                   ADC state-machine: HSUP, BINF, GPA, HPAS,
                   announce-broadcast, keepalive. 28 events.emit(
                   "status", ...) call sites for state updates.
  util.lua         Table serialise / loadtable / savetable /
                   formatbytes.

cfg/               Per-install configuration (operator edits)
  cfg.lua          Bot settings (interval / sleeptime / ...).
  sslparams.lua    LuaSec ssl.newcontext params.
  hub.lua          Hub addr / nick / pass / keyprint.
  rules.lua        Watched directories + per-rule command + filters.
  categories.lua   Category metadata for freshstuff multi-cat.

frontends/
  cli/main.lua     Standalone headless entry. Drives net.loop() in
                   a reconnect loop with explicit cfg.sleeptime
                   backoff between iterations (the upstream bot
                   hot-spinned on post-login fatal; the new code
                   guards against it).
  gui/Announcer.wx.lua  wxLua GUI (Win32 only). Inherited verbatim
                   from upstream for Phase 0. The GUI's spawned
                   worker still relies on file-IPC (core/status.lua),
                   so until a handler is registered for
                   events.emit("status", ...), status updates are
                   silent. GUI integration with the events dispatch
                   is Phase 0 follow-up / Phase 1 work.

--- C-extension sources (vendored, Phase 2) ---
lua/src/           Lua 5.4 stdlib (vendored from hub). Builds lua.dll
                   + lua.exe via CMakeLists.txt (standalone interpreter
                   is announcer-specific; hub embeds Lua in Luadch.exe).
adclib/            ADC tiger-hash + base32 + escape (vendored from hub).
luasec/            TLS C extension (vendored from hub, upstream LuaSec 1.3.2).
luasocket/         TCP/UDP C extension (vendored from hub, upstream LuaSocket 3.1.0).
lfs/src/           LuaFileSystem source (vendored from upstream
                   lunarmodules/luafilesystem v1.9.0; hub doesn't bundle).

--- Pure-Lua sources (vendored, Phase 2) ---
basexx/            Pure-Lua base32/base64 (vendored from hub).
slnunicode/        Pure-Lua utf-8 shim (vendored from hub; replaced the
                   unmaintained slnunicode C module).

--- Runtime artefacts (NOT committed; produced by CMake build) ---
build/install/announcer/ default install root (cmake --install
                   destination). Contains lua.exe + lua.dll + OpenSSL
                   DLLs + the runtime tree (core/ cfg/ frontends/ certs/
                   log/ + lib/<dep>/<artefact>).

--- GUI assets ---
lib/ressources/png/*.png  App icon (3 sizes) + GPL badge + 5 tab icons.

certs/             OpenSSL cert-generation scripts (.bat + .sh).
log/               Runtime logs (gitignored except .gitkeep).

CMakeLists.txt     Top-level build orchestration. Vendored sources +
                   per-dep CMakeLists in their subdirs follow the hub's
                   pattern 1:1. See docs/BUILDING.md for the build recipe.
```

---

## 4. Phasing

Each phase ends with the §1b review gate. Don't start Phase N+1 until
Phase N is reviewed and clean.

### Phase 0 - Consolidation [SHIPPED 2026-05-30, PR #1]

Goal: one repo, one core, two frontends, still Lua 5.1.

Delivered: client's superset core kept as canonical; bot's cross-
platform filetype detect adopted; `core/events.lua` replaces file-IPC
for status; `net.lua` no longer auto-runs (frontends invoke); new
`frontends/cli/main.lua` with backoff guard; GUI moved verbatim;
`cfg/id.lua` secret leak fixed in .gitignore; provenance docs for
bundled binaries.

### Phase 1 - Lua 5.4 migration [SHIPPED 2026-06-01]

Goal: core + CLI on Lua 5.4 (matches hub).

PR-A (PR #3, merged 2026-06-01 as commit `838501a`, "lib bump +
source migration + parser bug fixes"):
- Lib bump: all hub-available deps swapped to hub's 5.4-built
  versions (adclib, basexx, luasec ssl, luasocket socket/mime/
  ltn12/mbox, unicode shim). Dead Lua source dropped (luasec
  https/options, luasocket ftp/headers/http/smtp/tp/url) - never
  required by announcer code per the require audit.
- lfs.dll: built from upstream `lunarmodules/luafilesystem` source
  against the hub's `lua.dll` (v1.9.0). Cross-platform .so/.dylib
  is Phase 2.
- Runtime bundling: `lua.exe`, `lua.dll`, `libcrypto-3-x64.dll`,
  `libssl-3-x64.dll` shipped at repo root so operators don't need
  a separate Lua 5.4 install. Whitelisted in `.gitignore`.
- Source migration: `loadstring( ... )` -> `load( ... )` in
  `core/util.lua` (the only Lua-5.1-incompatible idiom in the
  codebase; setfenv/getfenv/unpack/module were already absent).
- Parser-bug fixes (the 2 TODO(phase-1) markers from Phase 0):
  - `buf:find( "CT4" or "CT8" or "CT16" or "OP1" )` now expanded
    to a proper or-chain of `buf:find()` calls; CT8/CT16/OP1
    branches are no longer dead.
  - `tonumber( cfg.sleeptime ) or 10 .. " seconds..."` now
    parenthesised via a hoisted local `_sleep`; sleeptime-nil
    fallback no longer corrupts the sleep arg.

PR-B (PR #4, merged 2026-06-01 as commit `610e12c`, "events.lua
pcall safety wrap"): handler dispatch in `events.emit` is now
pcall-guarded; a handler that throws is logged and the chain
continues. Tested side-by-side pre/post-fix: a middle handler
erroring would previously kill subsequent handlers, now they run.

PR-C (PR #5, merged 2026-06-01 as commit `4afdae1`, "GUI integration
via events.on"): new `frontends/gui/spawned_worker.lua` registers
`events.on("status", ...)` -> writes `core/status.lua` for the
wxLua GUI's poller. The GUI's `start_process()` now spawns the
bundled `lua.exe` + the worker script via `wx.wxExecute`,
replacing the upstream's `lib/ressources/client.dll` wxluafrozen
Lua-5.1 bundle (deleted in PR-C as orphaned). PR-C also fixed the
stale `integrity_check` table in `Announcer.wx.lua` (latent
broken since PR-A; 11 stale entries removed, 5 new entries added)
and added quote-hazard / empty-cwd guards on the `wxExecute` cmd.

Phase 1 review gate (CLAUDE.md §1b) passed 2026-06-01: cumulative
security / consistency / smoke audit across all 3 PRs returned 0
blockers + 6 nits, all addressed inline or tracked for later
phases.

### Phase 2 - CMake + cross-platform CLI [SHIPPED 2026-06-01]

Goal: real Linux + Windows CLI via in-tree CMake + CI matrix.

PR-A (this PR, "CMake scaffold + vendor C deps + Windows in-tree build"):
- Vendor C sources from hub: `lua/src`, `adclib`, `luasec`,
  `luasocket`. Vendor pure-Lua helpers: `basexx`, `slnunicode`.
  Vendor `lfs/src` from upstream `lunarmodules/luafilesystem` v1.9.0.
- Top-level `CMakeLists.txt` adopting hub's CMake pattern 1:1; per-dep
  `CMakeLists.txt` in each vendored source dir (hub's verbatim where
  possible). Announcer-specific addition: standalone `lua.exe` build
  target in `lua/src/CMakeLists.txt` (hub embeds Lua in Luadch.exe;
  the announcer needs a separate interpreter for the CLI / GUI worker).
- Install layout matches Phase 1's bundled layout exactly: `lua.exe` +
  `lua.dll` + OpenSSL DLLs at root, `lib/<dep>/<artefact>` for C deps,
  pure-Lua helpers under `lib/basexx/` + `lib/unicode/`, runtime trees
  for `core/` `cfg/` `certs/` `frontends/`. `cfg/id.lua` excluded via
  CMake PATTERN exclude to avoid leaking the bot secret if a dev tree
  has one from local smoke-testing.
- All previously-committed binaries (`lua.exe`, `lua.dll`, OpenSSL DLLs,
  `lib/{adclib,lfs,luasec,luasocket}/*.dll`, `lib/{basexx,unicode}/*.lua`)
  removed from source tree; they are now build outputs.
- Workflow change: `git clone` no longer ships a runnable announcer.
  Operator runs `cmake -B build && cmake --build build && cmake
  --install build` first. PR-C (CI) will publish release zips with
  pre-built artefacts for end users.
- `docs/BUILDING.md` (NEW): full build recipe + prerequisites
  (MinGW + OpenSSL 3.0+ on Windows; gcc + libssl-dev on Linux).
- `BUNDLED.md` restructured: now documents in-tree vendor provenance +
  per-dep sync policy, not committed binary blobs.

PR-B + PR-C (this PR, "GitHub Actions matrix: Linux + Windows
build, smoke, release"):
- `.github/workflows/smoke.yml` builds on `ubuntu-latest` and
  `windows-latest` (msys2 UCRT64) on every push + PR. Verifies the
  install layout shape (lua.exe / lua.dll / lib/<dep>/<artefact>
  present, cfg/id.lua NOT present), then runs a bootstrap-chain
  smoke: dofile core/init.lua from the install dir + assert the
  expected ssl.newcontext failure path. Catches ABI mismatches and
  CMake install regressions.
- `.github/workflows/release.yml` builds on tag push (`v*`) and on
  `release/*` branch push (dry-run), packages
  `announcer-<tag>-linux-x86_64.tar.gz` +
  `announcer-<tag>-windows-x86_64.zip`, attaches both as GitHub
  release assets for end users who want no-build artefacts.
- Linux portability of the vendored CMakeLists is verified by the
  smoke matrix (PR-B's original "Linux build verification" goal).
  Hub's CMake builds cleanly on Linux today; the announcer's
  vendor-1:1 inherits that portability.

PR-D (queued): the 2 TODO(phase-2) source markers in `core/init.lua`
(`./lib/...` cpath anchoring vs CWD; drop dead `lib/jit/?.lua` path).

PR-E (queued): replace `lib/ressources/{res1,res2}.dll` opaque GUI
resource bundles with sourced-from-PNG resource loading at runtime.

### Phase 3 - GUI on Lua 5.4 [SHIPPED Tier 1+2 on 2026-06-01/02]

Tier 1 (#16): Announcer.wx.lua ported from the wxLua-2.8 API to
wxLua 3.x (filetype-detect fix, drop `lib/jit` dead path, PNG icon
migration replacing the upstream PE-icon-container .dll blobs,
wxBitmap-construction anti-patterns, wxTE_PROCESS_ENTER flag, etc.).
TLS-mode RadioBox trimmed to TLSv1.3 only (luadch-ng is TLSv1.3-only
by design).

Tier 2 (#18 + #19 + #20 + #21): vendored wxWidgets 3.2.10 (git
submodule) + wxLua source (in-tree from OneLuaPro/wxlua fork), wired
into the same CMake pipeline behind `-DBUILD_GUI=ON`. wx.dll links
against our existing lua.dll (no static-link duplication). MinGW
runtime DLLs bundled at install root on Windows. RPATH set so wx.so
can find the wxGTK libs at install root on Linux. CI matrix coverage
for the GUI build on both Linux + Windows; runtime smoke uses
xvfb-run on Linux for the headless DISPLAY.

Tier 3 (optional, [#7](https://github.com/luadch-ng/announcer/issues/7)):
status.lua poll race window via in-process events (now feasible
because GUI + worker share lua.dll).

---

## 5. External state & memory

- **GitHub issues**: this repo doesn't have a backlog yet. Phase 1
  work will create issues as needed.
- **Auto-memory**: Claude's per-user store has `project-announcer-
  consolidation` (the closed-Phase-0 record + 7 durable patterns).
- **Upstream clones** (read-only reference, do NOT modify):
  `d:\Projekte\announcer_client_upstream`,
  `d:\Projekte\announcer_bot_upstream`.

---

## 6. Conventions for changes

- **Commit style**: match `git log` - concise, imperative, optional
  `fix #NNN` trailer.
- **PR scope**: one logical change per PR. For multi-tier work,
  reference the tracker with `Part of #N` (NEVER `Closes #N` on a
  multi-tier tracker - GitHub auto-closes the whole tracker on
  squash-merge).
- **Lua style**: match the file you're editing (the upstream client
  used 4-space indent; the bot used 2-space - preserve per-file).
- **Comments**: explain *why*, not *what*. Don't restate code.
- **No drive-by refactors**. If you spot something during an
  unrelated change, open an issue or add a `TODO(phase-N)` marker
  instead of fixing it inline.
- **No em-dashes anywhere.** Use `-` in all written output: chat,
  commits, PRs, issues, docs.

### Tooling gotchas

- **Pin `gh` to the repo**: `gh ... --repo luadch-ng/announcer`.
- **Default branch is `main`**, not `master`. Lesson from Phase 0.
- **`cfg/id.lua` must never be committed** - it is the bot's tiger-
  hash PID (CID derived). In `.gitignore` from Phase 0 (parsing fix
  Phase 1); CMake `install(DIRECTORY cfg/ ...)` also excludes it via
  PATTERN.
- **CMake build (Phase 2+)**: needs `OPENSSL_ROOT_DIR` set on Windows
  (flat-layout path or msys2-style with bin/ underneath both work).
  MinGW + OpenSSL 3.0+ are required. See `reference-windows-toolchain`
  in auto-memory for Aybo's machine setup.
- **Vendored C-source sync from hub**: when the hub updates one of
  `adclib`/`luasec`/`luasocket`/`lua/src`/`basexx`/`slnunicode`, an
  announcer follow-up PR mirrors the change + re-runs the build +
  documents the sync date in `BUNDLED.md`. Avoid drift.
- **`lib/` runtime artefacts** (`adclib.dll`, `lfs.dll`, `wx.dll`,
  wxWidgets DLLs, MinGW runtime DLLs, etc.) are NOT committed; they're
  CMake outputs. The repo carries only `lib/ressources/png/` (PNG
  assets). New binary blobs need `BUNDLED.md` provenance.
- **Local Lua-syntax check** before push (using the CMake-built
  lua.exe in the install dir):
  ```
  build/install/announcer/lua.exe -e "local f, e = loadfile([[core/net.lua]]); print(f and 'OK' or e)"
  ```
  Faster than going through review for a syntax bug.

---

## 7. First-time setup (operator-side, Windows, Phase 2)

After Phase 2 the announcer ships **source-only**. Build via the
in-tree CMake pipeline (see [`docs/BUILDING.md`](docs/BUILDING.md) for
prerequisites + full details). Three-step recipe:

```
cmake -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=C:/OpenSSL
cmake --build build -j
cmake --install build
```

Output lands at `build/install/announcer/`. From there:

1. Generate a TLS cert:
   ```
   cd certs/
   make_cert.bat   # OpenSSL must be on PATH
   ```
   Or use [luadch-ng/certmanager](https://github.com/luadch-ng/certmanager).
2. Edit `cfg/hub.lua` (addr / nick / pass / keyprint).
3. Edit `cfg/rules.lua` (which directories to scan).
4. Run:
   ```
   lua.exe frontends/cli/main.lua          # CLI
   lua.exe frontends/gui/Announcer.wx.lua  # GUI (needs -DBUILD_GUI=ON at configure)
   ```

Linux: Phase 3 Tier 2c verified - same `cmake -B build` + `--build`
+ `--install` chain, no MinGW runtime bundle needed (system libgcc /
libstdc++). GUI needs `libgtk-3-dev` at build time.

macOS: untested. Source compiles in principle; the wxWidgets build
requires Cocoa headers (Xcode SDK) and additional wxLua macOS
binding files we vendored from OneLuaPro's master. Real work for a
future phase.
