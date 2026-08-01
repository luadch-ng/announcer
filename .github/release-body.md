# Luadch-NG Announcer v1.0.0-rc4

Fourth pre-release of the consolidated `luadch-ng/announcer` tree (replaces upstream [`luadch/announcer_client`](https://github.com/luadch/announcer_client) + [`luadch/announcer_bot`](https://github.com/luadch/announcer_bot), both stale since 2022).

## ⚠️ Why you want rc4 over rc3

rc4 fixes the reconnect handling and makes the GUI reflect the live connection state. Closes [#70](https://github.com/luadch-ng/announcer/issues/70).

1. **Automatic reconnect after a hub outage.** The announce loop only ever *sent* (release announcements + a keepalive) and never *read* the hub stream, so a dropped hub was noticed only when a later send happened to fail - which on a half-open TCP connection can take many minutes, or never. The announcer therefore looked "connected" but never came back. It now polls the link and detects a clean drop within ~5 s, then reconnects on its own (verified against a test hub: ~1 s detection, ~10 s full re-login). **This is the main fix - if the hub restarts, the announcer rejoins by itself.**
2. **Honest login errors + no auth hammering.** The login now recognises the hub's rejection messages (bad password, nick/CID taken, hub full, ...) instead of mis-reporting them as "No password request, closing". A wrong password stops cleanly with the real reason; a transient rejection (hub full / nick taken) retries with backoff.
3. **Live connection status in the GUI.** A coloured indicator (green = connected / orange = reconnecting / red = disconnected) plus the status-bar text and log lines now reflect the live connection, so an outage and the following reconnect are actually visible instead of a frozen "Connected".

The announce-protocol path is unchanged, so the rc2/rc3 end-to-end verification against the hub-side `ptx_freshstuff` plugin carries forward.

## ⚠️ Before installing

Back up your config + state before swapping:

```sh
tar -czf "announcer-backup-$(date +%F).tar.gz" cfg log
```

The `cfg/` layout is byte-identical to all earlier rc versions - drop your `cfg/*.lua` into the new install's `cfg/` and settings carry over, including `log/announced.txt` (which releases were already announced).

## What's new since rc3

- [#70](https://github.com/luadch-ng/announcer/issues/70) - **Reconnect too long / never reconnects (fixed).** Read-driven announce loop detects a dropped hub in seconds and reconnects automatically; ISTA-aware login (honest errors, no hammering); live GUI connection indicator (LED + status bar + log line per transition). `net.loop()` is shared by the CLI and the GUI worker, so both frontends get the fix.
