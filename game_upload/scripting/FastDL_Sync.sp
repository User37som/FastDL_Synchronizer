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

#define DEBUG       true

#include <sourcemod>
#include <dbi>
#include <sdktools>
#include <sdktools_stringtables>
#include <keyvalues>
#include <bzip2>
#include <cURL>

#pragma newdecls required

#include "fastdl_sync/helpers.sp"
#include "fastdl_sync/config.sp"
#include "fastdl_sync/sql.sp"
#include "fastdl_sync/stringtable.sp"

Handle hFiles = null;
int iFilesCount;
bool bWork;

/* Default cURL options */
int cURL_DefaultOptions[][] = {
    {view_as<int>(CURLOPT_FTP_CREATE_MISSING_DIRS), view_as<int>(CURLFTP_CREATE_DIR)},
    {view_as<int>(CURLOPT_NOSIGNAL),                1},
    {view_as<int>(CURLOPT_NOPROGRESS),              1},
    {view_as<int>(CURLOPT_CONNECTTIMEOUT),          60},
    {view_as<int>(CURLOPT_VERBOSE),                 0},
    {view_as<int>(CURLOPT_UPLOAD),                  1}
};

public Plugin myinfo = {
    description = "Synchronizes your FastDL with server files.",
    version     = "0.1.2-dev",
    author      = "Kruzya",
    name        = "FastDL updater",
    url         = "https://kruzefag.ru/"
};

public void OnPluginStart() {
    RegServerCmd("sm_fastdl_update", OnNeedSyncFastDLFiles);
    RegServerCmd("sm_fastdl_list",   OnNeedPrintListFiles);

    /* Init */
    BuildPath(Path_SM,  sCFGPath, PLATFORM_MAX_PATH, "cfg/fastdl.cfg");
    if (!FileExists(sCFGPath)) {
        SetFailState("Config (%s) not found.", sCFGPath);
        return;
    }
    bWork = false;
    SQL_StartConnect();
    CFG_StartRead();
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

void RecreateFilesArray() {
    if (hFiles != null)
        ClearArray(hFiles);
    else
        hFiles = CreateArray(PLATFORM_MAX_PATH);
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
    PrintToServer("[FastDL] Need upload %d files. Allowed %d workers.", iFilesCount, iWorkers_Threads);
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
    
    for (int iWorker = 1; iWorker <= iWorkers_Threads; iWorker++)
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
    
    /* SQL: Send file to DB */
    // Coming Soon
    
    /* Remove file from ADT_Array */
    RemoveFromArray(hFiles, 0);
    
    BZ2_CompressFile(sFile, sCompressed, 9, OnFilePacked, iWorker);
}

public void OnFilePacked(BZ_Error iErr, char[] sFile, char[] sCompressed, any worker) {
    /* Check error exists */
    if (iErr != BZ_OK) {
        LogError("Couldn't pack file \"%s\" to archive. Error code: %d. Worker ID: %d.", sFile, iErr, worker);
        return;
    }
    /* Start upload transfer task. */
    /* Create cURL handle and setting default params */
    Handle hcURL = curl_easy_init();
    curl_easy_setopt_int_array( hcURL,  cURL_DefaultOptions,            sizeof(cURL_DefaultOptions));
    curl_easy_setopt_string(    hcURL,  CURLOPT_USERPWD,                sCFG_FTPAuth);
    curl_easy_setopt_int64(     hcURL,  CURLOPT_MAX_SEND_SPEED_LARGE,   sWorkers_TransferLimit);
    curl_easy_setopt_int(       hcURL,  CURLOPT_TIMEOUT,                iWorkers_Timeout);
    
    /* Prepare path */
    char sFileOnFTP[PLATFORM_MAX_PATH];
    FormatEx(sFileOnFTP, sizeof(sFileOnFTP), "%s/%s", sCFG_FTPDir, sCompressed);
    
    /* Start upload */
    Handle hFile = curl_OpenFile(sCompressed, "rb");
    if (!hFile) {
        CloseHandle(hcURL);
        LogError( g_logfile, "Couldn't open \"%s\" for upload!", source );
        return;
    }
    
    LogMessage("Start uploading file \"%s\"...", sCompressed);
    curl_easy_setopt_handle(hcURL,  CURLOPT_READDATA,   hFile);
    curl_easy_setopt_string(hcURL,  CURLOPT_URL,        sFileOnFTP);
    curl_easy_perform_thread(hcURL, OnUploadComplete,   worker);
}

public void OnUploadComplete(Handle hcURL, CURLcode iCode, any worker) {
    CloseHandle(hcURL);
    if (iCode != CURLE_OK)
        LogError("Upload failed.");
    
    CreateTimer(0.5*worker, FastDLWorker, worker);
}
