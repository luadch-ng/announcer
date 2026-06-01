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

lib/               Bundled deps (Phase 0 = Win-only binaries)
  basexx/          Pure-Lua base32/base64 (cross-platform).
  luasec/          TLS - .dll + Lua source.
  luasocket/       TCP/UDP - .dll + Lua source.
  adclib/          ADC tiger-hash - .dll.
  lfs/             LuaFileSystem (CLI path) - .dll.
  lfs_wx/          LuaFileSystem (GUI path) - .dll.
  unicode/         Unicode utf-8 shim - .dll (Win-only Phase 0).
  ressources/      GUI icon/resource .dll bundles. lib/ressources/
                   README.md documents provenance + Phase 2 plan to
                   replace with sourced-from-PNG resource loading.

certs/             OpenSSL cert-generation scripts (.bat + .sh)
log/               Runtime logs (gitignored except .gitkeep)
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

### Phase 1 - Lua 5.4 migration [IN PROGRESS]

Goal: core + CLI on Lua 5.4 (matches hub).

PR-A (this PR, "lib bump + source migration + parser bug fixes"):
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

PR-B (queued): events.lua pcall safety wrap around handler dispatch.

PR-C (queued): GUI integration. Wire `events.on("status", ...)` to
a handler that writes `core/status.lua` so the existing GUI worker
keeps working in-process.

Phase 2 (separate, queued): adopt hub's CMake 1:1 + cross-platform
CI matrix. Build `.so`/`.dylib` for adclib/luasec/luasocket/lfs/
unicode-shim. Replace `lib/ressources/*.dll` opaque resource bundles
with sourced-from-PNG resource loading.

### Phase 2 - Cross-platform CLI [QUEUED, no fixed timeline]

Goal: real Linux + Windows CLI via CMake + CI matrix.

- Adopt hub's CMake pipeline (currently the .dlls are pulled from
  the hub's build artifacts; Phase 2 builds them in-tree).
- Ship `.so` / `.dylib` alongside the existing `.dll` for
  luasec / luasocket / adclib / lfs / unicode-shim.
- Replace `lib/ressources/*.dll` opaque resource bundles with
  sourced-from-PNG resource loading at runtime.
- GitHub Actions matrix for build + smoke on Linux + Windows.

### Phase 3 - GUI on Lua 5.4 [QUEUED, highest risk]

wxLua 2.8 is from 2014 and Lua-5.1-only. Modern wxLua 3.x may or
may not have stable 5.4 bindings - investigate first. Worst case:
GUI stays on a separate Lua-5.1 sandbox while CLI/core run on 5.4;
or GUI is rewritten in something else. This phase is isolated as
last so CLI/core deliver value independently even if the GUI lags.

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
- **Default branch is `main`**, not `master`. `gh pr create
  --base master` errors with "Base ref must be a branch". Use
  `--base main`. Lesson from Phase 0.
- **`cfg/id.lua` must never be committed** - it is the bot's
  tiger-hash PID (CID derived). Already in `.gitignore` from Phase 0;
  if anyone removes the entry, security review fails.
- **`lib/` binary provenance**: never add a new binary blob to lib/
  without updating `lib/ressources/README.md` (or sibling) with
  upstream source + sha256 + purpose. Unaudited blobs in the repo
  history are a security smell.
- **Local Lua-syntax check** before push:
  ```
  C:\lua-5.4.8_Win64_bin\lua54.exe -e "local f, e = loadfile([[core/net.lua]]); print(f and 'OK' or e)"
  ```
  Faster than going through review for a syntax bug.

---

## 7. First-time setup (operator-side, Windows, Phase 0)

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
   lua frontends/cli/main.lua
   ```
   (Or build the GUI `Announcer.exe` via wxluafreeze.)

Linux / macOS: Phase 2 work.
