Param ([string]$mode)
Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force

#$SourceServerPath	= "\\192.168.1.1\ARCHIVE$"
$SourceServerPath	= "\\192.168.1.1\BACKUP$"
$SourceServerLogin	= "DOMAIN\user"
$SourceServerPassword	= "password"
$SourceDriveLetter	= "X:"
$SourcePath		= "\"

$DestinationServerPath	= "\\192.168.199.200\HDD"
$DestinationServerLogin	= $SourceServerLogin
$DestinationServerPassword	= $SourceServerPassword
$DestinationDriveLetter	= "Y:"
#$DestinationPath	= "\ARCHIVE\"
$DestinationPath	= "\BACKUP\"

$LogPath = "D:\REPORTS"
$LogFileName = (Get-Date -format "yyyy-MM-dd_HH-mm-ss") + ".txt"
$LogFullFileName = $LogPath + "\" + $LogFileName

$ExcludesList	= "FOLDER-01", "FOLDER-02", "FOLDER-03", "TEMP"

# Skip checking file integrity:
#$FastMode = $true
$FastMode = $false
# Seconds to wait before start a new attempt (after error):
$WaitTime = 3
# Maximum retries to copy (if get an error):
$AttemptsLimit = 10

If (($mode) -and ($mode -eq "quick")) {
	$FastMode = $true
}

Function Format-FileSize() {
	Param ([long]$size)
	If	($size -gt 1TB)	{[string]::Format("{0:0.00} TB", $size / 1TB)}
	ElseIf	($size -gt 1GB)	{[string]::Format("{0:0.00} GB", $size / 1GB)}
	ElseIf	($size -gt 1MB)	{[string]::Format("{0:0.00} MB", $size / 1MB)}
	ElseIf	($size -gt 1KB)	{[string]::Format("{0:0.00} kB", $size / 1KB)}
	ElseIf	($size -gt 0)	{[string]::Format("{0:0.00} B", $size)}
	Else			{""}
}

Function MD5() {
	Param([string]$file)
	$md5		= [System.Security.Cryptography.HashAlgorithm]::Create("MD5")
	$IO		= New-Object System.IO.FileStream($file, [System.IO.FileMode]::Open, ([IO.FileAccess]::Read), ([IO.FileShare]::Read))
	$StringBuilder 	= New-Object System.Text.StringBuilder
	$md5.ComputeHash($IO) | % { [void] $StringBuilder.Append($_.ToString("x2")) }
	$hash		= $StringBuilder.ToString() 
	$IO.Dispose()
	return $hash
}

