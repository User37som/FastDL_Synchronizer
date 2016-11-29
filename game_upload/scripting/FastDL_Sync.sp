/**
 * FastDL sync manager
 * 
 * Automatic FastDL updater
 * Written by Kruzya
 * 
 * Updates your web-host files for fast connecting
 * 
 * Requires:
 * * bzip2 extension: <https://forums.alliedmods.net/showthread.php?t=175063>
 * * cURL extension:  <https://forums.alliedmods.net/showthread.php?t=152216>
 * * MySQL server (configure in databases.cfg section with name "fastdl")
 * * (optionally) PHP 5.3 for cleaning unused files from web-host
 **/

#include <sourcemod>
#include <dbi>
#include <sdktools>
#include <sdktools_stringtables>
#include <keyvalues>
#include <bzip2>
#include <cURL>

#pragma newdecls required

Handle hFiles = null;
int DLTable = INVALID_STRING_TABLE;
int AmountThreads;
bool bWork;
int iFilesCount;
Database hDB;

public Plugin myinfo = {
    description = "Synchronizes your FastDL with server files.",
    version     = "0.1.1-dev",
    author      = "Kruzya",
    name        = "FastDL updater",
    url         = "https://kruzefag.ru/"
};

public void OnPluginStart() {
    RegServerCmd("sm_fastdl_update", OnNeedSyncFastDLFiles);
    RegServerCmd("sm_fastdl_list",   OnNeedPrintListFiles);

    ConVar cvTogetherUploadingFiles = CreateConVar("sm_fastdl_amountfiles", "2", "Allows you to control the amount at once uploads.", 0);
    cvTogetherUploadingFiles.AddChangeHook(OnCVarUpdate);
    delete cvTogetherUploadingFiles;
    AmountThreads = 2;
    
    bWork = false;
    
    /* Init */
    SQL_Start();
}

/* DEBUG CMD */
public Action OnNeedPrintListFiles(int argc) {
    ValidateDLTable();
    int iCount = GetAmountFiles();
    PrintToServer("-[FastDL] Listening stringtable 'downloadables'-");
    PrintToServer("          Files: %d", iCount);
    
    char sFile[PLATFORM_MAX_PATH];
    for (int iFile = 0; iFile<iCount; iFile++) {
        GetFilepath(iFile, sFile, PLATFORM_MAX_PATH);
        PrintToServer("     %03d. %s", iFile+1, sFile);
    }
    return Plugin_Handled;
}

public void OnCVarUpdate(ConVar cv, const char[] oV, const char[] nV) {
    AmountThreads = StringToInt(nV);
}

/* Helpers */
void ValidateDLTable() {
    if (DLTable == INVALID_STRING_TABLE)
        DLTable = FindStringTable("downloadables");
}

public int GetAmountFiles() {
    ValidateDLTable();
    return GetStringTableNumStrings(DLTable);
}

public int GetFilepath(int iFileNum, char[] str, int maxLength) {
    ValidateDLTable();
    return ReadStringTable(DLTable, iFileNum, str, maxLength);
}

public int GetFilename(char[] filename, char[] output, int maxLength) {
    char sTemp[10][50];
    int ID = ExplodeString(filename, "/", sTemp, 10, 50);
    return strcopy(output, maxLength, sTemp[ID-1]);
}

void RecreateFilesArray() {
    if (hFiles != null)
        ClearArray(hFiles);
    else
        hFiles = CreateArray(PLATFORM_MAX_PATH);
}

public int GetServerIP() {
    static int iIP;
    if (iIP)
        return iIP;

    ConVar hIP = FindConVar("hostip");
    iIP = hIP.IntValue;
    delete hIP;
    
    return iIP;
}

public int GetServerPort() {
    static int iPort;
    if (iPort)
        return iPort;

    ConVar hPort = FindConVar("hostport");
    iPort = hPort.IntValue;
    delete hPort;
    
    return iPort;
}

/* SQL */
public void SQL_Start() {
    if (bCanWork)
        delete hDB;
    hDB.Connect(SQL_ConnectCallback, "fastdl");
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

public void SQL_ConnectCallback(Database hDatabase, const char[] error) {
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

public void SQL_DefaultCallback(Database db, DBResultSet res, const char[] error) {
    if (!db || !res)
        LogError("Error with executing query: %s", error);
}

/* Updater code */
public Action OnNeedSyncFastDLFiles(int argc) {
    // Start FastDL update
    PrintToServer("[FastDL] Start updating FastDL files after 5 seconds...");
    bWork = true;
    CreateTimer(5.0, StartFastDL_Update);
    return Plugin_Handled;
}

public Action StartFastDL_Update(Handle hTimer) {
    iFilesCount = GetAmountFiles();
    PrintToServer("[FastDL] Need upload %d files. Allowed %d workers.", iFilesCount, AmountThreads);
    CreateTimer(0.5, FastDL_PrepareFilesList);
}

public Action FastDL_PrepareFilesList(Handle hTimer) {
    char sFile[PLATFORM_MAX_PATH];
    RecreateFilesArray();
    
    PrintToServer("[FastDL] Reading downloadables list...");
    for (int iFileNum = 0; iFileNum<iFilesCount; iFileNum++) {
        GetFilepath(iFileNum, sFile, PLATFORM_MAX_PATH);
        if (FileExists(sFile)) {
            PushArrayString(hFiles, sFile);
            PrintToServer("[FastDL] Founded and added to upload list file %s", sFile);
        } else
            PrintToServer("[FastDL] Founded, but not added to upload list file %s, because file not found on server drive.", sFile);
    }
    
    iFilesCount = GetArraySize(hFiles);
    PrintToServer("[FastDL] Downloadables list fully readed. Founded and added to upload list %d files.", iFilesCount);
    
    for (int iWorker = 1; iWorker <= AmountThreads; iWorker++)
        CreateTimer(0.5*iWorker, FastDLWorker, iWorker);
}

public Action FastDLWorker(Handle hTimer, any iWorker) {
    if (!GetArraySize(hFiles)) {
        PrintToServer("[FastDL] Worker #%d stopped. All jobs finished.", iWorker);
        return;
    }
    
    char sFile[PLATFORM_MAX_PATH];
    char sCompressed[PLATFORM_MAX_PATH];
    GetArrayString(hFiles, 0, sFile, PLATFORM_MAX_PATH);
    
    GetFilename(sFile, sCompressed, PLATFORM_MAX_PATH);
    BuildPath(Path_SM, sCompressed, PLATFORM_MAX_PATH, "data/%s.bz2", sCompressed);
    
    FastDL_SendToDB(sFile);
    
    BZ2_CompressFile(sFile, sCompressed, 9, OnFilePacked, iWorker);
}

public void OnFilePacked(BZ_Error iErr, char[] sFile, char[] sCompressed, any worker) {
    
}
