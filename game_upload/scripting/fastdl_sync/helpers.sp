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

public int GetFilename(char[] filename, char[] output, int maxLength) {
    char sTemp[10][50];
    int ID = ExplodeString(filename, "/", sTemp, 10, 50);
    return strcopy(output, maxLength, sTemp[ID-1]);
}
