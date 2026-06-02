# Operator User Guide

This guide walks an operator from "I just built the announcer" to "It's
announcing my releases to my hub". It assumes you already followed
[BUILDING.md](BUILDING.md) and have a working `build/install/announcer/`
tree.

For the build itself, see [BUILDING.md](BUILDING.md). For the protocol
basics + license, see [the README](../README.md).

---

## 1. First-run quickstart (5 minutes)

After `cmake --install build`, your `build/install/announcer/` tree
contains everything needed to run. From that directory:

```sh
# 1. Generate a TLS cert (your hub will reject plain-text connections).
#    Windows:
cd certs && make_cert.bat && cd ..
#    Linux:
cd certs && bash make_cert.sh && cd ..

# 2. Edit the four configuration files. See section 7 below for each.
#    At minimum:
#    - cfg/hub.lua    : addr / port / nick / pass / keyp
#    - cfg/rules.lua  : list of directories to watch + per-rule filters

# 3. Run.
#    CLI (Linux + Windows):
./lua frontends/cli/main.lua          # ./lua.exe on Windows
#    GUI (Linux + Windows, requires -DBUILD_GUI=ON at build):
./lua frontends/gui/Announcer.wx.lua  # ./lua.exe on Windows
```

The announcer connects to the hub, negotiates the `OSNR` SUP feature
flag, logs in as the configured nick, then enters the scan/announce
loop. New releases that match a watched rule are posted to the hub's
main chat with the rule's `command` prefix (default `+addrel`).

### Sanity check that it's working

After the first announce cycle (default 5 minutes):

- `log/logfile.txt` contains the activity trace, including each scan and
  announce decision
- `log/announced.txt` contains the names of releases the bot has already
  announced (used to dedupe across restarts)
- Your hub's main chat shows the announcer's BMSG broadcasts

If `log/announced.txt` stays empty, the filters are blocking everything;
see section 6 (Troubleshooting).

### About the auto-generated bot identity (`cfg/id.lua`)

The first time you run the announcer, `core/adc.lua` generates a fresh
ADC PID + CID pair and writes it to `cfg/id.lua`. This file is
gitignored and **per-deployment**. DO NOT copy it between announcer
instances - each bot must have its own unique identity, otherwise
two announcers on the same hub will fight over the same CID and
neither will work correctly.

If you ever need to start fresh: delete `cfg/id.lua` and the next run
generates a new pair.

---

## 2. Configuring watch rules (`cfg/rules.lua`)

Each entry in `cfg/rules.lua` is one watched directory + filters. The
default file ships with a single example rule for `Movies_1080p`. Add
more by extending the `rules` table.

### Rule structure

```lua
rules = {

    [ 1 ] = {

        [ "active" ]      = true,                  -- master toggle for this rule
        [ "path" ]        = "C:/MyReleases",       -- directory to scan
        [ "rulename" ]    = "MyMovies",            -- internal name + log tag
        [ "category" ]    = "Movies_1080p",        -- must exist in cfg/categories.lua
        [ "command" ]     = "+addrel",             -- hub-side command prefix on announce
        [ "checkdirs" ]   = true,                  -- announce subdirectories (releases as folders)
        [ "checkfiles" ]  = false,                 -- announce loose files (releases as single files)

        --// Filters
        [ "blacklist" ] = {
            [ "(incomplete)" ] = true,
            [ "(no-sfv)" ]     = true,
            [ "(nuked)" ]      = true,
        },
        [ "whitelist" ] = { },                    -- empty = allow everything not in blacklist

        [ "checkspaces" ]   = true,                -- block release names containing spaces
        [ "checkage" ]      = false,               -- enforce max-age filter
        [ "maxage" ]        = 0,                   -- maximum age in days (0 = no limit)
        [ "checkdirsnfo" ]  = false,               -- require .nfo file in release directory
        [ "checkdirssfv" ]  = false,               -- require valid .sfv file in release directory

        [ "skip_hidden" ]                = true,   -- block dot-prefix names (.git, .vscode, ...)
        [ "max_per_extension" ]          = {       -- block "dirty" bundles
            [ "nfo" ] = 1,
            [ "sfv" ] = 1,
        },
        [ "max_per_extension_recursive" ] = true,  -- include subfolders in the count

        --// Daydir scheme (auto-roll watch path by date)
        [ "daydirscheme" ] = false,
        [ "zeroday" ]      = false,

        --// Alibi check (treat any user with this nick as already-aware)
        [ "alibicheck" ] = false,
        [ "alibinick" ]  = "DUMP",

    },

}

return rules
```

