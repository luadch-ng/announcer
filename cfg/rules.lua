--// Watched directories (the [`path`] field below).
--//
--// #31: Use forward slashes on ALL platforms. They work on Windows
--// because the Win32 API accepts both / and \. Backslashes in Lua
--// strings need to be escaped (\\), which is error-prone.
--//   Correct (cross-platform):     "C:/MyReleases"  or  "/home/user/releases"
--//   Incorrect (Lua string):       "C:\MyReleases"  (\M is an invalid Lua escape)
--//   Workable but ugly:            "C:\\MyReleases" (escaped backslash)

rules = {

    [ 1 ] = {

        [ "active" ] = true,
        [ "alibicheck" ] = false,
        [ "alibinick" ] = "DUMP",
        [ "blacklist" ] = {

            [ "(incomplete)" ] = true,
            [ "(no-sfv)" ] = true,
            [ "(nuked)" ] = true,

        },
        [ "category" ] = "Movies_1080p",
        [ "checkage" ] = false,
        [ "checkdirs" ] = true,
        [ "checkdirsnfo" ] = false,
        [ "checkdirssfv" ] = false,
        [ "checkfiles" ] = false,
        [ "checkspaces" ] = true,
        [ "command" ] = "+addrel",
        [ "daydirscheme" ] = false,
        [ "maxage" ] = 0,
        [ "path" ] = "C:/your/path/to/announce",
        [ "rulename" ] = "Movies_1080p",
        --// #28: skip releases whose folder name starts with a dot
        --// (.git, .vscode, .DS_Store etc.). Default true; set false
        --// to allow dot-prefix releases through this rule.
        [ "skip_hidden" ] = true,
        --// #29: per-extension count cap. Block the release if any
        --// listed extension appears more than its max in the bundle.
        --// Set to nil / omit the key to disable. Default blocks
        --// "dirty" bundles with extra .nfo or .sfv files.
        [ "max_per_extension" ] = {
            [ "nfo" ] = 1,
            [ "sfv" ] = 1,
        },
        --// #29: when true, max_per_extension walks subfolders too,
        --// catching sample-folder .nfo or .mkv duplicates. Default
        --// true; set false to only count top-level files.
        [ "max_per_extension_recursive" ] = true,
        --// #38: max recursion depth for the max_per_extension walk.
        --// Guards against symlink loops (Linux), junction-point loops
        --// (Windows), and pathological cfg.path settings that would
        --// otherwise walk the entire filesystem inside one announce
        --// tick. Default 8 (omit / set nil to use it); raise if your
        --// bundles legitimately nest deeper.
        [ "max_per_extension_max_depth" ] = 8,
        [ "whitelist" ] = {


        },
        [ "zeroday" ] = false,

    },

}

return rules