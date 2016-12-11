Database hDB;
bool bCanWork;

public void SQL_StartConnect() {
    if (bCanWork)
        delete hDB;
    Database.Connect(SQL_ConnectCallback, "fastdl");
}

public void SQL_ClearFiles() {
    char sQuery[256];
    FormatEx(sQuery, sizeof(sQuery), "DELETE * FROM `fastdl_files` WHERE `server` = (SELECT `id` FROM `fastdl_servers` WHERE `ip` = %d AND `port` = %d)", GetServerIP(), GetServerPort());
    hDB.Query(SQL_DefaultCallback, sQuery);
}

public void SQL_SendFileToDB(char[] file) {
    char sPacked[PLATFORM_MAX_PATH],
        sQuery[256],
        sTemp[256];
    FormatEx(sPacked, PLATFORM_MAX_PATH, "%s.bz2", file);
    hDB.Escape(sPacked, sPacked, PLATFORM_MAX_PATH);
    FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `fastdl_files` (`file`, `server`) VALUES (%s, (SELECT `id` FROM `fastdl_servers` WHERE `ip` = %d AND `port` = %d));", sPacked);
    
    hDB.Query(SQL_DefaultCallback, sQuery);
}

public void SQL_ConnectCallback(Database hDatabase, const char[] error, any data) {
    if (!hDatabase) {
        LogError("Unable to connect database: %s", error);
        bCanWork = false;
        return;
    }
    
    hDB = hDatabase;
    hDB.SetCharset("utf8");
    
    // SQL_CheckTables();
    SQL_ClearFiles();
    bCanWork = true;
}

public void SQL_DefaultCallback(Database db, DBResultSet res, const char[] error, any data) {
    if (!db || !res)
        LogError("Error with executing query: %s", error);
}
