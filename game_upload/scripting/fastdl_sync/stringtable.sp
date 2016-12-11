int DLTable = INVALID_STRING_TABLE;

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
