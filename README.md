# Luadch-NG Announcer

[![License: GPL v3](https://img.shields.io/badge/license-GPLv3.0-blueviolet.svg)](LICENSE)

Luadch-NG Announcer is a release announcer for [Luadch](https://github.com/luadch-ng/luadch) hubs. It logs into an ADC hub as a registered bot account (TLS only), scans configured local directories, and posts new release folders to the hub's main chat via the ADC **OSNR** extension.

This project consolidates two stale upstream tools - [`luadch/announcer_client`](https://github.com/luadch/announcer_client) (Win32 wxLua GUI, last release 2022) and [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot) (Win32 headless CLI, last release 2022) - into a single tree with one shared core and two thin frontends (CLI + GUI).

## Features

- Cross-platform CLI and Windows GUI frontends
- Scans local directories for new release folders
- Posts announcements to ADC hubs via the OSNR extension
- Supports configurable blacklisting, whitelisting, and filtering
- Logs activity to local files (logfile.txt and announced.txt)
- Secure TLS-only hub connections
- Modular and extensible design

## Requirements

- **Hub** must be a Luadch (or compatible) ADC hub with the **OSNR** protocol extension.
- **Hub account** must be a registered nick (not a guest).
- **TLS** is mandatory - no plain-text fallback.
- [**ptx_freshstuff**]([https://github.com/luadch-ng/luadch](https://github.com/luadch-ng/scripts/tree/master/scripts/ptx_freshstuff)) installed

## Configuration

Edit these files under `cfg/` after a successful build. Each is a Lua
file that returns a table; comments inline explain each field. For a
full walkthrough (rules + filters + troubleshooting) see
[`docs/USERGUIDE.md`](docs/USERGUIDE.md).

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
