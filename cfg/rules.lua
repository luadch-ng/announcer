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
        [ "whitelist" ] = {


        },
        [ "zeroday" ] = false,

    },

}

return rules