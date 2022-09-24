Param ([string]$MACAddress, [string]$BroadcastAddress)
Function WakeOnLAN ([string]$MACAddress, [IPAddress]$BroadcastAddress) {
	Try {
## Create UDP client instance:
		$UdpClient = New-Object Net.Sockets.UdpClient
## Detecting broadcast address:
		If (($BroadcastAddress -ne $null) -and ($BroadcastAddress -ne "")) {
			$Broadcast = $BroadcastAddress
		} Else {
			$Broadcast = ([System.Net.IPAddress]::Broadcast)
		}
## Create IP endpoints for each port:
		$IPEndPoint = New-Object Net.IPEndPoint $Broadcast, 9
## Construct physical address instance for the MAC address of the machine (string to byte array):
		$MAC = [Net.NetworkInformation.PhysicalAddress]::Parse($MACAddress.ToUpper())
## Construct the Magic Packet frame:
		$Packet =  [Byte[]](,0xFF*6)+($MAC.GetAddressBytes()*16)
## Broadcast UDP packets to the IP endpoint of the machine:
		$UdpClient.Send($Packet, $Packet.Length, $IPEndPoint) | Out-Null
		$UdpClient.Close()
		Remove-Variable -Name Packet -Scope Script -ErrorAction SilentlyContinue
		Remove-Variable -Name MAC -Scope Script -ErrorAction SilentlyContinue
		Remove-Variable -Name IPEndPoint -Scope Script -ErrorAction SilentlyContinue
		Remove-Variable -Name Broadcast -Scope Script -ErrorAction SilentlyContinue
		Remove-Variable -Name UdpClient -Scope Script -ErrorAction SilentlyContinue
	} Catch {
		$UdpClient.Dispose()
		$Error | Write-Error
	}
	Remove-Variable -Name BroadcastAddress -Scope Script -ErrorAction SilentlyContinue
	Remove-Variable -Name MACAddress -Scope Script -ErrorAction SilentlyContinue
}
WakeOnLAN $MACAddress.Replace(":","").Trim() $BroadcastAddress.Trim()