### Path syntax

Use forward slashes on ALL platforms. The Win32 API accepts both `/`
and `\`, but `\` in Lua strings needs to be escaped (`\\`), and an
unescaped `\M` (e.g. in `"C:\MyReleases"`) is an invalid Lua escape
and raises an error on Lua 5.4.

```lua
-- Correct (cross-platform):
[ "path" ] = "C:/MyReleases",
[ "path" ] = "/home/user/releases",

-- Incorrect (invalid Lua escape):
[ "path" ] = "C:\MyReleases",
```

### checkdirs vs checkfiles

- `checkdirs = true` + `checkfiles = false` → announce **subdirectories**
  inside `path`. Typical scene-release layout where each release is its
  own folder (`Movie.2024.1080p-GROUP/`).
- `checkdirs = false` + `checkfiles = true` → announce **loose files**
  directly inside `path`. Useful for already-extracted single-file releases.
- Both true → announce both kinds.
- Both false → rule does nothing.

### Daydirscheme + zeroday

If your releases are organized into date-stamped subdirectories
(`MMDD`, e.g. `0601` for June 1), enable `daydirscheme = true`. The
announcer then descends into each `MMDD` directory under `path`.

`zeroday = true` restricts scanning to **today's** date directory only
(`os.date("%m%d")`). Useful for high-volume "0day" announces where you
only ever care about today's drops.

`zeroday = false` (default) scans all date-stamped subdirectories - the
filters then decide which are too old.

### Categories

`category` must reference a `categoryname` entry in `cfg/categories.lua`.
This pairing lets you have multiple rules sharing the same category
(e.g. two paths both feeding into `Movies_1080p`). The category is
included in the announce, and OSNR-aware hub scripts use it to group
the feed.

Add new categories in `cfg/categories.lua`:

```lua
categories = {

    [ 1 ] = { [ "categoryname" ] = "Movies_1080p" },
    [ 2 ] = { [ "categoryname" ] = "Movies_2160p" },
    [ 3 ] = { [ "categoryname" ] = "TV_HD" },

}

