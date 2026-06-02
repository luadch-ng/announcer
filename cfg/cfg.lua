cfg = {

    [ "announceinterval" ] = 300,
    [ "botdesc" ] = "Announcer Client",
    [ "botshare" ] = 0,
    [ "botslots" ] = 0,
    --// #26: max upload speed advertised in INF (US field, bytes/sec).
    --// 0 = no claim. Some hub-side stats / top-uploader scripts expect
    --// a non-zero value to count the bot; set to e.g. 125000000 for
    --// 1 Gbps. The announcer itself does not actually upload; this
    --// only affects how the hub displays / classifies the bot.
    [ "botupload" ] = 0,
    [ "freshstuff_version" ] = true,
    [ "logfilesize" ] = 2097152,
    [ "sleeptime" ] = 10,
    [ "sockettimeout" ] = 60,
    [ "trayicon" ] = false,

}

return cfg