Function Copy-File() {
	Param([string]$from, [string]$to, [string]$log)
	$SourceFile = [io.file]::OpenRead($from)
	$DestinationFile = [io.file]::OpenWrite($to)
	If (Test-Path -Path $log) {
		$LogFullFileName = $log
	}
	$FlagPercentComplete = 10
	Try {
		$StopwatchTimer = [System.Diagnostics.Stopwatch]::StartNew()
		[byte[]]$CopyBufferSize = new-object byte[] (4096*1024)
		[long]$total = [long]$count = 0
		Do {
			$count = $SourceFile.Read($CopyBufferSize, 0, $CopyBufferSize.Length)
			$DestinationFile.Write($CopyBufferSize, 0, $count)
			$total += $count
			[int]$PercentComplete = [int]($total/$SourceFile.Length*100)
			[int]$TimeElapsed = [int](($StopwatchTimer.elapsedmilliseconds.ToString())/1000)
			If ($TimeElapsed -ne 0) {
				[single]$DataTransferRate = (($total/$TimeElapsed)/1mb)
# [single]$DataTransferRate = [math]::Round(($total/$TimeElapsed)/1KB,2)
			} Else {
				[single]$DataTransferRate = 0.0
			}

			If ($total % 1mb -eq 0) {
				If ($PercentComplete -gt 0) {
					[int]$TimeRemaining = ((($TimeElapsed/$PercentComplete)*100) - $TimeElapsed)
				} Else {
					[int]$TimeRemaining = 0
				}
				If ($PercentComplete -ge $FlagPercentComplete) {
					If ($PercentComplete -lt ($FlagPercentComplete + 10)) {
						$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	File '" + ($from.Split("\")|select -last 1) + "' copying complete " + $PercentComplete.ToString() + "% (Time Elapsed: " + (New-TimeSpan -Seconds $TimeElapsed) + "; Time Remaining: " + (New-TimeSpan -Seconds $TimeRemaining) + "; DTR: " + "{0:n2}" -f $DataTransferRate + " MB/s)"
						Write-Host $MessageText
						If ($LogFullFileName) {
							$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
						}
					}
					$FlagPercentComplete = $FlagPercentComplete + 10
				}
				Write-Progress `
					-Id 0 `
					-Activity ("Copying '" + ($from.Split("\")|select -last 1) + "':") `
					-Status ("Complete: " + $PercentComplete.ToString() + "% ; DTR: " + "{0:n2}" -f $DataTransferRate + " MB/s") `
					-PercentComplete $PercentComplete `
					-CurrentOperation ("Time Elapsed: " + (New-TimeSpan -Seconds $TimeElapsed) + " ; Time Remaining: " + (New-TimeSpan -Seconds $TimeRemaining))
#					-SecondsRemaining $TimeRemaining `
			}
		} While ($count -gt 0)
		Write-Progress -Id 0 -Activity ("Copying '" + ($from.Split("\")|select -last 1) + "': completed") -Completed
		$StopwatchTimer.Stop()
		$StopwatchTimer.Reset()
	}
	finally {
		Remove-Variable -Name "FlagPercentComplete"
		If ($TimeElapsed -ge 1) {
			$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File '" + ($from.Split("\")|select -last 1) + "' copied in " + (New-TimeSpan -Seconds $TimeElapsed) + " at " + "{0:n2}" -f [int](($SourceFile.length/$TimeElapsed)/1mb) + " MB/s"
		} Else {
			$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File '" + ($from.Split("\")|select -last 1) + "' copied in " + (New-TimeSpan -Seconds $TimeElapsed)
		}
		Write-Host $MessageText
		If ($LogFullFileName) {
			$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
		}
		$SourceFile.Close()
		$DestinationFile.Close()
	}
}


Function Copy-Backup() {
	Param (
		[string]$SourceServerPath, [string]$SourceServerLogin, [string]$SourceServerPassword, [string]$SourceDriveLetter, [string]$SourcePath,
		[string]$DestinationServerPath, [string]$DestinationServerLogin, [string]$DestinationServerPassword , [string]$DestinationDriveLetter, [string]$DestinationPath,
		[string]$LogPath, [string]$LogFileName, [string]$LogFullFileName, [boolean]$FastMode, [int]$WaitTime, [int]$AttemptsLimit
	)

	$StopwatchTimer = [System.Diagnostics.Stopwatch]::StartNew()

	$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	[START]"
	Write-Host $MessageText
	$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName

	If (-not (Test-Path -Path $SourceDriveLetter)) {
		$SourceNetworkDrive = new-object -ComObject WScript.Network
		$SourceNetworkDrive.MapNetworkDrive($SourceDriveLetter, $SourceServerPath, $false, $SourceServerLogin, $SourceServerPassword)
		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Connected source drive '" + $SourceDriveLetter + "' ('" + $SourceServerPath + "')."
		Write-Host $MessageText
		$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName

		$SourceDriveSpace = Get-WmiObject -Class Win32_LogicalDisk -Computername localhost | WHERE {$_.DeviceID -eq $SourceDriveLetter}
		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Source drive '" + $SourceDriveLetter + "' free space: " + (Format-FileSize -size $SourceDriveSpace.FreeSpace) + " (of total: " + (Format-FileSize -size $SourceDriveSpace.Size) + ")."
		Write-Host $MessageText
		$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName

		If (-not (Test-Path -Path $DestinationDriveLetter)) {
			$DestinationNetworkDrive = new-object -ComObject WScript.Network
			$DestinationNetworkDrive.MapNetworkDrive($DestinationDriveLetter, $DestinationServerPath, $false, $DestinationServerLogin, $DestinationServerPassword)
			$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Connected destination drive '" + $DestinationDriveLetter + "' ('" + $DestinationServerPath + "')."
			Write-Host $MessageText 
			$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName

			$DestinationDriveSpace = Get-WmiObject -Class Win32_LogicalDisk -Computername localhost | WHERE {$_.DeviceID -eq $DestinationDriveLetter}
			$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Destination drive '" + $DestinationDriveLetter + "' free space: " + (Format-FileSize -size $DestinationDriveSpace.FreeSpace) + " (of total: " + (Format-FileSize -size $DestinationDriveSpace.Size) + ")."
			Write-Host $MessageText
			$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName

#			Remove-Item ($DestinationDriveLetter + $DestinationPath + "\*") -Recurse
#			Write-Host ("RESULT	Removed files and folders from '" + $DestinationDriveLetter + $DestinationPath + "'.")
#			Copy-Item -Path ($SourceDriveLetter + $SourcePath + "\*") -Destination ($DestinationDriveLetter + $DestinationPath) -Recurse -Force
#			Write-Host ("RESULT	Copied files and folders from '" + $SourceDriveLetter + $SourcePath + "' to '" + $DestinationDriveLetter + $DestinationPath + "'.")

			$SRC_DIR = $SourceDriveLetter + $SourcePath
			$DST_DIR = $DestinationDriveLetter + $DestinationPath

			Write-Host "`r`n"
			$MessageText = "" | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName

			$FlagBackupRemoved = "no"
# Remove files deleted from the source on destination:
			$DestinationFiles = GCI -Recurse $DST_DIR | ? { $_.PSIsContainer -eq $false}
# Loop through the source dir files:
			$DestinationFiles | % {
				$DestinationFileCurrent = $_.FullName
				$SourceFileCurrent = $DestinationFileCurrent -replace $DST_DIR.Replace('\','\\'),$SRC_DIR
				If (-not (Test-Path -Path $SourceFileCurrent)) {
					$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Found file '" + $DestinationFileCurrent + "' in '" + $DST_DIR + "', but not in '" + $SRC_DIR + "'. Removing file..."
					Write-Host $MessageText
					$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
					Remove-Item -Path $DestinationFileCurrent -Force
					$FlagBackupRemoved = "yes"
				}
			}
			If ($FlagBackupRemoved -eq "yes") {
				Write-Host "`r`n"
				$MessageText = "" | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
			}
			Remove-Variable -Name FlagBackupRemoved -ErrorAction SilentlyContinue

# Get the files in the source dir.
			$SourceFiles = GCI -Recurse $SRC_DIR | ? { $_.PSIsContainer -eq $false }
# Only "*.pdf":
#			$SourceFiles = GCI -Recurse $SRC_DIR | ? { $_.PSIsContainer -eq $false -and $_.extension -eq ‘.pdf’}
# Loop through the source dir files:
			$SourceFiles | % {
# Current source dir file:
				$SourceFileCurrent = $_.FullName
				$SourceFolderCurrent = Split-Path (Split-Path $SourceFileCurrent -Parent) -Leaf
				$SkipFileCurrent = $false

				ForEach ($Excludes in $ExcludesList) {
					If ($SourceFolderCurrent -eq $Excludes) {
						$SkipFileCurrent = $true
						$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Folder '" + $SourceFolderCurrent + "' is in a excludes list, skipping file '" + $SourceFileCurrent + "'..."
						Write-Host $MessageText
						$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
					}
				}

				If ($SkipFileCurrent -eq $false) {

					$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Checking file: '" + $SourceFileCurrent + "'..."
					Write-Host $MessageText
					$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
# Current source file size:
					$SourceFileSize = (Get-Item $SourceFileCurrent).length
					$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Source file size: " + (Format-FileSize -size $SourceFileSize) + " (" + $SourceFileSize + " bites)"
					Write-Host $MessageText
					$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
# Current destination dir file:
					$DestinationFileCurrent = $SourceFileCurrent -replace $SRC_DIR.Replace('\','\\'),$DST_DIR
# Checking destination:
					While (-not (Test-Path -Path $DST_DIR)) {
						$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Destination folder is unavailable! Waiting for destination drive..."
						Write-Host $MessageText
						$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
						start-sleep -s $WaitTime
					}
# Default flag:
					$SuccessfulFlag = $false
# Counter ot attempts:
					$AttemptCount = 0

					While (-not ($SuccessfulFlag)) {

						$ErrorFlag = $false
# If it a first attempt, - just check a size:
						If ($AttemptCount -eq 0) {
# If file exists in destination folder...
							If ((Test-Path -Path  $SRC_DIR) -and (-not (Test-Path -Path $SourceFileCurrent))) {
								$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Source file not found!"
								Write-Host $MessageText
								$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
								$ErrorFlag = $true

								$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Skip copying file from '" + $SourceFileCurrent + "'."
								Write-Host $MessageText
								$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
								$CopyFlag = $false

								Write-Host "`r`n"
								$MessageText = "" | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
								$SuccessfulFlag = $true
							} Else {
								If (Test-Path -Path $DestinationFileCurrent) {

									$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Found the same file in a destination folder: '" + $DestinationFileCurrent + "'"
									Write-Host $MessageText
									$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName

									If ($FastMode -eq $true) {
# Check file size:
										If ($SourceFileSize -gt 0) {
											$DestinationFileSize = (Get-Item $DestinationFileCurrent).length
											$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Destination file size: " + (Format-FileSize -size $DestinationFileSize) + " (" + $DestinationFileSize + " bites)"
											Write-Host $MessageText
											$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											If ($DestinationFileSize -gt 0) {
												If ($SourceFileSize -eq $DestinationFileSize) {
													$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File sizes match. File already exists in destination folder, copying will be skipped."
													Write-Host $MessageText
													$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
													$CopyFlag = $false
												} Else {
													$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File sizes don't match. File will be copied to destination folder."
													Write-Host $MessageText
													$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
													$CopyFlag = $true
												}
											} Else {
												$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Destination file is empty."
												Write-Host $MessageText
												$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
												$CopyFlag = $true
											}
										} Else {
											$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Source file is empty."
											Write-Host $MessageText
											$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											$ErrorFlag = $true
											$CopyFlag = $false
										}
									} Else {
# Check MD5 hash:
										$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Begin calculation of source file hash..."
										Write-Host $MessageText
										$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
										$SourceFileCurrentMD5 = MD5 -file $SourceFileCurrent
										If ($SourceFileCurrentMD5.length -gt 0) {
											$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Source file hash: " + $SourceFileCurrentMD5
											Write-Host $MessageText
											$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Begin calculation of destination file hash..."
											Write-Host $MessageText
											$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											$DestinationFileCurrentMD5 = MD5 -file $DestinationFileCurrent
											If ($DestinationFileCurrentMD5.length -gt 0) {
												$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Destination file hash: " + $DestinationFileCurrentMD5
												Write-Host $MessageText
												$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
# If the MD5 hashes match then the files are the same:
												If ($SourceFileCurrentMD5 -eq $DestinationFileCurrentMD5) {
													$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File hashes match. File already exists in destination folder and will be skipped."
													Write-Host $MessageText
													$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
													$CopyFlag = $false
													$SuccessfulFlag = $true
# If the MD5 hashes are different then copy the file and overwrite the older version in the destination dir:
												} Else {
													$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File hashes don't match. File will be copied to destination folder."
													Write-Host $MessageText
													$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
													$CopyFlag = $true
												}
											} Else {
												$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Cann't get destination file hash!"
												Write-Host $MessageText
												$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
												$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Skip copying file to '" + $DestinationFileCurrent + "'."
												Write-Host $MessageText
												$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
												$ErrorFlag = $true
												$CopyFlag = $false
											}
										} Else {
# If the MD5 of source file is empty (some errors?):
											$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Cann't get source file hash!"
											Write-Host $MessageText
											$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Skip copying file from '" + $SourceFileCurrent + "'."
											Write-Host $MessageText
											$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											$ErrorFlag = $true
											$CopyFlag = $false
										}
									}
# If the file doesn't in the destination dir it will be copied:
								} Else {
									$DestinationDriveSpace = Get-WmiObject -Class Win32_LogicalDisk -Computername localhost | WHERE {$_.DeviceID -eq $DestinationDriveLetter}
# Checking free space before copy process:
									If ($SourceFileSize -lt $DestinationDriveSpace.FreeSpace) {
										$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File doesn't exist in destination folder and will be copied."
										Write-Host $MessageText
										$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
										$CopyFlag = $true
									} Else {
										$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Not enough free space: destination drive free space is " + (Format-FileSize -size $DestinationDriveSpace.FreeSpace) + " and the source file size is " + (Format-FileSize -size $SourceFileSize) + ". File will be skipped."
										Write-Host $MessageText
										$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
										$CopyFlag = $false
									}
								}
							}
						} Else {
							If ($StopwatchTimer.Elapsed.TotalHours -lt 24) {
								$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Last attempt of copying was unsuccessful. Retry # " + $AttemptCount + " ..."
								Write-Host $MessageText
								$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
								start-sleep -s $WaitTime
							} Else {
								$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Last attempt of copying was unsuccessful. Script running over " + $StopwatchTimer.Elapsed.TotalHours.ToString() + " hours. Quit..."
								Write-Host $MessageText
								$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
								start-sleep -s $WaitTime
								$ErrorFlag = $true
							}
						}
						If ($ErrorFlag -eq $false) {
# Copy the file if file version is newer or if it doesn't exist in the destination dir:
							If ($CopyFlag -eq $true) {
								$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Copying from '" + $SourceFileCurrent + "' to '" + $DestinationFileCurrent +"' ..."
								Write-Host $MessageText
								$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
								If (Test-Path -Path $DestinationFileCurrent) {
									Remove-Item -Path $DestinationFileCurrent -Force | Out-Null
								}
								New-Item -ItemType "File" -Path $DestinationFileCurrent -Force | Out-Null
#								$CopyTime = Measure-Command -Expression {
#									Copy-Item -Path $SourceFileCurrent -Destination $DestinationFileCurrent -Force | Out-Null
#								}
# $SourceFileSize / $CopyTime
								Copy-File -From $SourceFileCurrent -To $DestinationFileCurrent -Log $LogFullFileName

#								$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Finished copying '" + $DestinationFileCurrent + "'."
#								Write-Host $MessageText
#								$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
							}
# Check for results:
							If ($SuccessfulFlag -eq $false) {
# If it a first attempt...
								If (($AttemptCount -eq 0) -and ($CopyFlag -eq $false)) {
									If ($FastMode -ne $true) {
										$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Checking destination file integrity:"
										Write-Host $MessageText
										$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
									}
								} Else {
									$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Checking copy results:"
									Write-Host $MessageText
									$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
								}
								If ($FastMode -ne $true) {
									$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Begin calculation of source file hash..."
									Write-Host $MessageText
									$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
									$SourceFileCurrentMD5 = MD5 -file $SourceFileCurrent
									$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Source file hash: " + $SourceFileCurrentMD5
									Write-Host $MessageText
									$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
									$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "PROCESS	Begin calculation of destination file hash..."
									Write-Host $MessageText
									$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
									$DestinationFileCurrentMD5 = MD5 -file $DestinationFileCurrent
									$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Destination file hash: " + $DestinationFileCurrentMD5
									Write-Host $MessageText
									$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
									If ($SourceFileCurrentMD5 -eq $DestinationFileCurrentMD5) {
										If ($AttemptCount -eq 0) {
											If ($CopyFlag -eq $false) {
												$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File hashes match. Destination file integrity is OK."
												Write-Host $MessageText
												$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											} Else {
												$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File hashes match. Copying successful."
												Write-Host $MessageText
												$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											}
										} Else {
											$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File hashes match. Copying successful on attept #" + $AttemptCount + "."
											Write-Host $MessageText
											$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
										}
										Write-Host "`r`n"
										$MessageText = "" | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
										$SuccessfulFlag = $true
									} Else {
										$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	File hashes don't match! Copying unsuccessful."
										Write-Host $MessageText
										$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
										$SuccessfulFlag = $false
									}
								} Else {
									If ($CopyFlag -eq $true) {
										$SourceFileSize = (Get-Item $SourceFileCurrent).length
										$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Source file size: " + (Format-FileSize -size $SourceFileSize) + " (" + $SourceFileSize + " bites)"
										Write-Host $MessageText
										$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
										If ($SourceFileSize -gt 0) {
											If (Test-Path -Path $DestinationFileCurrent) {
												$DestinationFileSize = (Get-Item $DestinationFileCurrent).length
												$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Destination file size: " + (Format-FileSize -size $DestinationFileSize) + " (" + $DestinationFileSize + " bites)"
												Write-Host $MessageText
												$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
												If ($DestinationFileSize -gt 0) {
													If ($SourceFileSize -eq $DestinationFileSize) {
														$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	File sizes match. Copying successful (working in 'FastMode': no check of destination file integrity)."
														Write-Host $MessageText
														$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
														$SuccessfulFlag = $true
														Write-Host "`r`n"
														$MessageText = "" | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
													} Else {
														$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	File sizes don't match! Copying unsuccessful."
														Write-Host $MessageText
														$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
														$ErrorFlag = $true
														$SuccessfulFlag = $false
													}
												} Else {
													$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Destination file is empty."
													Write-Host $MessageText
													$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
													$ErrorFlag = $true
													$SuccessfulFlag = $false
												}
											} Else {
												$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Destination file not found."
												Write-Host $MessageText
												$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
												$ErrorFlag = $true
												$SuccessfulFlag = $false
											}
										} Else {
											$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Source file is empty."
											Write-Host $MessageText
											$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
											$ErrorFlag = $true
											$SuccessfulFlag = $false
										}
									} Else {
										$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Working in 'FastMode': no check of destination file integrity."
										Write-Host $MessageText
										$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
										$SuccessfulFlag = $true
										Write-Host "`r`n"
										$MessageText = "" | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
									}
								}
							} Else {
								Write-Host "`r`n"
								$MessageText = "" | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
							}
						}
						If (($SuccessfulFlag -eq $false) -and ($AttemptCount -ge $AttemptsLimit)) {
							$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Maximum (" + $AttemptsLimit + ") retries (of copying file) exceeded. Skipping..."
							Write-Host $MessageText
							$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
							$SuccessfulFlag = $true
							Write-Host "`r`n"
							$MessageText = "" | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
						} Else {
							$AttemptCount = $AttemptCount + 1
						}
					}
				}
			}

# Get result of process:
			$DestinationDriveSpace = Get-WmiObject -Class Win32_LogicalDisk -Computername localhost | WHERE {$_.DeviceID -eq $DestinationDriveLetter}
			$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Destination drive '" + $DestinationDriveLetter + "' free space: " + (Format-FileSize -size $DestinationDriveSpace.FreeSpace) + " (of total: " + (Format-FileSize -size $DestinationDriveSpace.Size) + ")."
			Write-Host $MessageText
			$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
			$SourceDriveSpace = Get-WmiObject -Class Win32_LogicalDisk -Computername localhost | WHERE {$_.DeviceID -eq $SourceDriveLetter}
			$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "INFO	Source drive '" + $SourceDriveLetter + "' free space: " + (Format-FileSize -size $SourceDriveSpace.FreeSpace) + " (of total: " + (Format-FileSize -size $SourceDriveSpace.Size) + ")."
			Write-Host $MessageText
			$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
# Remove mapping of network destination share:
			$DestinationNetworkDrive.RemoveNetworkDrive($DestinationDriveLetter)
			$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Disconnected drive '" + $DestinationDriveLetter + "'."
			Write-Host $MessageText
			$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
		} Else {
			$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Drive '" + $DestinationDriveLetter + "' is already connected. Please disconnect it."
			Write-Host $MessageText
			$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
		}
# Remove mapping of network source share:
		$SourceNetworkDrive.RemoveNetworkDrive($SourceDriveLetter)
		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "RESULT	Disconnected drive '" + $SourceDriveLetter + "'."
		Write-Host $MessageText
		$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
	} Else {
		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "ERROR	Drive '" + $SourceDriveLetter + "' is already connected. Please disconnect it."
		Write-Host $MessageText
		$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName
	}

	$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	[END]"
	Write-Host $MessageText
	$MessageText | Out-File -Encoding ASCII -Append -Force -FilePath $LogFullFileName

	[int]$TimeElapsed = [int]($StopwatchTimer.Elapsed.TotalHours)

	$StopwatchTimer.Stop()
	$StopwatchTimer.Reset()

	If ($TimeElapsed -gt 24) {
		Copy-Backup `
			-SourceServerPath $SourceServerPath -SourceServerLogin $SourceServerLogin -SourceServerPassword $SourceServerPassword -SourceDriveLetter $SourceDriveLetter -SourcePath $SourcePath  `
			-DestinationServerPath $DestinationServerPath -DestinationServerLogin $DestinationServerLogin -DestinationServerPassword $DestinationServerPassword -DestinationDriveLetter $DestinationDriveLetter -DestinationPath $DestinationPath `
			-LogPath $LogPath -LogFileName $LogFileName -LogFullFileName $LogFullFileName -FastMode $FastMode -WaitTime $WaitTime -AttemptsLimit $AttemptsLimit
	}
}

Copy-Backup `
	-SourceServerPath $SourceServerPath -SourceServerLogin $SourceServerLogin -SourceServerPassword $SourceServerPassword -SourceDriveLetter $SourceDriveLetter -SourcePath $SourcePath  `
	-DestinationServerPath $DestinationServerPath -DestinationServerLogin $DestinationServerLogin -DestinationServerPassword $DestinationServerPassword -DestinationDriveLetter $DestinationDriveLetter -DestinationPath $DestinationPath `
	-LogPath $LogPath -LogFileName $LogFileName -LogFullFileName $LogFullFileName -FastMode $FastMode -WaitTime $WaitTime -AttemptsLimit $AttemptsLimit
