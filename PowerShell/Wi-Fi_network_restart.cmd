rem @"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy unrestricted -windowstyle hidden -file ".\Wi-Fi_network_restart.ps1"
@"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -executionpolicy unrestricted -file ".\Wi-Fi_network_restart.ps1"
pause
rem Import scheduled task:
rem schtasks /create /xml ".\Wi-Fi_network_restart.xml" /tn "\TASKSCHEDULER-FOLDER-PATH\Wi-Fi Network Restart" /ru "COMPUTER\Administrator"
