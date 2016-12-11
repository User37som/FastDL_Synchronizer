/* Config */
/* FTP */
char sCFG_FTPHost[64],
     sCFG_FTPDir[PLATFORM_MAX_PATH],
     sCFG_FTPAuth[64],
     sCFG_FTPAuth_login[32],
     sCFG_FTPAuth_pass[32];

int  iCFG_FTPPort;

/* Callbacks */
char sCallbacks_Start[128],
     sCallbacks_Processing[128],
     sCallbacks_End[128];

/* Workers */
char sWorkers_TransferLimit[64];
int iWorkers_Timeout,
    iWorkers_Threads;

/* Reader */
#define CFG_UNKNOWN     0
#define CFG_FTPDATA     1
#define CFG_CALLBACKS   2
#define CFG_WORKERS     3

#define CFGLOG_PREFIX   "[SMCParser: CFG Reader]"

char sCFGPath[PLATFORM_MAX_PATH];

char sSMCDescriptions[][] = {
    /* Just Copy & Paste descriptions from <https://sm.alliedmods.net/new-api/textparse/SMCError> */
    "No error.",
    "Stream failed to open.",
    "The stream died... somehow",
    "A custom handler threw an error",
    "A section was declared without quotes, and had extra tokens",
    "A section was declared without any header",
    "A section ending was declared with too many unknown tokens",
    "A section ending has no matching beginning",
    "A section beginning has no matching ending",
    "There were too many unidentifiable strings on one line",
    "The token buffer overflowed",
    "A property was declared outside of any section"
}

int iCurrentReaderState;

public bool CFG_StartRead() {
    int iLine,
        iColumn;
    
    SMCParser hSMC      = new SMCParser();
    hSMC.OnEnterSection = CFG_OnEnterSection;
    hSMC.OnLeaveSection = CFG_OnLeaveSection;
    hSMC.OnKeyValue     = CFG_OnKeyValue;
    
#if defined DEBUG
    LogMessage("CFG_StartRead(): Reading start...");
#endif
    iCurrentReaderState = CFG_UNKNOWN;
    SMCError iSMCErr    = hSMC.ParseFile(sCFGPath, iLine, iColumn);
#if defined DEBUG
    LogMessage("CFG_StartRead(): Reading end.");
#endif
    if (iSMCErr != SMCError_Okay) {
        LogError("%s %s", CFGLOG_PREFIX, sSMCDescriptions[view_as<int>(iSMCErr)]);
        return false;
    } else {
        FormatEx(sCFG_FTPAuth, sizeof(sCFG_FTPAuth), "%s:%s", sCFG_FTPAuth_login, sCFG_FTPAuth_pass);
        return true;
    }
}

public SMCResult CFG_OnEnterSection(SMCParser hSMC, const char[] sName, bool bOptQuotes) {
    if (StrEqual(sName,         "ftp"))
        iCurrentReaderState = CFG_FTPDATA;
    else if (StrEqual(sName,    "callbacks"))
        iCurrentReaderState = CFG_CALLBACKS;
    else if (StrEqual(sName,    "workers"))
        iCurrentReaderState = CFG_WORKERS;
    else
        iCurrentReaderState = CFG_UNKNOWN;

#if defined DEBUG
    LogMessage("CFG_OnEnterSection(): New section \"%s\". Detected ID: %d", sName, iCurrentReaderState);
#endif

    return SMCParse_Continue;
}

public SMCResult CFG_OnLeaveSection(SMCParser hSMC) {
#if defined DEBUG
    LogMessage("CFG_OnLeaveSection(): Section reading done.");
#endif

    iCurrentReaderState = CFG_UNKNOWN;
    return SMCParse_Continue;
}

public SMCResult CFG_OnKeyValue(SMCParser hSMC, const char[] sKey, const char[] sValue, bool bKeyQuotes, bool bValueQuotes) {
#if defined DEBUG
    LogMessage("CFG_OnKeyValue(): Found key \"%s\" with value \"%s\" in section with ID %d", sKey, sValue, iCurrentReaderState);
#endif

    switch (iCurrentReaderState) {
        case CFG_FTPDATA:   {
            if (StrEqual(sKey,      "host"))
                strcopy(sCFG_FTPHost,       sizeof(sCFG_FTPHost),       sValue);
            else if (StrEqual(sKey, "user"))
                strcopy(sCFG_FTPAuth_login, sizeof(sCFG_FTPAuth_login), sValue);
            else if (StrEqual(sKey, "password"))
                strcopy(sCFG_FTPAuth_pass,  sizeof(sCFG_FTPAuth_pass),  sValue);
            else if (StrEqual(sKey, "dir_path"))
                strcopy(sCFG_FTPDir,        sizeof(sCFG_FTPDir),        sValue);
            else if (StrEqual(sKey, "port"))
                iCFG_FTPPort = StringToInt(sValue);
        }
        
        case CFG_CALLBACKS: {
            if (StrEqual(sKey, "start"))
                strcopy(sCallbacks_Start,       sizeof(sCallbacks_Start),       sValue);
            else if (StrEqual(sKey, "processing"))
                strcopy(sCallbacks_Processing,  sizeof(sCallbacks_Processing),  sValue);
            else if (StrEqual(sKey, "end"))
                strcopy(sCallbacks_End,         sizeof(sCallbacks_End),         sValue);
        }
        
        case CFG_WORKERS:   {
            if (StrEqual(sKey, "transfer_limit"))
                strcopy(sWorkers_TransferLimit, sizeof(sWorkers_TransferLimit), sValue);
            else if (StrEqual(sKey, "timeout"))
                iWorkers_Timeout    = StringToInt(sValue);
            else if (StrEqual(sKey, "threads"))
                iWorkers_Threads    = StringToInt(sValue);
        }
    }
    
    return SMCParse_Continue;
}