return categories
```

The GUI exposes this via the **Categories** tab so you don't have to
edit the file by hand.

---

## 3. Announce filters

A release in a watched path must pass ALL active filters before being
announced. Filters run in order; the first hit blocks. The decision is
logged with the rule's `rulename` in `log/logfile.txt`.

| Filter | Config | Behavior |
|---|---|---|
| **blacklist** | `blacklist = { ["pattern"] = true, ... }` | If the release name contains any listed substring (case-insensitive), it's blocked |
| **whitelist** | `whitelist = { ["pattern"] = true, ... }` | If non-empty, the release must contain at least one listed substring. Empty = no whitelist |
| **hidden** | `skip_hidden = true` (default) | Block names starting with `.` |
| **whitespaces** | `checkspaces = true` | Block names containing spaces (scene convention: no spaces) |
| **max age** | `checkage = true`, `maxage = N` | Block if file/folder mtime is N or more days old |
| **nfo present** | `checkdirsnfo = true` (with `checkdirs`) | Block subdirectory releases without a `.nfo` file inside |
| **valid sfv** | `checkdirssfv = true` (with `checkdirs`) | Block subdirectory releases without a `.sfv` whose listed files exist |
| **max per ext** | `max_per_extension = { ext = N }` | Block if any listed extension appears more than N times in the release (recursive by default) |

Real-world example for a movies feed:

```lua
[ "blacklist" ] = {
    [ "(incomplete)" ] = true,
    [ "(nuked)" ]      = true,
    [ ".sample" ]      = true,
    [ "subpack" ]      = true,
},
[ "whitelist" ] = {
    [ "1080p" ] = true,
    [ "2160p" ] = true,
    [ "4k" ]    = true,
},
[ "checkspaces" ]    = true,
[ "checkage" ]       = true,
[ "maxage" ]         = 7,          -- only announce releases newer than 7 days
[ "checkdirs" ]      = true,
[ "checkdirsnfo" ]   = true,
[ "checkdirssfv" ]   = true,
[ "max_per_extension" ] = {
    [ "nfo" ] = 1,
    [ "sfv" ] = 1,
},
```

This rule:
- announces only `1080p` / `2160p` / `4k` releases
- rejects `(incomplete)` / `(nuked)` / `.sample` / `subpack`
- requires both `.nfo` and valid `.sfv`
- rejects "dirty" bundles with extra `.nfo` or `.sfv` (e.g. a Sample
  folder with its own .nfo)
- rejects anything older than 7 days

---

## 4. GUI walkthrough

The GUI (`frontends/gui/Announcer.wx.lua`) wraps the same `core/`
modules as the CLI, plus a wxLua-based UI. Six tabs:

### Tab 1 - Connection

Status indicators + Connect / Disconnect / Reload buttons. The
"Connect" button spawns `frontends/gui/spawned_worker.lua` as a child
process that runs the actual `net.loop()`. Status updates flow back
via `core/status.lua` (file-IPC, updated every status event in the
worker).

### Tab 2 - Hub

Form-bound to `cfg/hub.lua`: addr / port / nick / pass / keyprint.
Save writes back to the file. The bot identity (`cfg/id.lua`) is
not editable from the GUI - it's auto-generated, see section 1.

### Tab 3 - SSL

Form-bound to `cfg/sslparams.lua`: cert/key paths, TLS protocol,
ciphers. Defaults are TLSv1.3 with the modern AEAD suites. The cert
itself is generated by `certs/make_cert.{sh,bat}`.

### Tab 4 - Rules

Add / edit / delete watched rules. The add-rule dialog enforces the
safe-name char set (letters, digits, dot, underscore, dash, parens)
- invalid characters show a status-bar hint and keep OK disabled.

### Tab 5 - Categories

Same shape as Rules, for category names. Categories must exist before
they can be selected in the rule editor.

### Tab 6 - Logfiles

Load / Clear buttons for `log/logfile.txt`, `log/announced.txt`,
`log/exception.txt`. Auto-refreshes every 60s if a file is currently
loaded (only re-reads when the file's size or mtime changed). Files
larger than 10 MB are refused to prevent the wxTextCtrl from crashing
- see section 6 for what to do then.

### Settings (top of any tab)

Form-bound to `cfg/cfg.lua` general settings: announce interval,
sleep / socket timeouts, log-rotation size, slots / share / upload
speed claims, tray-icon toggle.

---

## 5. Operations: the announce loop

Once running, the announcer loops:

1. Sleep `cfg.announceinterval` seconds (default 300 = 5 min)
2. For each `active` rule, walk `path` (and date subdirs if
   `daydirscheme`)
3. For each candidate release, apply the filter chain
4. For each passing release that isn't already in `log/announced.txt`,
   send a `BMSG` to the hub with the rule's `command` prefix and
   record in `log/announced.txt`
5. On socket error or hub disconnect, sleep `cfg.sleeptime` (default
   10s) and reconnect

Reconnect is automatic. Hub kicks (TL-bounded) honor the timeout
before reconnect.

### Log rotation

`log/logfile.txt` and `log/announced.txt` are bounded by
`cfg.logfilesize` (default 2 MB). When a write would push past the
limit, the file is truncated to 0 and a marker line is emitted. At
startup, oversized files (left over from a crash or disk-fill) are
also truncated to keep the in-memory read bounded.

For long-term log retention, configure external rotation (logrotate
on Linux, scheduled-task copy on Windows) and point the announcer
at the live file. The internal rotation is a safety floor, not a
historical archive.

---

## 6. Troubleshooting

### "Nothing announces"

Decision tree:

1. **Check `log/logfile.txt`** - every scan logs `Searching in '...'`
   for each active rule. If you don't see your rule's path, the rule
   is `active = false` or the path doesn't exist.
2. **Look for `Release: '...' blocked. | Reason: ...`** entries. If
   your release appears with a blacklist / whitelist / hidden /
   whitespaces reason, the filters caught it. Loosen the rule.
3. **Check `log/announced.txt`** - if your release name is already
   there, the bot has announced it before (or thinks it has).
   Clearing this file forces a re-announce on next cycle.
4. **Check the hub connection** - search for "Login successful" in
   `log/logfile.txt`. If the bot never connected, see "Connection
   failed" below.
5. **Verify OSNR** - if `log/logfile.txt` contains "Fail: No OSNR
   support, closing...", your hub doesn't have OSNR enabled. Luadch
   enables it by default; check your hub's cfg.

### "Connection failed" / "Login failed"

- **TLS error**: regenerate the cert (`make_cert.{sh,bat}` in the
  `certs/` directory). On Linux, ensure `bash make_cert.sh` runs
  cleanly - the script renames `UID` to `CERT_CN` to avoid the bash
  builtin collision (PR #41).
- **Keyprint mismatch**: your `cfg/hub.lua` `keyp` field must match
  the hub's TLS keyprint, OR be empty (no pinning). Get the hub's
  keyprint from its info command or its TLS cert SHA-256.
- **Wrong nick / pass**: hub-side authentication failure. The hub
  must have the bot's nick registered with the configured password.

### "Two announcers fighting" / "CID taken"

You copied `cfg/id.lua` between deployments. Delete the file on one
instance and let it regenerate - each announcer needs its own
unique ADC PID + CID.

### "GUI: File too large to load"

The Logfiles tab refuses to load files larger than 10 MB to protect
the wxTextCtrl from crashing (which would take down the whole GUI).
Click Clear on the affected file, or rotate it externally to view
newer entries. Default core rotation is 2 MB so this should normally
not happen; if it does, your `cfg.logfilesize` is set higher than
the GUI cap, or something has bypassed rotation.

### "Logs are too noisy / not noisy enough"

`cfg.logfilesize` controls how big each log file gets before
rotation. There's no log-level setting in the announcer - every
filter decision and every announce is logged. If you want quieter
logs, set `cfg.logfilesize` lower so rotation fires more often.

---

## 7. Reference

### `cfg/cfg.lua` keys

| Key | Type | Default | Purpose |
|---|---|---|---|
| `announceinterval` | int (seconds) | 300 | Scan-and-announce cycle interval |
| `botdesc` | string | "Announcer Client" | DC++ description field (DE in INF) |
| `botshare` | int (MB) | 0 | Announced share size in MB (SS in INF, multiplied by 1024² internally) |
| `botslots` | int | 0 | Announced upload slot count (SL in INF) |
| `botupload` | int (bytes/sec) | 0 | Announced max upload speed (US in INF). Some hub-side stats scripts expect non-zero |
| `freshstuff_version` | bool | true | Reserved for freshstuff-compatible announce format |
| `logfilesize` | int (bytes) | 2097152 | Max log file size before rotation |
| `sleeptime` | int (seconds) | 10 | Reconnect delay after disconnect |
| `sockettimeout` | int (seconds) | 60 | Socket timeout on hub I/O |
| `trayicon` | bool | false | GUI: minimize to system tray icon |

### `cfg/hub.lua` keys

| Key | Type | Purpose |
|---|---|---|
| `addr` | string | Hub hostname or IP |
| `port` | string | Hub port (TLS) |
| `nick` | string | Bot's registered nick on the hub |
| `pass` | string | Bot's registered password |
| `keyp` | string | TLS keyprint to pin (empty = no pinning) |
| `name` | string | Friendly hub name for the GUI / logs |

### `cfg/sslparams.lua` keys

Passed directly to `ssl.newcontext` (LuaSec):

| Key | Default | Purpose |
|---|---|---|
| `certificate` | "certs/servercert.pem" | Path to client cert |
| `key` | "certs/serverkey.pem" | Path to client private key |
| `protocol` | "tlsv1_3" | TLS version (tlsv1_3 only since OpenSSL 1.1.1+) |
| `mode` | "client" | LuaSec context mode |
| `ciphers` | "HIGH" | Pre-1.3 cipher suite name |
| `ciphersuites` | TLS-1.3 AEAD list | TLS-1.3 cipher suite list |

### `cfg/rules.lua` per-rule keys

See section 2 for the full per-rule table layout.

### `cfg/categories.lua`

Flat list of `{ categoryname = "..." }` entries.

### `cfg/id.lua` (auto-generated, gitignored)

```lua
id = { }
id.pid = '...'  -- bot's ADC PID (tiger-hash secret)
id.cid = '...'  -- bot's ADC CID (derived from PID)
```

Generated by `core/adc.lua` on first run when the file is missing.
DO NOT commit this file. DO NOT copy between deployments.

---

## See also

- [BUILDING.md](BUILDING.md) - build prerequisites + recipe
- [README](../README.md) - project overview, requirements, OSNR
  primer, license
- [GitHub issues](https://github.com/luadch-ng/announcer/issues) -
  open bugs and feature requests
