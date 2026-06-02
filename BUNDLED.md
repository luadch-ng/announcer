# Vendored sources + bundled provenance

After Phase 2 (CMake build pipeline), the announcer no longer commits
pre-built binary blobs. All runtime binaries are produced by the local
build from the in-tree vendored C sources. See [`docs/BUILDING.md`](docs/BUILDING.md)
for the three-step `cmake -B build` workflow.

This file documents the per-source upstream provenance + sync policy.

## In-tree vendored C sources

| Directory             | Upstream                                                    | Version / sync          | Built artefact (CMake)         |
|-----------------------|-------------------------------------------------------------|-------------------------|--------------------------------|
| `lua/src/`            | upstream Lua 5.4 (lua.org)                                  | mirrored from hub `luadch-ng/luadch:lua/src` | `lua.dll` + `lua.exe` (standalone interpreter, announcer-specific) |
| `adclib/`             | hub's `luadch-ng/luadch:adclib`                             | mirrored                | `lib/adclib/adclib.dll`        |
| `luasec/`             | hub's `luadch-ng/luadch:luasec` (upstream LuaSec 1.3.2)     | mirrored                | `lib/luasec/ssl/ssl.dll`       |
| `luasocket/`          | hub's `luadch-ng/luadch:luasocket` (upstream LuaSocket 3.1.0) | mirrored              | `lib/luasocket/socket/socket.dll` + `lib/luasocket/mime/mime.dll` |
| `lfs/src/`            | upstream [`lunarmodules/luafilesystem`](https://github.com/lunarmodules/luafilesystem) | **v1.9.0** (cloned 2026-06-01) | `lib/lfs/lfs.dll` |
| `wxlua/`              | [`OneLuaPro/wxlua`](https://github.com/OneLuaPro/wxlua) (active fork of pkulchenko/wxlua) | **SHA `c5e0cbb`** (dated 2026-02-27, snapshot) | `lib/wx/wx.dll` (only built with `-DBUILD_GUI=ON`) |

## In-tree vendored pure-Lua sources

| File / dir                  | Upstream                                                    | Sync           | Installed to (CMake) |
|-----------------------------|-------------------------------------------------------------|----------------|----------------------|
| `basexx/basexx.lua`         | hub's `luadch-ng/luadch:basexx/basexx.lua`                  | mirrored       | `lib/basexx/basexx.lua` |
| `slnunicode/unicode.lua`    | hub's `luadch-ng/luadch:slnunicode/unicode.lua` (~100 LoC utf-8 shim that replaces the unmaintained `slnunicode` C module) | mirrored | `lib/unicode/unicode.lua` |

## Runtime DLLs bundled at install root

Produced by the CMake build (NOT committed in the source tree):

- `lua.dll` (Lua 5.4 runtime)
- `lua.exe` (Lua 5.4 standalone interpreter)
- `libssl-3-x64.dll` + `libcrypto-3-x64.dll` (copied from `OPENSSL_ROOT_DIR` at install time)

## Committed binaries that remain (not yet CMake-built)

None as of Phase 3 Tier 1. The previous entries here were:

- `lib/lfs_wx/lfs.dll` (Lua-5.1 build for the wxLua 2.8 GUI) - removed in Phase 3 Tier 1. The Tier-2 runtime bundle decides which `lfs.dll` the GUI process loads.
- `lib/ressources/res{1,2}.dll` (wxLua 2.8 PE icon containers) - removed in Phase 3 Tier 1. The 7 icons they held now ship as PNGs under `lib/ressources/png/` and are loaded via the existing `wxBitmap(path, wxBITMAP_TYPE_PNG)` pattern.

## Vendored as git submodule (Phase 3 Tier 2)

One dep is too large to commit in-tree without bloating the repo:

| Submodule  | Version | URL                              | Why submodule (not in-tree) |
|------------|---------|----------------------------------|-----------------------------|
| `wxwidgets/` | v3.2.10 | github.com/wxWidgets/wxWidgets   | ~80 MB source. In-tree would balloon the repo. Submodule = source-only-promise intact (still source, just pinned by SHA). |

**Clone instructions:** `git clone --recurse-submodules <repo>`, or after a plain
clone: `git submodule update --init --recursive`. CI does this automatically.

## Bundled GUI assets (source artefacts, not pre-built binaries)

| File                                       | Purpose                                                |
|--------------------------------------------|--------------------------------------------------------|
| `lib/ressources/png/applogo_{16,32,96}x*.png` | Window / taskbar / About-dialog app icon, 3 sizes      |
| `lib/ressources/png/GPLv3_160x80.png`         | License badge in About dialog                          |
| `lib/ressources/png/tab_{0..4}_16x16.png`     | Notebook tab icons (5 unique; tab_5 reuses tab_3 by design) |

## Sync policy

When the hub `luadch-ng/luadch` updates one of the C deps (typically as
part of a phase-N modernisation), sync this announcer's vendored copy
in a follow-up PR:

1. Copy the updated `<dep>/` directory from the hub.
2. Re-run `cmake --build build && cmake --install build` and verify
   the smoke (`dofile core/init.lua` runs to the expected
   `ssl.newcontext` failure when no cert is installed).
3. Document the sync date + hub commit hash in this file.

This avoids accidental drift; the announcer is always one explicit
sync behind the hub at most.

## Verification

```sh
# After cmake --install build, confirm each artefact links lua.dll
# (NOT lua54.dll - we ship our own runtime under that exact name):
cd build/install/announcer
objdump -p lua.exe lua.dll libssl-3-x64.dll lib/adclib/adclib.dll lib/lfs/lfs.dll | grep "DLL Name"
```

All artefacts should reference `lua.dll`.
