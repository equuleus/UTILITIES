Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force
$strSSID="NETWORK"
Clear-Host

Function NetAdapterCheck ($objNetAdapter, $strSSID, $strAttempt) {
	If (($strAttempt -eq $null) -or ([int]$strAttempt -le 0)) {
		[int]$strAttempt = 1
	} Else {
		[int]$strAttempt = [int]$strAttempt + 1
	}
	$objConnectionProfile = Get-NetConnectionProfile -InterfaceIndex $objNetAdapter.InterfaceIndex
	$strNetwork = """" + $objConnectionProfile.Name  + """ (""" + $objConnectionProfile.NetworkCategory + """, """ + $objConnectionProfile.IPv4Connectivity + """)"
	If (($objConnectionProfile.Name -like $strSSID) -and ($objConnectionProfile.NetworkCategory -like "Private")) {
#	If (($objConnectionProfile.Name -like $strSSID) -and (($objConnectionProfile.NetworkCategory -like "Private") -or ($objConnectionProfile.NetworkCategory -like "Public"))) {
		Write-Host -NoNewline -BackgroundColor DarkGreen ([char]8730)
		Write-Host -NoNewline -ForegroundColor Green " CONNECTED"
		Write-Host -ForegroundColor White (" to: " + $strNetwork)
	} Else {
		Write-Host -NoNewline -BackgroundColor DarkRed ([char]215)
		Write-Host -NoNewline -ForegroundColor Red " NOT CONNECTED"
		Write-Host -ForegroundColor White (" to: " + $strNetwork)
		NetAdapterRestart $objNetAdapter $strSSID
		If ([int]$strAttempt -le 10) {
			Start-Sleep 30
			NetAdapterCheck $objNetAdapter $strSSID
		}
	}
}

Function NetAdapterRestart ($objNetAdapter, $strSSID) {
	Disable-NetAdapter -Name $objNetAdapter.Name -Confirm:$false | Out-Null
	Start-Sleep 3
	Enable-NetAdapter -Name $objNetAdapter.Name -Confirm:$false | Out-Null
	Start-Sleep 3
	Invoke-Expression ("netsh wlan connect ssid=" + $strSSID + " name= " + $strSSID) | Out-Null
	Start-Sleep 10
}

ForEach ($objNetAdapter in (Get-NetAdapter -Physical)) {
	If (($objNetAdapter.Name -like "*Wireless*") -or ($objNetAdapter.InterfaceDescription -like "*Wireless*")) {
		$strNetAdapter = """" + $objNetAdapter.InterfaceDescription + """ (""" + $objNetAdapter.Name + """)"
		Write-Host -NoNewline -BackgroundColor DarkYellow ([char]8734)
		Write-Host -NoNewline -ForegroundColor Yellow " FOUND"
		Write-Host -ForegroundColor White (" NIC: " + $strNetAdapter)
		If  ((Get-WmiObject -ClassName Win32_NetworkAdapter | Where-Object {$_.Description -like $objNetAdapter.InterfaceDescription}).NetConnectionStatus -ne 2) {
			Write-Host -NoNewline -BackgroundColor DarkRed ([char]215)
			Write-Host -NoNewline -ForegroundColor Red " NOT CONNECTED"
			Write-Host -ForegroundColor White (" to: " + $strSSID)
			NetAdapterRestart $objNetAdapter $strSSID
		}
		NetAdapterCheck $objNetAdapter $strSSID
	}
}
