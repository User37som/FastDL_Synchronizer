# FastDL synchronizer
#### Automatic FastDL updater
#### Written by Kruzya

Updates your web-server files for FastDL after event or cmd

## *Requires*:
- [bzip2 extension for SourceMod](https://forums.alliedmods.net/showthread.php?t=175063)
- [cURL extension for SourceMod](https://forums.alliedmods.net/showthread.php?t=152216)
- MySQL server
- *(optionally)* PHP

Dir *includes* in **/scripting/** contains fixed includes BZip2 and cURL for successfull compiling.
- *bzip2*: Ported to new syntax.
- *cURL*: Changed function (*curl_easy_setopt_string*) argument with buffer. Compiler throws error *cannot coerce char[] to any[]*
