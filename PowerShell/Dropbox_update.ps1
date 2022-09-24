Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force
Clear-Host

Function Update {
#	[string]$strLocalRoot			= ".\SHARE"
	[string]$strLocalRoot			= Split-Path -Parent (Split-Path -Parent (((Get-Variable MyInvocation -Scope Script).Value).MyCommand.Path))
	[string]$strCloudRoot			= "/SHARE"
	[string]$script:strTempFolder		= $strLocalRoot + "\TEMP"
	[string]$script:strLogFolder		= $strLocalRoot + "\LOG"
	[string]$script:strLogFileName		= "update.log"
	[string]$script:strLogData		= ""
#	[string]$script:strLogFileName		= (Get-Date -format "yyyy-MM-dd_HH-mm-ss") + ".log"
	[int]$intScriptSleepTime		= 900
	[int]$intCloudWebRequestRetryTotal	= 5
	[int]$intCloudWebRequestSleepTime	= 15
# Encode / decode example:
#	$EncodedToken = [System.Text.Encoding]::UTF8.GetBytes($OriginalToken)
#	$OriginalToken = [System.Text.Encoding]::ASCII.GetString($EncodedToken)
# Cloud URL encoded array:
	[array]$objCloudURL			= @()
# Cloud token encoded array:
	[array]$objCloudToken			= @()
# API URL: https://www.dropbox.com/developers/apps
	[string]$strPSScriptFileName		= Split-Path -Leaf (((Get-Variable MyInvocation -Scope Script).Value).MyCommand.Path)
	[string]$strPSScriptFilePath		= Split-Path -Parent (((Get-Variable MyInvocation -Scope Script).Value).MyCommand.Path)
	[string]$strPSFilePath			= $env:SystemRoot + "\System32\WindowsPowerShell\v1.0\powershell.exe"
	[string]$strPSFileArguments		= "-ExecutionPolicy Unrestricted -File " + $strPSScriptFilePath + "\" + $strPSScriptFileName
# Run commands before and after update:
#	WindowStyle: Normal, Hidden, Minimized, and Maximized.
	[string]$strPSFileWindowStyle		= "Minimized"
	[string]$strCMDStartFileName		= "start.cmd"
	[string]$strCMDStartWindowStyle		= "Minimized"
	[string]$strCMDStopFileName		= "stop.cmd"
	[string]$strCMDStopWindowStyle		= "Minimized"
#	[string]$strLogFoldersAndFiles		= $true
	[string]$strLogFoldersAndFiles		= $false
	[string]$strLocalPath			= ""
	[string]$strCloudPath			= ""
	[hashtable]$objLocalPathFoldersList	= @{}
	[hashtable]$objLocalPathFilesList	= @{}
	[int]$script:intLocalFoldersCounter	= 0
	[int]$script:intLocalFilesCounter	= 0
	[hashtable]$objCloudPathFoldersList	= @{}
	[hashtable]$objCloudPathFilesList	= @{}
	[int]$script:intCloudFoldersCounter	= 0
	[int]$script:intCloudFilesCounter	= 0
	[hashtable]$objEmail			= @{}
# Username encoded array:
	$objEmail["ServerUsername"]		= @()
# Password encoded array:
	$objEmail["ServerPassword"]		= @()
	#$objEmail["ServerUsername"]		= "anonymous"
	#$objEmail["ServerPassword"]		= ConvertTo-SecureString "anonymous" -AsPlainText -Force
	$objEmail["ServerAddress"]		= "smtp.mail.ru"
	$objEmail["ServerPort"]			= "25"
	$objEmail["From"]			= "SCRIPT INFO <" + [System.Text.Encoding]::UTF8.GetString($objEmail.("ServerUsername")) + ">"
# E-Mail send-to encoded array address:
	$objEmail["To"]				= @("Administrator <" + [System.Text.Encoding]::UTF8.GetString(@()) + ">")
	$objEmail["Subject"]			= "SCRIPT INFO: UPDATE LOG ON """ + [System.Environment]::MachineName + """"
	$objEmail["Body"]			= ""
	#$objEmail["Encoding"]			= "Unicode"	# ASCII, UTF8, UTF7, UTF32, Unicode, BigEndianUnicode, Default, OEM
	$objEmail["AttachmentPath"]		= Split-Path -Parent (((Get-Variable MyInvocation -Scope Script).Value).MyCommand.Path)
	$objEmail["AttachmentFile"]		= ""
	If ((($objEmail.("AttachmentPath") -ne "") -and ($objEmail.("AttachmentFile") -ne "")) -and (Test-Path -Path ($objEmail.("AttachmentPath") + "\" + $objEmail.("AttachmentFile")))) {
		$objEmail["Attachment"]		= @($objEmail.("AttachmentPath") + "\" + $objEmail.("AttachmentFile"))
	} Else {
		$objEmail["Attachment"]		= @()
	}
	#$objEmail["Delivery"]			= "Never"	# OnSuccess, OnFailure, Delay, Never
	#$objEmail["Priority"]			= "Normal"	# Normal, High, and Low
	$objEmail["Credential"]			= New-Object System.Net.NetworkCredential([System.Text.Encoding]::UTF8.GetString($objEmail.("ServerUsername")), [System.Text.Encoding]::UTF8.GetString($objEmail.("ServerPassword")))
	If (Test-Path -Path ($script:strLogFolder + "\" + $script:strLogFileName)) { Remove-Item -Path ($script:strLogFolder + "\" + $script:strLogFileName) -Force }
	Clear-Host
	Update_LOG ""
	Update_LOG ("[STATUS]	Start indexing local root folder...")
	$objLocalPathList = Update_ListFolderLocal $strLocalRoot $strCloudPath $strLogFoldersAndFiles
	If (($script:intLocalFoldersCounter -gt 0) -or ($script:intLocalFilesCounter -gt 0)) {
		Update_LOG ""
		Update_LOG ("[STATUS]	Finish indexing local root folder. Total: " + $script:intLocalFoldersCounter + " folder(s) and " + $script:intLocalFilesCounter + " file(s).")
	}
	Update_LOG ""
	Update_LOG ("[STATUS]	Start indexing cloud root folder...")
	$objCloudPathList = Update_ListFolderCloud $strCloudRoot $strCloudPath $objCloudURL $objCloudToken $intCloudWebRequestRetryTotal $intCloudWebRequestSleepTime $strLogFoldersAndFiles
	If (($script:intCloudFoldersCounter -gt 0) -or ($script:intCloudFilesCounter -gt 0)) {
		Update_LOG ""
		Update_LOG ("[STATUS]	Finish indexing cloud root folder. Total: " + $script:intCloudFoldersCounter + " folder(s) and " + $script:intCloudFilesCounter + " file(s).")
		[int]$script:intSyncFoldersAddCounterTotal	= 0
		[int]$script:intSyncFoldersRemoveCounterTotal	= 0
		[int]$script:intSyncFilesAddCounterTotal	= 0
		[int]$script:intSyncFilesRemoveCounterTotal	= 0
		[int]$script:intSyncFilesUpdateCounterTotal	= 0
		$objLocalCompare = Update_Compare $strLocalRoot $strCloudRoot $objLocalPathList $objCloudPathList
		$strLocalSynchronize = Update_Synchronize $strLocalRoot $strCloudRoot $strCMDStartFileName $strCMDStartWindowStyle $strCMDStopFileName $strCMDStopWindowStyle $objCloudURL $objCloudToken $objLocalCompare
	} Else {
		Update_LOG ("[ERROR]	No folders or files found on a cloud root folder. This may be a connection error. Nothing to compare or synchronize.")
		Start-Sleep 10
	}
	If ($strLocalSynchronize -eq $false) {
		Clear-Host
		For ($i = 1; ($i -le $intScriptSleepTime); $i += 1) {
			Start-Sleep -Seconds 1
			$strTextActivity = "All " + $script:intLocalFoldersCounter + " folder(s) and " + $script:intLocalFilesCounter + " file(s) already synchronized."
			$strTextStatus = "[" + $i.ToString().PadLeft($intScriptSleepTime.ToString().Length, "0") + "/" + $intScriptSleepTime.ToString() + "] Waiting " + ($intScriptSleepTime - $i).ToString().PadLeft($intScriptSleepTime.ToString().Length, "0") + " seconds to restart update script..."
			Write-Progress -ID 1 -Activity $strTextActivity -Status $strTextStatus -PercentComplete ( $i * 100 / $intScriptSleepTime) -SecondsRemaining ($intScriptSleepTime - $i)
		}
		Write-Progress -ID 1 -Activity " " -Completed
		Return $true
	} Else {
		$strEmailBody = "COMPUTER """ + [System.Environment]::MachineName + """ UPDATE LOG: " + "`n" + $script:strLogData
		If ((Update_SendEmail $objEmail.("From") $objEmail.("To") $objEmail.("Subject") ($objEmail.("Body") + $strEmailBody) $objEmail.("Attachment") $objEmail.("ServerAddress") $objEmail.("ServerPort") $objEmail.("Credential")) -eq $true) {
			Update_LOG ("[INFO]	E-mail report was sent to: """ + $objEmail.("To") + """.")
		} Else {
			Update_LOG ("[ERROR]	E-mail report sending error.")
		}
		Remove-Variable -Name strEmailBody
		Return $false
	}
}

Function Update_LOG {
	Param(
		[string]$strMessageText
	)
	If ($strMessageText -eq "") {
#		$strMessageText = "`r`n"
		$strMessageText = ""
	} Else {
		$strMessageText = (Get-Date -format "yyyy-MM-dd HH:mm:ss") + "	" + $strMessageText
		$strMessageText | Out-File -Encoding ASCII -Append -Force -FilePath ($script:strLogFolder + "\" + $script:strLogFileName)
	}
	$script:strLogData += $strMessageText + "`n"
	Write-Host $strMessageText
}

Function Update_ListFolderLocal {
	Param(
		[string]$strLocalRoot,
		[string]$strLocalPath,
		[string]$strLogFoldersAndFiles
	)
	If ($strLocalPath -eq "") {
		$strLocalPathCurrent = $strLocalRoot
	} Else {
		$strLocalPathCurrent = $strLocalPath
	}
	$objLocalFilesList = Get-ChildItem -Path $strLocalPathCurrent | Where-Object { -not ($_.PsIsContainer) }
	If ($strLogFoldersAndFiles -eq $true) {
		Update_LOG ""
		Update_LOG ("[INFO]	Folder: """ + $strLocalPathCurrent.Split("\")[-1] + """ [path: """ + $strLocalPathCurrent + """]")
	}
	ForEach ($strLocalFile in $objLocalFilesList) {
		If (($strLocalFile -ne "") -and ($strLocalFile -ne $null)) {
			$strLocalFilePath = $strLocalPathCurrent + "\" + $strLocalFile
#			If ((Test-Path -Path $strLocalFilePath) -and ($strLocalFilePath -ne ($script:strLogFolder + "\" + $script:strLogFileName))) {
			If ((Test-Path -Path $strLocalFilePath) -and ($strLocalPathCurrent -ne $script:strTempFolder) -and ($strLocalPathCurrent -ne $script:strLogFolder)) {
				$strLocalFileName = $strLocalFile
				$strLocalFileSize = (Get-Item $strLocalFilePath).Length
				$strLocalFileHash = Update_CalculateFileHash $strLocalFilePath
				$strLocalPathFilesListID = $strLocalFilePath.SubString($strLocalRoot.Length).ToLower()
				$objLocalPathFilesList[$strLocalPathFilesListID] = @{}
				$objLocalPathFilesList[$strLocalPathFilesListID]["NAME"] = $strLocalFileName
				$objLocalPathFilesList[$strLocalPathFilesListID]["PATH"] = $strLocalFilePath
				$objLocalPathFilesList[$strLocalPathFilesListID]["SIZE"] = $strLocalFileSize
				$objLocalPathFilesList[$strLocalPathFilesListID]["HASH"] = $strLocalFileHash
				$script:intLocalFilesCounter = $script:intLocalFilesCounter + 1
				If ($strLogFoldersAndFiles -eq $true) {
					Update_LOG ("[INFO]		File: """ + $strLocalFileName + """ [path: """ + $strLocalFilePath + """, size: """ + $strLocalFileSize + """ bite(s), hash: """ + $strLocalFileHash + """]")
				}
			}
		}
	}
	$objLocalFoldersList = Get-ChildItem -Path $strLocalPathCurrent | Where-Object { $_.PsIsContainer }
	ForEach ($strLocalFolder in $objLocalFoldersList) {
		If (($strLocalFolder -ne "") -and ($strLocalFolder -ne $null)) {
			$strLocalFolderPath = $strLocalPathCurrent + "\" + $strLocalFolder
			If (Test-Path -Path $strLocalFolderPath) {
				$strLocalFolderName = $strLocalFolder
				$strLocalPathFoldersListID = $strLocalFolderPath.SubString($strLocalRoot.Length).ToLower()
				$objLocalPathFoldersList[$strLocalPathFoldersListID] = @{}
				$objLocalPathFoldersList[$strLocalPathFoldersListID]["NAME"] = $strLocalFolderName
				$objLocalPathFoldersList[$strLocalPathFoldersListID]["PATH"] = $strLocalFolderPath
				$script:intLocalFoldersCounter = $script:intLocalFoldersCounter + 1
#				If ($strLogFoldersAndFiles -eq $true) {
#					Update_LOG ("[INFO]	Folder: """ + $strLocalFolderName + """ [path: """ + $strLocalFolderPath + """]")
#					Update_LOG ""
#				}
				Update_ListFolderLocal $strLocalRoot $strLocalFolderPath $strLogFoldersAndFiles
			}
		}
	}
	If ($strLocalPath -eq "") {
		Return @{"FOLDERS" = $objLocalPathFoldersList; "FILES" = $objLocalPathFilesList}
	}
}

Function Update_ListFolderCloud {
	Param(
		[string]$strCloudRoot,
		[string]$strCloudPath,
		[array]$objCloudURL,
		[array]$objCloudToken,
		[int]$intCloudWebRequestRetryTotal,
		[int]$intCloudWebRequestSleepTime,
		[string]$strLogFoldersAndFiles
	)
	$strCloudURI	= "https://api.dropboxapi.com/2/files/list_folder"
	$strCloudHeader	= ""
	$strCloudBody	= ConvertTo-Json @{
		"path" = $strCloudPath
		"recursive" = $false
		"include_media_info" = $false
		"include_deleted" = $false
		"include_has_explicit_shared_members" = $false
		"include_mounted_folders" = $false
		"limit" = 1000
		"shared_link" = @{
			"url" = ([System.Text.Encoding]::UTF8.GetString($objCloudURL))
		}
	}
	[int]$intCloudWebRequestCounter = 0
	$strCloudWebRequestStatus = ""
	While (($strCloudWebRequestStatus -eq "") -and ($intCloudWebRequestCounter -lt $intCloudWebRequestRetryTotal)) {
		$intCloudWebRequestCounter = $intCloudWebRequestCounter + 1
		$objWebResponseResultListFolder = (Update_WebRequest $strCloudURI $objCloudToken $strCloudHeader $strCloudBody $strFilePath)[1]
		If ([int]$objWebResponseResultListFolder.("RESPONSE").StatusCode -eq "200") {
			$strCloudWebRequestStatus = $true
			If ($strLogFoldersAndFiles -eq $true) {
				Update_LOG ""
				If ($strCloudPath -eq "") {
					Update_LOG ("[INFO]	Folder: """ + $strCloudRoot.Split("/")[-1] + """ [path: """ + $strCloudRoot + """]")
				} Else {
					Update_LOG ("[INFO]	Folder: """ + $strCloudPath.Split("/")[-1] + """ [path: """ + $strCloudRoot + $strCloudPath + """]")
				}
			}
#			Update_LOG ("[INFO]	Server API answer: " + $objWebResponseResultListFolder.("RESULT"))
#			$objWebResponseResultListFolder = $objWebResponseResultListFolder.("RESULT") | ConvertFrom-JSON
			$objWebResponseResultListFolder = ConvertFrom-JSON $objWebResponseResultListFolder.("RESULT")
			ForEach ($objTemp in $objWebResponseResultListFolder.entries) {
				If ($objTemp.(".tag") -eq "file") {
					$strCloudFileName = $objTemp.("name")
					$strCloudFilePath = $objTemp.("path_display")
					$strCloudFileSize = $objTemp.("size")
					$strCloudFileDate = $objTemp.("client_modified")
#					$strCloudFileDate = $objTemp.("server_modified")
					$strCloudFileHash = $objTemp.("content_hash")
					$strCloudFileID = $objTemp.("id")
					$strCloudPathFilesListID = $strCloudFilePath.SubString($strCloudRoot.Length).Replace("/", "\").ToLower()
					$objCloudPathFilesList[$strCloudPathFilesListID] = @{}
					$objCloudPathFilesList[$strCloudPathFilesListID]["NAME"] = $strCloudFileName
					$objCloudPathFilesList[$strCloudPathFilesListID]["PATH"] = $strCloudFilePath
					$objCloudPathFilesList[$strCloudPathFilesListID]["SIZE"] = $strCloudFileSize
					$objCloudPathFilesList[$strCloudPathFilesListID]["DATE"] = $strCloudFileDate
					$objCloudPathFilesList[$strCloudPathFilesListID]["HASH"] = $strCloudFileHash
					$objCloudPathFilesList[$strCloudPathFilesListID]["ID"] = $strCloudFileID
					$script:intCloudFilesCounter = $script:intCloudFilesCounter + 1
					If ($strLogFoldersAndFiles -eq $true) {
						Update_LOG ("[INFO]		File: """ + $strCloudFileName + """ [path: """ + $strCloudFilePath + """, size: """ + $strCloudFileSize + """ bite(s), date: """ + $strCloudFileDate + """, hash: """ + $strCloudFileHash + """, id: """ + $strCloudFileID + """]")
					}
				}
			}
			ForEach ($objTemp in $objWebResponseResultListFolder.entries) {
				If (($objTemp.(".tag") -eq "folder") -and ($strCloudWebRequestStatus -ne $false)) {
					$strCloudFolderName = $objTemp.("name")
					$strCloudFolderPath = $objTemp.("path_display")
#					$strCloudFolderPath = $strCloudPath + "/" + $objTemp.("name")
					$strCloudFolderID = $objTemp.("id")
					$strCloudPathFoldersListID = $strCloudFolderPath.SubString($strCloudRoot.Length).Replace("/", "\").ToLower()
					$objCloudPathFoldersList[$strCloudPathFoldersListID] = @{}
					$objCloudPathFoldersList[$strCloudPathFoldersListID]["NAME"] = $strCloudFolderName
					$objCloudPathFoldersList[$strCloudPathFoldersListID]["PATH"] = $strCloudFolderPath
					$objCloudPathFoldersList[$strCloudPathFoldersListID]["ID"] = $strCloudFolderID
					$script:intCloudFoldersCounter = $script:intCloudFoldersCounter + 1
#					Update_LOG ""
#					Update_LOG ("[INFO]	Folder: """ + $strCloudFolderName + """ [path: """ + $strCloudFolderPath + """, id: """ + $strCloudFolderID + """]")
					$strCloudWebRequestStatus = Update_ListFolderCloud $strCloudRoot $strCloudFolderPath.SubString($strCloudRoot.Length) $objCloudURL $objCloudToken $intCloudWebRequestRetryTotal $intCloudWebRequestSleepTime $strLogFoldersAndFiles
					If ($objTemp.("has_more") -eq "true") {
#							Update_LOG ("Folder has more entries!!!")
# !!!
# while ($folders.has_more -eq "true") {
# ...
#					Update_ListFolderCloud ...
# https://api.dropboxapi.com/2/sharing/list_folder/continue
# --data "{\"cursor\": \"ZtkX9_EHj3x7PMkVuFIhwKYXEpwpLwyxp9vMKomUhllil9q7eWiAu\"}"
					}
				}
			}
		} Else {
			If ($strCloudWebRequestStatus -eq $false) {
				$intCloudWebRequestCounter = $intCloudWebRequestRetryTotal
			} Else {
				If ($strCloudPath -eq "") {
					Update_LOG ("[ERROR]		Answer from WebRequest while get info from folder """ + $strCloudRoot.Split("/")[-1] + """ [path: """ + $strCloudRoot + """].")
				} Else {
					Update_LOG ("[ERROR]		Answer from WebRequest while get info from folder """ + $strCloudPath.Split("/")[-1] + """ [path: """ + $strCloudRoot + $strCloudPath + """].")
				}
#				Update_LOG ("		Request to server API: " + $strCloudBody)
				If ([int]$objWebResponseResultListFolder.("RESPONSE").StatusCode -eq 0) {
					Update_LOG ("[ERROR]		No server answer. Can not conect to cloud API.")
				} Else {
					Update_LOG ("[ERROR]		Server API answer: " + [int]$objWebResponseResultListFolder.("RESPONSE").StatusCode + " - " + $objWebResponseResultListFolder.("RESPONSE").StatusCode + " (" + $objWebResponseResultListFolder.("RESPONSE").StatusDescription + ")")
				}
				If (($intCloudWebRequestCounter -lt $intCloudWebRequestRetryTotal)) {
					Update_LOG ("[ERROR]		Retry attempt " + $intCloudWebRequestCounter + " of " + $intCloudWebRequestRetryTotal + ". Waiting " + $intCloudWebRequestSleepTime + " seconds...")
					Start-Sleep -Seconds $intCloudWebRequestSleepTime
				} Else {
					$strCloudWebRequestStatus = $false
					Update_LOG ("[ERROR]		Maximum attempts (" + $intCloudWebRequestCounter + " of " + $intCloudWebRequestRetryTotal + ") reached. Canceling update process...")
				}
			}
		}
	}
	If ($strCloudPath -eq "") {
		If ($strCloudWebRequestStatus -eq $true) {
			Return @{"FOLDERS" = $objCloudPathFoldersList; "FILES" = $objCloudPathFilesList}
		} Else {
			$script:intCloudFoldersCounter	= 0
			$script:intCloudFilesCounter	= 0
			Return @{"FOLDERS" = @{}; "FILES" = @{}}
		}
	} Else {
		Return $strCloudWebRequestStatus
	}
}

Function Update_Compare {
	Param(
		[string]$strLocalRoot,
		[string]$strCloudRoot,
		[hashtable]$objLocalPathList,
		[hashtable]$objCloudPathList
	)
	$objLocalPathFoldersListAdd = @{}
	$objLocalPathFoldersListRemove = @{}
	$objLocalPathFilesListAdd = @{}
	$objLocalPathFilesListRemove = @{}
	$objLocalPathFilesListUpdate = @{}
	Update_LOG ""
	Update_LOG ("[STATUS]	Comparing...")
	$objCloudPathListSorted = $objCloudPathList.("FOLDERS").Keys | Sort-Object
	$objLocalPathFoldersListAdd = @{}
	ForEach ($objCloudPathFoldersListKey in $objCloudPathListSorted) {
		If (($objCloudPathFoldersListKey -ne "") -and ($objCloudPathFoldersListKey -ne $null)) {
			If ($objLocalPathList.("FOLDERS").Keys -notcontains $objCloudPathFoldersListKey) {
				$objLocalPathFoldersListAdd[$objCloudPathFoldersListKey] = @{}
				$objLocalPathFoldersListAdd[$objCloudPathFoldersListKey]["LOCAL"] = @{}
				$objLocalPathFoldersListAdd[$objCloudPathFoldersListKey]["LOCAL"]["NAME"] = $objCloudPathList.("FOLDERS").$objCloudPathFoldersListKey.("PATH").Split("/")[-1].ToUpper()
				$objLocalPathFoldersListAdd[$objCloudPathFoldersListKey]["LOCAL"]["PATH"] = $strLocalRoot + $objCloudPathList.("FOLDERS").$objCloudPathFoldersListKey.("PATH").SubString($strCloudRoot.Length).Replace("/", "\").ToUpper()
				$script:intSyncFoldersAddCounterTotal = $script:intSyncFoldersAddCounterTotal + 1
				Update_LOG ("[STATUS]	Local folder """ + $strLocalRoot + $objCloudPathList.("FOLDERS").$objCloudPathFoldersListKey.("PATH").SubString($strCloudRoot.Length).Replace("/", "\").ToUpper() + """ not found, but exists in a cloud (""" + $objCloudPathList.("FOLDERS").$objCloudPathFoldersListKey.("PATH") + """).")
			}
		}
	}
	$objLocalPathListSorted = $objLocalPathList.("FOLDERS").Keys | Sort-Object
	$objLocalPathFoldersListRemove = @{}
	ForEach ($objLocalPathFoldersListKey in $objLocalPathListSorted) {
		If (($objLocalPathFoldersListKey -ne "") -and ($objLocalPathFoldersListKey -ne $null)) {
			If ($objCloudPathList.("FOLDERS").Keys -notcontains $objLocalPathFoldersListKey) {
				$objLocalPathFoldersListRemove[$objLocalPathFoldersListKey] = @{}
				$objLocalPathFoldersListRemove[$objLocalPathFoldersListKey]["LOCAL"] = @{}
				$objLocalPathFoldersListRemove[$objLocalPathFoldersListKey]["LOCAL"]["NAME"] = $objLocalPathList.("FOLDERS").($objLocalPathFoldersListKey).("NAME")
				$objLocalPathFoldersListRemove[$objLocalPathFoldersListKey]["LOCAL"]["PATH"] = $objLocalPathList.("FOLDERS").($objLocalPathFoldersListKey).("PATH")
				$script:intSyncFoldersRemoveCounterTotal = $script:intSyncFoldersRemoveCounterTotal + 1
				Update_LOG ("[STATUS]	Local folder """ + $objLocalPathList.("FOLDERS").$objLocalPathFoldersListKey.("PATH") + """ exists, but not found in a cloud.")
			}
		}
	}
	$objCloudPathListSorted = $objCloudPathList.("FILES").Keys | Sort-Object
	$objLocalPathFilesListAdd = @{}
	ForEach ($objCloudPathFilesListKey in $objCloudPathListSorted) {
		If (($objCloudPathFilesListKey -ne "") -and ($objCloudPathFilesListKey -ne $null)) {
			If ($objLocalPathList.("FILES").Keys -notcontains $objCloudPathFilesListKey) {
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey] = @{}
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["LOCAL"] = @{}
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["LOCAL"]["NAME"] = $objCloudPathList.("FILES").$objCloudPathFilesListKey.("NAME")
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["LOCAL"]["PATH"] = $strLocalRoot + $objCloudPathList.("FILES").$objCloudPathFilesListKey.("PATH").SubString($strCloudRoot.Length).SubString(0, ($objCloudPathList.("FILES").$objCloudPathFilesListKey.("PATH").SubString($strCloudRoot.Length).Length - $objCloudPathList.("FILES").$objCloudPathFilesListKey.("NAME").Length)).Replace("/", "\").ToUpper() + $objCloudPathList.("FILES").$objCloudPathFilesListKey.("NAME")
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["CLOUD"] = @{}
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["CLOUD"]["NAME"] = $objCloudPathList.("FILES").$objCloudPathFilesListKey.("NAME")
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["CLOUD"]["PATH"] = $objCloudPathList.("FILES").$objCloudPathFilesListKey.("PATH")
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["CLOUD"]["SIZE"] = $objCloudPathList.("FILES").$objCloudPathFilesListKey.("SIZE")
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["CLOUD"]["DATE"] = $objCloudPathList.("FILES").$objCloudPathFilesListKey.("DATE")
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["CLOUD"]["HASH"] = $objCloudPathList.("FILES").$objCloudPathFilesListKey.("HASH")
				$objLocalPathFilesListAdd[$objCloudPathFilesListKey]["CLOUD"]["ID"] = $objCloudPathList.("FILES").$objCloudPathFilesListKey.("ID")
				$script:intSyncFilesAddCounterTotal = $script:intSyncFilesAddCounterTotal + 1
				Update_LOG ("[STATUS]	Local file """ + $strLocalRoot + $objCloudPathList.("FILES").$objCloudPathFilesListKey.("PATH").SubString($strCloudRoot.Length).SubString(0, ($objCloudPathList.("FILES").$objCloudPathFilesListKey.("PATH").SubString($strCloudRoot.Length).Length - $objCloudPathList.("FILES").$objCloudPathFilesListKey.("NAME").Length)).Replace("/", "\").ToUpper() + $objCloudPathList.("FILES").$objCloudPathFilesListKey.("NAME") + """ not found, but exists in a cloud (""" + $objCloudPathList.("FILES").$objCloudPathFilesListKey.("PATH") + """).")
			}
		}
	}
	$objLocalPathListSorted = $objLocalPathList.("FILES").Keys | Sort-Object
	$objLocalPathFilesListUpdate = @{}
	$objLocalPathFilesListRemove = @{}
	ForEach ($objLocalPathFilesListKey in $objLocalPathListSorted) {
		If (($objLocalPathFilesListKey -ne "") -and ($objLocalPathFilesListKey -ne $null)) {
			If ($objCloudPathList.("FILES").Keys -contains $objLocalPathFilesListKey) {
				If ($objLocalPathList.("FILES").$objLocalPathFilesListKey.("HASH") -ne $objCloudPathList.("FILES").$objLocalPathFilesListKey.("HASH")) {
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey] = @{}
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["LOCAL"] = @{}
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["LOCAL"]["NAME"] = $objLocalPathList.("FILES").$objLocalPathFilesListKey.("NAME")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["LOCAL"]["PATH"] = $objLocalPathList.("FILES").$objLocalPathFilesListKey.("PATH")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["LOCAL"]["SIZE"] = $objLocalPathList.("FILES").$objLocalPathFilesListKey.("SIZE")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["LOCAL"]["HASH"] = $objLocalPathList.("FILES").$objLocalPathFilesListKey.("HASH")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["CLOUD"] = @{}
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["CLOUD"]["NAME"] = $objCloudPathList.("FILES").$objLocalPathFilesListKey.("NAME")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["CLOUD"]["PATH"] = $objCloudPathList.("FILES").$objLocalPathFilesListKey.("PATH")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["CLOUD"]["SIZE"] = $objCloudPathList.("FILES").$objLocalPathFilesListKey.("SIZE")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["CLOUD"]["DATE"] = $objCloudPathList.("FILES").$objLocalPathFilesListKey.("DATE")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["CLOUD"]["HASH"] = $objCloudPathList.("FILES").$objLocalPathFilesListKey.("HASH")
					$objLocalPathFilesListUpdate[$objLocalPathFilesListKey]["CLOUD"]["ID"] = $objCloudPathList.("FILES").$objLocalPathFilesListKey.("ID")
					$script:intSyncFilesUpdateCounterTotal = $script:intSyncFilesUpdateCounterTotal + 1
					Update_LOG ("[STATUS]	Local file """ + $objLocalPathList.("FILES").$objLocalPathFilesListKey.("PATH") + """ has different hash sum with cloud file """ + $objCloudPathList.("FILES").$objLocalPathFilesListKey.("PATH")  + """.")
				}
			} Else {
				$objLocalPathFilesListRemove[$objLocalPathFilesListKey] = @{}
				$objLocalPathFilesListRemove[$objLocalPathFilesListKey]["LOCAL"] = @{}
				$objLocalPathFilesListRemove[$objLocalPathFilesListKey]["LOCAL"]["NAME"] = $objLocalPathList.("FILES").($objLocalPathFilesListKey).("NAME")
				$objLocalPathFilesListRemove[$objLocalPathFilesListKey]["LOCAL"]["PATH"] = $objLocalPathList.("FILES").($objLocalPathFilesListKey).("PATH")
				$objLocalPathFilesListRemove[$objLocalPathFilesListKey]["LOCAL"]["SIZE"] = $objLocalPathList.("FILES").($objLocalPathFilesListKey).("SIZE")
				$objLocalPathFilesListRemove[$objLocalPathFilesListKey]["LOCAL"]["HASH"] = $objLocalPathList.("FILES").($objLocalPathFilesListKey).("HASH")
				$script:intSyncFilesRemoveCounterTotal = $script:intSyncFilesRemoveCounterTotal + 1
				Update_LOG ("[STATUS]	Local file """ + $objLocalPathList.("FILES").$objLocalPathFilesListKey.("PATH") + """ exists, but not found in a cloud.")
			}
		}
	}
	Return (@{"FOLDERS" = @{"ADD" = $objLocalPathFoldersListAdd; "REMOVE" = $objLocalPathFoldersListRemove}; "FILES" = @{"ADD" = $objLocalPathFilesListAdd; "REMOVE" = $objLocalPathFilesListRemove; "UPDATE" = $objLocalPathFilesListUpdate}})
}

Function Update_Synchronize {
	Param(
		[string]$strLocalRoot,
		[string]$strCloudRoot,
		[string]$strCMDStartFileName,
		[string]$strCMDStartWindowStyle,
		[string]$strCMDStopFileName,
		[string]$strCMDStopWindowStyle,
		[array]$objCloudURL,
		[array]$objCloudToken,
		[hashtable]$objLocalCompare
	)

	$objLocalPathFilesListRemove = $objLocalCompare.("FILES").("REMOVE")
	$objLocalPathFoldersListRemove = $objLocalCompare.("FOLDERS").("REMOVE")
	$objLocalPathFoldersListAdd = $objLocalCompare.("FOLDERS").("ADD")
	$objLocalPathFilesListUpdate = $objLocalCompare.("FILES").("UPDATE")
	$objLocalPathFilesListAdd = $objLocalCompare.("FILES").("ADD")

	If (($objLocalPathFilesListRemove.Keys.Count -gt 0) -or ($objLocalPathFoldersListRemove.Keys.Count -gt 0) -or ($objLocalPathFoldersListAdd.Keys.Count -gt 0) -or ($objLocalPathFilesListAdd.Keys.Count -gt 0) -or ($objLocalPathFilesListUpdate.Keys.Count -gt 0)) {
		If (Test-Path -Path ($strLocalRoot + "\" + $strCMDStopFileName)) {
			Update_LOG ""
			Update_LOG ("[STATUS]	Stop CMD Script """ + ($strLocalRoot + "\" + $strCMDStopFileName) + """...")
			Start-Process -FilePath ($strLocalRoot + "\" + $strCMDStopFileName) -Wait -WindowStyle $strCMDStopWindowStyle
		}
		[int]$intPSScriptPID = [System.Diagnostics.Process]::GetCurrentProcess().id
		ForEach ($intPID in (Get-Process -Name PowerShell).id) {
			If (($intPID -ne "") -and ($intPID -ne $null) -and ($intPID -ne $intPSScriptPID)) {
				Update_LOG ""
				Update_LOG ("[STATUS]	Stop PowerShell with PID """ + $intPID + """...")
				Stop-Process -id $intPID -Force
			}
		}
		Update_LOG ""
		Update_LOG ("[STATUS]	Synchronizing...")
		[int]$intSyncFilesCounterCurrent = 0
		[int]$intSyncFilesCounterComplete = 0
		[string]$strSyncFilesRemoveCounterTotal = $intSyncFilesRemoveCounterTotal.ToString().PadLeft(3, "0")
		Update_LOG ""
		Update_LOG ("[STATUS]	Checking files to be removed...")
		ForEach ($objLocalPathFilesListRemoveKey in ($objLocalPathFilesListRemove.Keys | Sort-Object -Descending)) {
			$intSyncFilesCounterCurrent = $intSyncFilesCounterCurrent + 1
			[string]$strSyncFilesCounterCurrent = $intSyncFilesCounterCurrent.ToString().PadLeft(3, "0")
			[string]$strLocalFileName		= $objLocalPathFilesListRemove.($objLocalPathFilesListRemoveKey).("LOCAL").("NAME")
			[string]$strLocalFilePath		= $objLocalPathFilesListRemove.($objLocalPathFilesListRemoveKey).("LOCAL").("PATH")
			Update_SynchronizeRemove $strLocalFilePath $strLocalFileName
			If (-not (Test-Path -Path $strLocalFilePath)) {
				$intSyncFilesCounterComplete = $intSyncFilesCounterComplete + 1
				Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesRemoveCounterTotal + "] Removing file """ + $strLocalFileName + """ (""" + $strLocalFilePath + """) successfull.")
			} Else {
				Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesRemoveCounterTotal + "] Error: can not remove file """ + $strLocalFilePath + """.")
			}
		}
		Update_LOG ("[STATUS]	Total " + $intSyncFilesCounterComplete + " of " + $script:intSyncFilesRemoveCounterTotal + " files removed.")
		[int]$intSyncFoldersCounterCurrent = 0
		[int]$intSyncFoldersCounterComplete = 0
		[string]$strSyncFoldersRemoveCounterTotal = $intSyncFoldersRemoveCounterTotal.ToString().PadLeft(3, "0")
		Update_LOG ""
		Update_LOG ("[STATUS]	Checking folders to be removed...")
		ForEach ($objLocalPathFoldersListRemoveKey in ($objLocalPathFoldersListRemove.Keys | Sort-Object -Descending)) {
			$intSyncFoldersCounterCurrent = $intSyncFoldersCounterCurrent + 1
			[string]$strSyncFoldersCounterCurrent = $intSyncFoldersCounterCurrent.ToString().PadLeft(3, "0")
			[string]$strLocalFolderPath = $objLocalPathFoldersListRemove.($objLocalPathFoldersListRemoveKey).("LOCAL").("PATH")
			[int]$intCounterTryRemove = 0
			While ((Test-Path -Path $strLocalFolderPath) -and ($intCounterTryRemove -le 3)) {
				$intCounterTryRemove += 1
				Try {
					Remove-Item -Path ($strLocalFolderPath) -Force -Recurse -ErrorAction Stop
				} Catch {
					If ($intCounterTryRemove -gt 3) {
						Update_LOG ("[STATUS]		[" + $strSyncFoldersCounterCurrent + "/" + $strSyncFoldersRemoveCounterTotal + "] Error: can not remove folder """ +  $strLocalFolderPath + """. Trying again in 3 seconds. Retry # " + $intCounterTryRemove + " of 3 ...")
						Start-Sleep -Seconds 3
					}
				}
			}
			If (-not (Test-Path -Path $strLocalFolderPath)) {
				$intSyncFoldersCounterComplete = $intSyncFoldersCounterComplete + 1
				Update_LOG ("[STATUS]		[" + $strSyncFoldersCounterCurrent + "/" + $strSyncFoldersRemoveCounterTotal + "] Removing folder """ + $strLocalFolderPath + """ successfull.")
			} Else {
				Update_LOG ("[STATUS]		[" + $strSyncFoldersCounterCurrent + "/" + $strSyncFoldersRemoveCounterTotal + "] Error: can not remove folder """ + $strLocalFolderPath + """.")
			}
		}
		Update_LOG ("[STATUS]	Total " + $intSyncFoldersCounterComplete + " of " + $script:intSyncFoldersRemoveCounterTotal + " folders removed.")
		[int]$intSyncFoldersCounterCurrent = 0
		[int]$intSyncFoldersCounterComplete = 0
		[string]$strSyncFoldersAddCounterTotal = $intSyncFoldersAddCounterTotal.ToString().PadLeft(3, "0")
		Update_LOG ""
		Update_LOG ("[STATUS]	Checking folders to be created...")
		ForEach ($objLocalPathFoldersListAddKey in ($objLocalPathFoldersListAdd.Keys | Sort-Object)) {
			$intSyncFoldersCounterCurrent = $intSyncFoldersCounterCurrent + 1
			[string]$strSyncFoldersCounterCurrent = $intSyncFoldersCounterCurrent.ToString().PadLeft(3, "0")
			[string]$strLocalFolderPath = $objLocalPathFoldersListAdd.($objLocalPathFoldersListAddKey).("LOCAL").("PATH")
			Try {
				New-Item -ItemType Directory -Force -Path $strLocalFolderPath -ErrorAction Stop
			} Catch {
				Update_LOG ("[STATUS]		[" + $strSyncFoldersCounterCurrent + "/" + $strSyncFoldersAddCounterTotal + "] Error: can not create folder """ + $strLocalFolderPath + """.")
			}
			If (Test-Path -Path $strLocalFolderPath) {
				$intSyncFoldersCounterComplete = $intSyncFoldersCounterComplete + 1
				Update_LOG ("[STATUS]		[" + $strSyncFoldersCounterCurrent + "/" + $strSyncFoldersAddCounterTotal + "] Creating folder """ + $strLocalFolderPath + """ successfull.")
			}
		}
		Update_LOG ("[STATUS]	Total " + $intSyncFoldersCounterComplete + " of " + $script:intSyncFoldersAddCounterTotal + " folders created.")
		[int]$intSyncFilesCounterCurrent = 0
		[int]$intSyncFilesCounterComplete = 0
		[string]$strSyncFilesAddCounterTotal = $intSyncFilesAddCounterTotal.ToString().PadLeft(3, "0")
		Update_LOG ""
		Update_LOG ("[STATUS]	Checking files to be added...")
		ForEach ($objLocalPathFilesListAddKey in ($objLocalPathFilesListAdd.Keys | Sort-Object)) {
			$intSyncFilesCounterCurrent = $intSyncFilesCounterCurrent + 1
			[string]$strSyncFilesCounterCurrent = $intSyncFilesCounterCurrent.ToString().PadLeft(3, "0")
			[string]$strLocalFileName	= $objLocalPathFilesListAdd.($objLocalPathFilesListAddKey).("LOCAL").("NAME")
			[string]$strLocalFilePath	= $objLocalPathFilesListAdd.($objLocalPathFilesListAddKey).("LOCAL").("PATH")
			[string]$strCloudFilePath	= $objLocalPathFilesListAdd.($objLocalPathFilesListAddKey).("CLOUD").("PATH")
			[string]$strCloudFileHash	= $objLocalPathFilesListAdd.($objLocalPathFilesListAddKey).("CLOUD").("HASH")
			[string]$strCloudFileID		= $objLocalPathFilesListAdd.($objLocalPathFilesListAddKey).("CLOUD").("ID")
			If (Test-Path -Path $strLocalFilePath.SubString(0, ($strLocalFilePath.Length - $strLocalFileName.Length))) {
				Update_DownloadFile $objCloudURL $objCloudToken $strCloudRoot $strCloudFilePath $strLocalFileName $strCloudFileID $strLocalFilePath
				If (Test-Path -Path $strLocalFilePath) {
					$strLocalFileHash = Update_CalculateFileHash ($strLocalFilePath)
					If ($strLocalFileHash -eq $strCloudFileHash) {
						$intSyncFilesCounterComplete = $intSyncFilesCounterComplete + 1
						Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesAddCounterTotal + "] Copying file """ + $strLocalFileName + """ (""" + $strLocalFilePath + """) successfull.")
					} Else {
						Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesAddCounterTotal + "] Error: hash mismatch while updating file (""" + $strLocalFileHash + """ in """ + $strLocalFilePath + """ and """ + $strCloudFileHash + """ in """ + $strCloudFilePath + """).")
					}
				} Else {
					Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesAddCounterTotal + "] Error: can not copy file """ + $strLocalFileName + """ from cloud (""" + $strCloudFilePath + """) to local (""" + $strLocalFilePath + """) folder.")
				}
			} Else {
				Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesAddCounterTotal + "] Error: local folder """ + $strLocalFilePath.SubString(0, ($strLocalFilePath.Length - $strLocalFileName.Length)) + """ not found. Can not save file to """ + $strLocalFilePath + """.")
			}
		}
		Update_LOG ("[STATUS]	Total " + $intSyncFilesCounterComplete + " of " + $script:intSyncFilesAddCounterTotal + " files added.")
		[int]$intSyncFilesCounterCurrent = 0
		[int]$intSyncFilesCounterComplete = 0
		[string]$strSyncFilesUpdateCounterTotal = $intSyncFilesUpdateCounterTotal.ToString().PadLeft(3, "0")
		Update_LOG ""
		Update_LOG ("[STATUS]	Checking files to be updated...")
		ForEach ($objLocalPathFilesListUpdateKey in $objLocalPathFilesListUpdate.Keys) {
			$intSyncFilesCounterCurrent = $intSyncFilesCounterCurrent + 1
			[string]$strSyncFilesCounterCurrent = $intSyncFilesCounterCurrent.ToString().PadLeft(3, "0")
			[string]$strLocalFileName	= $objLocalPathFilesListUpdate.($objLocalPathFilesListUpdateKey).("LOCAL").("NAME")
			[string]$strLocalFilePath	= $objLocalPathFilesListUpdate.($objLocalPathFilesListUpdateKey).("LOCAL").("PATH")
			[string]$strCloudFilePath	= $objLocalPathFilesListUpdate.($objLocalPathFilesListUpdateKey).("CLOUD").("PATH")
			[string]$strCloudFileHash	= $objLocalPathFilesListUpdate.($objLocalPathFilesListUpdateKey).("CLOUD").("HASH")
			[string]$strCloudFileID		= $objLocalPathFilesListUpdate.($objLocalPathFilesListUpdateKey).("CLOUD").("ID")
			Update_SynchronizeRemove $strLocalFilePath $strLocalFileName
			If (-not (Test-Path -Path $strLocalFilePath)) {
#				Update_LOG ("[STATUS]	[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesUpdateCounterTotal + "] Updating file: """ + $strLocalFileName + """ from """ + $strCloudFilePath + """ to """ + $strLocalFilePath + """...")
				Update_DownloadFile $objCloudURL $objCloudToken $strCloudRoot $strCloudFilePath $strLocalFileName $strCloudFileID $strLocalFilePath
				$strLocalFileHash = Update_CalculateFileHash $strLocalFilePath
				If ($strLocalFileHash -eq $strCloudFileHash) {
					$intSyncFilesCounterComplete = $intSyncFilesCounterComplete + 1
					Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesUpdateCounterTotal + "] Updating file """ + $strLocalFileName + """ (""" + $strLocalFilePath + """) successfull.")
				} Else {
					Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesUpdateCounterTotal + "] Error: hash mismatch while updating file (""" + $strLocalFileHash + """ in """ + $strLocalFilePath + """ and """ + $strCloudFileHash + """ in """ + $strCloudFilePath + """).")
				}
			} Else {
				Update_LOG ("[STATUS]		[" + $strSyncFilesCounterCurrent + "/" + $strSyncFilesUpdateCounterTotal + "] Error: can not remove old file """ + $strLocalFilePath + """ before updating to a new file.")
			}
		}
		Update_LOG ("[STATUS]	Total " + $intSyncFilesCounterComplete + " of " + $script:intSyncFilesUpdateCounterTotal + " files updated.")
		Update_LOG ""
		Update_LOG ("[STATUS]	Complete synchronizing.")
		If (Test-Path -Path ($strLocalRoot + "\" + $strCMDStartFileName)) {
			Update_LOG ""
			Update_LOG ("[STATUS]	Start CMD Script """ + ($strLocalRoot + "\" + $strCMDStartFileName) + """...")
			Start-Process -FilePath ($strLocalRoot + "\" + $strCMDStartFileName) -WindowStyle $strCMDStartWindowStyle
		}
		Return $true
	} Else {
		Clear-Host
		Update_LOG ("[STATUS]	All " + $script:intLocalFoldersCounter + " folder(s) and " + $script:intLocalFilesCounter + " file(s) already synchronized.")
		Return $false
	}
}

Function Update_SynchronizeRemove {
	Param(
		[string]$strLocalFilePath,
		[string]$strLocalFileName
	)
	[string]$strLocalFileNameOnlyExt	= $strLocalFileName.Split(".")[-1]
	[string]$strLocalFileNameOnlyName	= $strLocalFileName.SubString(0, ($strLocalFileName.Length - ($strLocalFileNameOnlyExt.Length + 1)))
	[string]$strLocalFolderPath		= $strLocalFilePath.SubString(0, ($strLocalFilePath.Length - ($strLocalFileName.Length + 1)))
	[int]$intCounterTryRemove 		= 0
	If (Test-Path -Path $strLocalFilePath) {
		While ((Test-Path -Path $strLocalFilePath) -and ($intCounterTryRemove -le 3)) {
			$intCounterTryRemove += 1
			Try {
				Remove-Item -Path ($strLocalFilePath) -Force -ErrorAction Stop
			} Catch {
				If ($intCounterTryRemove -gt 3) {
					Update_LOG ("[ERROR]	File """ +  $strLocalFilePath + """ locked, can not remove. Trying to rename it to """ + $strLocalFolderPath + "\" + $strLocalFileNameOnlyName + "~." + $strLocalFileNameOnlyExt + """...")
					Rename-Item -Path $strLocalFilePath -NewName ($strLocalFolderPath + "\" + $strLocalFileNameOnlyName + "~." + $strLocalFileNameOnlyExt) -Force -ErrorAction Stop
				} Else {
					Update_LOG ("[ERROR]	File """ +  $strLocalFilePath + """ locked. Trying again in 3 seconds. Retry # " + $intCounterTryRemove + " of 3 ...")
					Start-Sleep -Seconds 3
				}
			}
		}
	} Else {
		Update_LOG ("[ERROR]	File """ +  $strLocalFilePath + """ not found.")
	}
}

Function Update_CalculateFileHash {
	Param(
		[string]$strLocalPath
	)
#	$objSHA256 = New-Object -TypeName System.Security.Cryptography.SHA256CryptoServiceProvider
	$objSHA256 = [System.Security.Cryptography.HashAlgorithm]::create("sha256")
	[int32]$intHashBufferSize=4*1024*1024
	$intCounterTryOpen = 0
	While (($objHashStream -eq $null) -and ($intCounterTryOpen -lt 5)) {
		$intCounterTryOpen += 1
		Try {
			$objHashStream = [System.IO.File]::OpenRead($strLocalPath)
		} Catch {
			Update_LOG ("[ERROR]	Can not open file """ +  $strLocalPath + """. Trying again in 1 seconds. Retry # " + $intCounterTryOpen + " of 5 ...")
			Start-Sleep -Seconds 1
		}
	}
	If ($objHashStream -ne $null) {
		$intHashChunkNumber = 1
		$byteHashBarr = New-Object byte[] $intHashBufferSize
		[string]$strLocalFileHash = ""
		While ($intHashBytesRead = $objHashStream.Read($byteHashBarr,0,$intHashBufferSize)) {
			$strLocalFileHash += [System.BitConverter]::ToString($objSHA256.ComputeHash($byteHashBarr,0,$intHashBytesRead)).Replace("-", "")
			$intHashChunkNumber += 1
		}
		$objHashStream.Dispose()
		$byteLocalFileHashBytes = [System.Byte[]]::CreateInstance([System.Byte],($strLocalFileHash.Length / 2))
		For ($i = 0; ($i -lt $strLocalFileHash.Length); $i += 2){
			$byteLocalFileHashBytes[($i / 2)] = [convert]::ToByte($strLocalFileHash.Substring($i, 2), 16)
		}
		$strLocalFileHash = ([System.BitConverter]::ToString($objSHA256.ComputeHash($byteLocalFileHashBytes))).Replace("-", "").ToLower()
	} Else {
		$strLocalFileHash = ""
	}
	Return $strLocalFileHash
}

Function Update_DownloadFile {
	Param(
		[array]$objCloudURL,
		[array]$objCloudToken,
		[string]$strCloudRoot,
		[string]$strCloudFilePath,
		[string]$strCloudFileName,
		[string]$strCloudFileID,
		[string]$strLocalFilePath
	)
	$strCloudURI	= "https://content.dropboxapi.com/2/files/download"
#	$strCloudURI	= "https://content.dropboxapi.com/2/sharing/get_shared_link_file"
	$strCloudHeader	= "{`"path`":`"" + $strCloudFileID + "`"}"
#	$strCloudHeader	= "{`"url`":`"" + [System.Text.Encoding]::UTF8.GetString($objCloudURL) + "`",`"path`":`"" + $strCloudFilePath.SubString($strCloudRoot.Length) + "`"}"
	$strCloudBody	= ""
	$objWebResponseResultDownload = (Update_WebRequest $strCloudURI $objCloudToken $strCloudHeader $strCloudBody $strLocalFilePath)[1]
	If ([int]$objWebResponseResultDownload.("RESPONSE").StatusCode -eq "200") {
#		Update_LOG ("[INFO]	File downloaded from """ + $strCloudFilePath + """ to """ + $strLocalFilePath + """.")
	} Else {
		Update_LOG ("[INFO]	Request to server API: " + $strCloudHeader)
		Update_LOG ("[INFO]	Server API answer: " + [int]$objWebResponseResultDownload.("RESPONSE").StatusCode + " - " + $objWebResponseResultDownload.("RESPONSE").StatusCode + " (" + $objWebResponseResultDownload.("RESPONSE").StatusDescription + ")")
	}
}

Function Update_WebRequest {
	Param(
		[string]$strCloudURI,
		[array]$objCloudToken,
		[string]$strCloudHeader,
		[string]$strCloudBody,
		[string]$strFilePath
	)
#	$objEncodedToken = [System.Text.Encoding]::UTF8.GetBytes($strOriginalToken)
#	$strOriginalToken = [System.Text.Encoding]::UTF8.GetString($objEncodedToken)
	$strMethod	= "POST"
	If ($strCloudHeader.Length -gt 0) {
		$strContentType	= "application/octet-stream; charset=utf-8"
	} Else {
		$strContentType	= "Application/json"
	}
	Try {
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
		[System.Net.ServicePointManager]::DefaultConnectionLimit = 1024
		$objWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
#		$objWebProxy = [System.Net.WebRequest]::DefaultWebProxy
		$objWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
#		$objWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
		$objWebConnection = [System.Net.WebRequest]::Create($strCloudURI)
		$objWebConnection.Proxy = $objWebProxy
		$objWebConnection.Method = $strMethod
		$objWebConnection.ContentType = $strContentType
		$objWebConnection.Headers.Add("Authorization", "Bearer " + ([System.Text.Encoding]::UTF8.GetString($objCloudToken)))
		If ($strCloudHeader.Length -gt 0) {
			$objWebConnection.Headers.Add("Dropbox-API-Arg", $strCloudHeader)
		}
		$objWebConnection.Timeout = 10000
		If (($strCloudHeader.Length -eq 0) -and ($strCloudBody.Length -gt 0)) {
			$objWebStream = $objWebConnection.GetRequestStream()
# Errors with non-latin chars!
#			$objCloudBody = [byte[]][char[]]$strCloudBody
			$objCloudBody = [Text.Encoding]::UTF8.GetBytes($strCloudBody)
			$objWebStream.Write($objCloudBody, 0, $objCloudBody.Length)
			$objWebStream.Flush()
			$objWebStream.Close()
		}
		$objWebResponse = $objWebConnection.GetResponse()
		If ([int]$objWebResponse.StatusCode -eq "200") {
#		If ($objWebResponse.StatusCode -eq "OK") {
			If ($strCloudHeader.Length -gt 0) {
				$objWebResponseStream = $objWebConnection.GetResponse().GetResponseStream()
				$objFileStream = [System.IO.File]::Create($strFilePath)
				$byteStreamBuffer = New-Object byte[] 10240
				While (($intStreamRead = $objWebResponseStream.Read($byteStreamBuffer, 0, $byteStreamBuffer.Length)) -gt 0) {
					$objFileStream.Write($byteStreamBuffer, 0, $intStreamRead)
				}
				$objFileStream.Close()
			} Else {
				$objWebResponseStream = $objWebConnection.GetResponse().GetResponseStream()
				$objWebResponseStreamReader = New-Object System.IO.StreamReader($objWebResponseStream)
				$objWebResult = $objWebResponseStreamReader.ReadToEnd()
			}
		} Else {
			$objWebResult = @()
		}
		$objWebConnection.Close
	} Catch [System.Net.WebException] {
      		$objWebResponse = $_.Exception.Response
		$objWebResult = @()
	}
	Return @{"RESPONSE" = $objWebResponse; "RESULT" = $objWebResult}
}

Function Update_SendEmail {
	Param(
		[string]$strFrom,
		[array]$objTo,
		[string]$strSubject,
		[string]$strBody,
		[array]$objAttachments,
		[string]$strServerAddress,
		[int]$strServerPort,
		[object]$strServerCredential
	)
	Try {
		$strEmailMessage	= New-Object System.Net.Mail.MailMessage
		$strEmailMessage.From	= $strFrom
		ForEach ($strRecipient in $objTo) {
			$strEmailMessage.To.Add($strRecipient)
		}
		$strEmailMessage.Subject= $strSubject
		$strEmailMessage.Body	= $strBody
		If ($objAttachments.Count -gt 0) {
			ForEach ($strAttachment in $objAttachments) {
				$strEmailAttachment = New-Object System.Net.Mail.Attachment ($strAttachment, "text/plain")
				$strEmailMessage.Attachments.Add($strEmailAttachment)
			}
		}
		$objEmail		= New-Object System.Net.Mail.SmtpClient
		$objEmail.Host		= $strServerAddress
		$objEmail.Port		= $strServerPort
		$objEmail.Credentials	= $strServerCredential
		$objEmail.EnableSsl	= $true
#		$objEmail.IsBodyHTML	= $false
#		$objEmail.Priority	= [System.Net.Mail.MailPriority]::High
		$objEmail.Send($strEmailMessage)
		$strEmailMessage.Dispose()
		$strResult = $true
	} Catch {
		Update_LOG ("[ERROR]	Can not send e-mail: " + $_.Exception.Message)
		$strResult = $false
	}
	Return $strResult
}

If ($PSVersionTable.PSVersion.Major -lt 3) {
#	Function ConvertFrom-Json([string]$InputObject) {
#		[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null
#		Add-Type -AssemblyName System.Web.Extensions
#		$objSerialization = New-Object System.Web.Script.Serialization.JavaScriptSerializer
#		$OutputObject = New-Object -Type PSObject -Property $objSerialization.DeserializeObject($InputObject)
#		Return $OutputObject
#	}
#	Function ConvertTo-Json([psobject]$InputObject) {
#		[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | out-null
#		$objSerialization =  New-Object System.Web.Script.Serialization.JavaScriptSerializer 
#		$HashTable = @{}
#		$InputObject.PSObject.Properties | %{ $HashTable.($_.Name) = $_.Value }
#		Return $objSerialization.Serialize($HashTable)
#	}
	Function ConvertFrom-Json {
		Param(
			[Parameter(ValueFromPipeline=$true)]
			[string]$json
		)
		Begin {
			Add-Type -AssemblyName System.Web.Extensions
			$Serialization = New-Object System.Web.Script.Serialization.JavaScriptSerializer
		} Process {
			,$Serialization.DeserializeObject($json)
		}
	}
# Author: Joakim Borger Svendsen, 2017. http://www.json.org
# https://gist.github.com/mdnmdn/6936714
# Take care of special characters in JSON (see json.org), such as newlines, backslashes carriage returns and tabs.
# '\\(?!["/bfnrt]|u[0-9a-f]{4})'
	function FormatString {
		param([String] $String)
		$String -replace '\\', '\\' -replace '\n', '\n' -replace '\u0008', '\b' -replace '\u000C', '\f' -replace '\r', '\r' -replace '\t', '\t' -replace '"', '\"'
	}
# Meant to be used as the "end value". Adding coercion of strings that match numerical formats
# supported by JSON as an optional, non-default feature (could actually be useful and save a lot of
# calculated properties with casts before passing..).
# If it's a number (or the parameter -CoerceNumberStrings is passed and it 
# can be "coerced" into one), it'll be returned as a string containing the number.
# If it's not a number, it'll be surrounded by double quotes as is the JSON requirement.
	function GetNumberOrString {
		param($InputObject)
		if ($InputObject -is [System.Byte] -or $InputObject -is [System.Int32] -or ($env:PROCESSOR_ARCHITECTURE -imatch '^(?:amd64|ia64)$' -and $InputObject -is [System.Int64]) -or $InputObject -is [System.Decimal] -or $InputObject -is [System.Double] -or $InputObject -is [System.Single] -or $InputObject -is [long] -or ($Script:CoerceNumberStrings -and $InputObject -match $Script:NumberRegex)) {
			Write-Verbose -Message "Got a number as end value."
			"$InputObject"
		} else {
			Write-Verbose -Message "Got a string as end value."
			"""$(FormatString -String $InputObject)"""
		}
	}
	function ConvertToJsonInternal {
		param($InputObject,[Int32] $WhiteSpacePad = 0)
		[String] $Json = ""
		$Keys = @()
		Write-Verbose -Message "WhiteSpacePad: $WhiteSpacePad."
		if ($null -eq $InputObject) {
			Write-Verbose -Message "Got 'null' in `$InputObject in inner function"
			$null
		} elseif ($InputObject -is [Bool] -and $InputObject -eq $true) {
			Write-Verbose -Message "Got 'true' in `$InputObject in inner function"
			$true
		} elseif ($InputObject -is [Bool] -and $InputObject -eq $false) {
			Write-Verbose -Message "Got 'false' in `$InputObject in inner function"
			$false
		} elseif ($InputObject -is [HashTable]) {
			$Keys = @($InputObject.Keys)
			Write-Verbose -Message "Input object is a hash table (keys: $($Keys -join ', '))."
		} elseif ($InputObject.GetType().FullName -eq "System.Management.Automation.PSCustomObject") {
			$Keys = @(Get-Member -InputObject $InputObject -MemberType NoteProperty |
			Select-Object -ExpandProperty Name)
			Write-Verbose -Message "Input object is a custom PowerShell object (properties: $($Keys -join ', '))."
		} elseif ($InputObject.GetType().Name -match '\[\]|Array') {
			Write-Verbose -Message "Input object appears to be of a collection/array type."
			Write-Verbose -Message "Building JSON for array input object."
#			$Json += " " * ((4 * ($WhiteSpacePad / 4)) + 4) + "[`n" + (($InputObject | ForEach-Object {
			$Json += "[`n" + (($InputObject | ForEach-Object {
				if ($null -eq $_) {
					Write-Verbose -Message "Got null inside array."
					" " * ((4 * ($WhiteSpacePad / 4)) + 4) + "null"
				} elseif ($_ -is [Bool] -and $_ -eq $true) {
					Write-Verbose -Message "Got 'true' inside array."
					" " * ((4 * ($WhiteSpacePad / 4)) + 4) + "true"
				} elseif ($_ -is [Bool] -and $_ -eq $false) {
					Write-Verbose -Message "Got 'false' inside array."
					" " * ((4 * ($WhiteSpacePad / 4)) + 4) + "false"
				} elseif ($_ -is [HashTable] -or $_.GetType().FullName -eq "System.Management.Automation.PSCustomObject" -or $_.GetType().Name -match '\[\]|Array') {
					Write-Verbose -Message "Found array, hash table or custom PowerShell object inside array."
					" " * ((4 * ($WhiteSpacePad / 4)) + 4) + (ConvertToJsonInternal -InputObject $_ -WhiteSpacePad ($WhiteSpacePad + 4)) -replace '\s*,\s*$' #-replace '\ {4}]', ']'
				} else {
					Write-Verbose -Message "Got a number or string inside array."
					$TempJsonString = GetNumberOrString -InputObject $_
					" " * ((4 * ($WhiteSpacePad / 4)) + 4) + $TempJsonString
				}
			#}) -join ",`n") + "`n],`n"
			}) -join ",`n") + "`n$(" " * (4 * ($WhiteSpacePad / 4)))],`n"
		} else {
			Write-Verbose -Message "Input object is a single element (treated as string/number)."
			GetNumberOrString -InputObject $InputObject
		}
		if ($Keys.Count) {
			Write-Verbose -Message "Building JSON for hash table or custom PowerShell object."
			$Json += "{`n"
			foreach ($Key in $Keys) {
# -is [PSCustomObject]) { # this was buggy with calculated properties, the value was thought to be PSCustomObject
				if ($null -eq $InputObject.$Key) {
					Write-Verbose -Message "Got null as `$InputObject.`$Key in inner hash or PS object."
					$Json += " " * ((4 * ($WhiteSpacePad / 4)) + 4) + """$Key"": null,`n"
				} elseif ($InputObject.$Key -is [Bool] -and $InputObject.$Key -eq $true) {
					Write-Verbose -Message "Got 'true' in `$InputObject.`$Key in inner hash or PS object."
					$Json += " " * ((4 * ($WhiteSpacePad / 4)) + 4) + """$Key"": true,`n"
				} elseif ($InputObject.$Key -is [Bool] -and $InputObject.$Key -eq $false) {
					Write-Verbose -Message "Got 'false' in `$InputObject.`$Key in inner hash or PS object."
					$Json += " " * ((4 * ($WhiteSpacePad / 4)) + 4) + """$Key"": false,`n"
				} elseif ($InputObject.$Key -is [HashTable] -or $InputObject.$Key.GetType().FullName -eq "System.Management.Automation.PSCustomObject") {
					Write-Verbose -Message "Input object's value for key '$Key' is a hash table or custom PowerShell object."
					$Json += " " * ($WhiteSpacePad + 4) + """$Key"":`n$(" " * ($WhiteSpacePad + 4))"
					$Json += ConvertToJsonInternal -InputObject $InputObject.$Key -WhiteSpacePad ($WhiteSpacePad + 4)
				} elseif ($InputObject.$Key.GetType().Name -match '\[\]|Array') {
					Write-Verbose -Message "Input object's value for key '$Key' has a type that appears to be a collection/array."
					Write-Verbose -Message "Building JSON for ${Key}'s array value."
					$Json += " " * ($WhiteSpacePad + 4) + """$Key"":`n$(" " * ((4 * ($WhiteSpacePad / 4)) + 4))[`n" + (($InputObject.$Key | ForEach-Object {
#Write-Verbose "Type inside array inside array/hash/PSObject: $($_.GetType().FullName)"
						if ($null -eq $_) {
							Write-Verbose -Message "Got null inside array inside inside array."
							" " * ((4 * ($WhiteSpacePad / 4)) + 8) + "null"
						} elseif ($_ -is [Bool] -and $_ -eq $true) {
							Write-Verbose -Message "Got 'true' inside array inside inside array."
							" " * ((4 * ($WhiteSpacePad / 4)) + 8) + "true"
						} elseif ($_ -is [Bool] -and $_ -eq $false) {
							Write-Verbose -Message "Got 'false' inside array inside inside array."
							" " * ((4 * ($WhiteSpacePad / 4)) + 8) + "false"
						} elseif ($_ -is [HashTable] -or $_.GetType().FullName -eq "System.Management.Automation.PSCustomObject" -or $_.GetType().Name -match '\[\]|Array') {
							Write-Verbose -Message "Found array, hash table or custom PowerShell object inside inside array."
							" " * ((4 * ($WhiteSpacePad / 4)) + 8) + (ConvertToJsonInternal -InputObject $_ -WhiteSpacePad ($WhiteSpacePad + 8)) -replace '\s*,\s*$'
						} else {
							Write-Verbose -Message "Got a string or number inside inside array."
							$TempJsonString = GetNumberOrString -InputObject $_
							" " * ((4 * ($WhiteSpacePad / 4)) + 8) + $TempJsonString
						}
					}) -join ",`n") + "`n$(" " * (4 * ($WhiteSpacePad / 4) + 4 ))],`n"
				} else {
					Write-Verbose -Message "Got a string inside inside hashtable or PSObject."
# '\\(?!["/bfnrt]|u[0-9a-f]{4})'
					$TempJsonString = GetNumberOrString -InputObject $InputObject.$Key
					$Json += " " * ((4 * ($WhiteSpacePad / 4)) + 4) + """$Key"": $TempJsonString,`n"
				}
			}
			$Json = $Json -replace '\s*,$' # remove trailing comma that'll break syntax
			$Json += "`n" + " " * $WhiteSpacePad + "},`n"
		}
		$Json
	}
	function ConvertTo-Json {
		[CmdletBinding()]
		#[OutputType([Void], [Bool], [String])]
		param(
			[AllowNull()]
			[Parameter(Mandatory=$true,
				ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true)]
			$InputObject,
			[Switch] $Compress,
			[Switch] $CoerceNumberStrings = $false)
		begin{
			$JsonOutput = ""
			$Collection = @()
# Not optimal, but the easiest now.
			[Bool] $Script:CoerceNumberStrings = $CoerceNumberStrings
			[String] $Script:NumberRegex = '^-?\d+(?:(?:\.\d+)?(?:e[+\-]?\d+)?)?$'
#$Script:NumberAndValueRegex = '^-?\d+(?:(?:\.\d+)?(?:e[+\-]?\d+)?)?$|^(?:true|false|null)$'
		} process {
# Hacking on pipeline support ...
			if ($_) {
				Write-Verbose -Message "Adding object to `$Collection. Type of object: $($_.GetType().FullName)."
				$Collection += $_
			}
		} end {
			if ($Collection.Count) {
				Write-Verbose -Message "Collection count: $($Collection.Count), type of first object: $($Collection[0].GetType().FullName)."
				$JsonOutput = ConvertToJsonInternal -InputObject ($Collection | ForEach-Object { $_ })
			} else {
				$JsonOutput = ConvertToJsonInternal -InputObject $InputObject
			}
			if ($null -eq $JsonOutput) {
				Write-Verbose -Message "Returning `$null."
				return $null # becomes an empty string :/
			} elseif ($JsonOutput -is [Bool] -and $JsonOutput -eq $true) {
				Write-Verbose -Message "Returning `$true."
				[Bool] $true # doesn't preserve bool type :/ but works for comparisons against $true
			} elseif ($JsonOutput-is [Bool] -and $JsonOutput -eq $false) {
				Write-Verbose -Message "Returning `$false."
				[Bool] $false # doesn't preserve bool type :/ but works for comparisons against $false
			} elseif ($Compress) {
				Write-Verbose -Message "Compress specified."
				(($JsonOutput -split "\n" | Where-Object { $_ -match '\S' }) -join "`n" -replace '^\s*|\s*,\s*$' -replace '\ *\]\ *$', ']') -replace ('(?m)^\s*("(?:\\"|[^"])+"): ((?:"(?:\\"|[^"])+")|(?:null|true|false|(?:' + $Script:NumberRegex.Trim('^$') + ')))\s*(?<Comma>,)?\s*$'), "`${1}:`${2}`${Comma}`n" -replace '(?m)^\s*|\s*\z|[\r\n]+'
			} else {
				($JsonOutput -split "\n" | Where-Object { $_ -match '\S' }) -join "`n" -replace '^\s*|\s*,\s*$' -replace '\ *\]\ *$', ']'
			}
		}
	}
}

[string]$strResult = $true
While ($strResult -eq $true) {
	[string]$strResult = Update
}
