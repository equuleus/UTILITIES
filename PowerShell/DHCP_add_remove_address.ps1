# DHCP Server:
$strDHCPServer = "192.168.0.1"
# DHCP Pool o addresses [192.168.1.0/255.255.255.0]:
$strDHCPPoolIPBase = "192.168.1."

### To add unavailable address "101" and move all existing addresses with +1:
# Add address begins from (reverse order - from 199 to 101):
$strDHCPPoolIPStart = 199
# Add address till ends at:
$strDHCPPoolIPEnd = 101

### To remove available address "101" and move all existing addresses with -1:
# Remove address begins from (forward order - from 101 to 199):
$strDHCPPoolIPStart = 101
# Remove address till ends at:
$strDHCPPoolIPEnd = 199


Function DHCP ($strDHCPServer, $strDHCPIPAddressOld, $strDHCPIPAddressNew) {
	If (Get-DhcpServerv4Scope -ComputerName $strDHCPServer | Get-DhcpServerv4Reservation -ComputerName $strDHCPServer | Where {$_.ipaddress -eq $strDHCPIPAddressOld}) {
# Current Reservation Description:
		$strDHCPDescription = Get-DhcpServerv4Scope -ComputerName $strDHCPServer | Get-DhcpServerv4Reservation -ComputerName $strDHCPServer | Where {$_.ipaddress -eq $strDHCPIPAddressOld} | Select -ExpandProperty "description"
# Current Reservation Scope ID:
		$strDHCPScopeID = Get-DhcpServerv4Scope -ComputerName $strDHCPServer | Get-DhcpServerv4Reservation -ComputerName $strDHCPServer | Where {$_.ipaddress -eq $strDHCPIPAddressOld} | ForEach {$_.scopeid.ipaddresstostring}
# Current Reservation MAC:
		$strDHCPMAC = Get-DhcpServerv4Scope -ComputerName $strDHCPServer|  Get-DhcpServerv4Reservation -ComputerName $strDHCPServer | Where {$_.ipaddress -eq $strDHCPIPAddressOld} | Select -ExpandProperty "clientid"
# Current Reservation Name:
		$strDHCPName = Get-DhcpServerv4Scope -ComputerName $strDHCPServer|  Get-DhcpServerv4Reservation -ComputerName $strDHCPServer | Where {$_.ipaddress -eq $strDHCPIPAddressOld} | Select -ExpandProperty "name"
# Delete Current Reservation:
		Remove-DhcpServerv4Reservation -ComputerName $strDHCPServer -IP $strDHCPIPAddressOld
# Recreate Reservation With New IP:
		Add-DhcpServerv4Reservation -ComputerName $strDHCPServer -Name $strDHCPName -ScopeId $strDHCPScopeID -IPAddress $strDHCPIPAddressNew -ClientId $strDHCPMAC -Description $strDHCPDescription
# Result:
		Write-Host ("Changed IP reservation on DHCP Server """ + $strDHCPServer + """ in DHCP Scope """ + $strDHCPScopeID  + """: from """ + $strDHCPIPAddressOld + """ to """ + $strDHCPIPAddressNew + """ (Name: """ + $strDHCPName + """, MAC: """ + $strDHCPMAC + """, Description: """ + $strDHCPDescription + """)")
	}
}

if ($strDHCPPoolIPStart -gt $strDHCPPoolIPEnd) {
# Counter in reverse order:
	For ($i = $strDHCPPoolIPStart; $i -ge $strDHCPPoolIPEnd; $i--) {
#For ($i = $strDHCPPoolIPStart; $i -le $strDHCPPoolIPEnd; $i++) {
# IP to Change:
		$strDHCPIPAddressOld = $strDHCPPoolIPBase + $i
# New IP (add +1 to address):
		$strDHCPIPAddressNew = $strDHCPPoolIPBase + ($i + 1)
# DHCP:
		DHCP $strDHCPServer $strDHCPIPAddressOld $strDHCPIPAddressNew
	}
}

if ($strDHCPPoolIPStart -lt $strDHCPPoolIPEnd) {
	For ($i = $strDHCPPoolIPStart; $i -le $strDHCPPoolIPEnd; $i++) {
# IP to Change:
		$strDHCPIPAddressOld = $strDHCPPoolIPBase + $i
# New IP (remove -1 to address):
		$strDHCPIPAddressNew = $strDHCPPoolIPBase + ($i - 1)
# DHCP:
		DHCP $strDHCPServer $strDHCPIPAddressOld $strDHCPIPAddressNew
	}
}
