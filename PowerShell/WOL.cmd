@ECHO OFF
CLS
SET WOL_PATH=%~dp0
SET WOL_FILE=WOL.ps1
SET WOL_MAC=00:11:22:33:44:55
SET WOL_NET=192.168.0.255
@"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy unrestricted -file "%WOL_PATH%%WOL_FILE%" "%WOL_MAC%" "%WOL_NET%"
