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

| File                          | Reason still committed                                                                           |
|-------------------------------|--------------------------------------------------------------------------------------------------|
| `lib/lfs_wx/lfs.dll`          | Lua-5.1 build used by the wxLua-2.8 GUI. Phase 3 GUI rework on wxLua 3.x will replace this.       |
| `lib/ressources/res1.dll`     | wxLua 2.8 icon-resource bundle. Phase 2 PR-E will replace with sourced-from-PNG resource loading. |
| `lib/ressources/res2.dll`     | Same.                                                                                            |
| `lib/ressources/png/*.png`    | App icon + license-badge PNGs. Stay; PR-E will use them directly.                                |

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
