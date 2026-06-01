# Bundled binary provenance

Top-level + `lib/` binary blobs shipped with this repo. Per CLAUDE.md
§6 "never add a new binary blob to lib/ without updating ... README.md"
- this file extends that contract to the top-level runtime binaries
introduced in Phase 1.

## Top-level runtime (Phase 1, Win64 only)

These ship at the repo root so operators can run `lua.exe frontends/cli/main.lua`
without installing Lua 5.4 separately. Linux `.so` + macOS `.dylib`
arrive in Phase 2.

| File                       | Size      | Source                                                                          | Built                                                                                                  |
|----------------------------|-----------|---------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| `lua.exe`                  | 109 934 B | upstream Lua 5.4.7 / 5.4.8 stdlib (`lua.c`), built fresh                        | MinGW gcc 16.1.0 UCRT64. `gcc -O2 -o lua.exe lua.c -I<hub>/lua/src -L. -l:lua.dll -static-libgcc`      |
| `lua.dll`                  | 363 008 B | hub `luadch-ng/luadch` build/install artefact - the Lua 5.4 runtime             | hub's CMake build at `d:\Projekte\luadch\build\install\luadch\lua.dll` (commit on `master`)             |
| `libcrypto-3-x64.dll`      | 7 065 964 B | OpenSSL 3                                                                       | mirrored from hub's build/install artefact (same OpenSSL version the hub links against)                |
| `libssl-3-x64.dll`         | 1 325 432 B | OpenSSL 3                                                                       | mirrored from hub's build/install artefact                                                             |

Why `lua.dll` and not `lua54.dll`? The hub builds its Lua runtime with
the basename `lua.dll`, and all the hub-compiled C extensions
(`adclib`, `luasec/ssl`, `luasocket/socket`, etc.) link against
`lua.dll` by that name. The standalone Lua 5.4 distro at
`C:\lua-5.4.8_Win64_bin\lua54.dll` is **not** ABI-interchangeable
here even though both are Lua 5.4 - the DLL filename must match.

## `lib/` C-extension binaries

| File                              | Size       | Source                                                                                         |
|-----------------------------------|------------|------------------------------------------------------------------------------------------------|
| `lib/adclib/adclib.dll`           | varies     | hub's CMake build (`adclib/CMakeLists.txt`). ADC tiger-hash + base32 + escape helpers.         |
| `lib/luasec/ssl/ssl.dll`          | varies     | hub's CMake build of upstream `luasec 1.3.2`.                                                  |
| `lib/luasocket/socket/socket.dll` | varies     | hub's CMake build of upstream `luasocket 3.1.0`.                                               |
| `lib/luasocket/mime/mime.dll`     | varies     | hub's CMake build of upstream `luasocket 3.1.0`.                                               |
| `lib/lfs/lfs.dll`                 | 69 371 B   | built fresh from `lunarmodules/luafilesystem` upstream **v1.9.0**, MinGW gcc 16.1.0 UCRT64.    |

`lfs.dll` build invocation (from upstream luafilesystem `src/`):

```
gcc -O2 -Wall -shared -o lfs.dll lfs.c \
    -I<hub>/lua/src \
    -L. -l:lua.dll \
    -static-libgcc
```

The hub does not bundle LuaFileSystem (the hub doesn't need it). It
is built in-tree for the announcer because `core/announce.lua` and
`core/log.lua` use `lfs.dir` / `lfs.attributes` for the release-dir
scan and the log-size cap.

## `lib/lfs_wx/lfs.dll`

Still the upstream 2014 Lua-5.1 build. **The wxLua GUI uses this
directory** via a separate `package.cpath` line in
`Announcer.wx.lua`. GUI migration to Lua 5.4 / wxLua 3.x is **Phase
3** scope; until then this remains a Lua-5.1 module. The CLI does
not load it.

## `lib/ressources/{res1,res2}.dll`

GUI icon resource bundles inherited verbatim from upstream
`luadch/announcer_client` master branch (2022). See
[`lib/ressources/README.md`](lib/ressources/README.md). Will be
replaced with sourced-from-PNG resource loading in **Phase 2**.

`client.dll` (the upstream wxluafrozen Lua-5.1 announcer-bot
bundle) was removed in Phase 1 PR-C; the GUI now spawns
`frontends/gui/spawned_worker.lua` via the bundled `lua.exe`.

## Verification

```sh
# Confirm each .dll links the expected lua runtime
objdump -p lua.exe lua.dll libssl-3-x64.dll lib/adclib/adclib.dll lib/lfs/lfs.dll | grep "DLL Name"
```

All hub-derived blobs and the locally-built lfs should reference
`lua.dll` (NOT `lua54.dll`).

## Phase 2 plan

Replace this section with a CMake build pipeline that produces all
of the above from in-tree sources. The Phase 2 PR will delete
`BUNDLED.md` (or re-scope it to "build-output description") because
the artefacts will no longer be vendored blobs.
