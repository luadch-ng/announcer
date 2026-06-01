# lib/ressources/

GUI resource assets (PNG only). All entries are source artefacts — no
pre-built binary blobs.

| File                          | Source                                                              | Purpose                                            |
|-------------------------------|---------------------------------------------------------------------|----------------------------------------------------|
| `png/applogo_16x16.png`       | extracted from upstream `res1.dll` in Phase 3 Tier 1                | App icon, window titlebar size                     |
| `png/applogo_32x32.png`       | extracted from upstream `res1.dll` in Phase 3 Tier 1                | App icon, taskbar size                             |
| `png/applogo_96x96.png`       | upstream `luadch/announcer_client`                                  | App icon, About-dialog size (GPL-3.0 art)          |
| `png/GPLv3_160x80.png`        | upstream `luadch/announcer_client`                                  | License badge in About dialog                      |
| `png/tab_{0..4}_16x16.png`    | extracted from upstream `res2.dll` in Phase 3 Tier 1                | Notebook tab icons (5 unique source PNGs; tab_5 in `Announcer.wx.lua` reuses tab_3 by design) |

History: the original `res1.dll` and `res2.dll` Windows PE icon
containers shipped with the wxLua-2.8 client. Phase 3 Tier 1 (#15)
extracted the 7 icons inside them as PNGs using wxLua itself
(`wxIcon(file, type, w, h)` + `wxBitmap:ConvertToImage:SaveFile`)
and removed the source DLLs. The wxLua-2.8 frozen distribution's
PE-resource-extraction shortcut is not available under wxLua 3.x +
Lua 5.4; the PNG-loaded path is portable instead.

`client.dll` (the upstream wxluafrozen Lua-5.1 announcer-bot
bundle) was removed in Phase 1 PR-C. The GUI spawns
`frontends/gui/spawned_worker.lua` via the bundled `lua.exe`
(Lua 5.4) instead.

License: GPL-3.0 (matches the upstream client and this repo).
