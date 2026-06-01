# lib/ressources/

GUI resource blobs imported verbatim from `luadch/announcer_client` master
branch (last commit before consolidation, 2022). The wxLua frontend
references these at runtime via `RES_PATH = "lib/ressources/"`
(defined in `core/const.lua`).

| File              | Source                                  | Purpose                              |
|-------------------|-----------------------------------------|--------------------------------------|
| `applogo_96x96.png` | upstream `luadch/announcer_client`    | App icon (PNG, GPL-3.0 art)          |
| `GPLv3_160x80.png`  | upstream `luadch/announcer_client`    | License badge image in the about box |
| `res1.dll`          | upstream `luadch/announcer_client`    | GUI icon resource bundle             |
| `res2.dll`          | upstream `luadch/announcer_client`    | GUI icon resource bundle (alt)       |

The `.dll` files are not Lua C modules - they are Windows resource
bundles loaded by wxLua at runtime to display the GUI's icons and
images. They were produced by the upstream maintainers in 2022.

`client.dll` (the upstream wxluafrozen Lua-5.1 announcer-bot
bundle) was REMOVED in Phase 1 PR-C. The GUI now spawns
`frontends/gui/spawned_worker.lua` via the bundled `lua.exe` (Lua
5.4) instead of executing a frozen .dll bundle.

**Phase 2 plan**: replace these with sourced-from-PNG resource loading
so we don't need to ship opaque resource `.dll` blobs. Until then they
are inherited as-is from the consolidation snapshot.

License: GPL-3.0 (matches the upstream client and this repo).
