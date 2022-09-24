Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force -STA

Function Format-FileSize($size) {
#	Param ([int]$size)
	If     ($size -gt 1TB)	{[string]::Format("{0:0.00} TB", $size / 1TB)}
	ElseIf ($size -gt 1GB)	{[string]::Format("{0:0.00} GB", $size / 1GB)}
	ElseIf ($size -gt 1MB)	{[string]::Format("{0:0.00} MB", $size / 1MB)}
	ElseIf ($size -gt 1KB)	{[string]::Format("{0:0.00} kB", $size / 1KB)}
	ElseIf ($size -gt 0)	{[string]::Format("{0:0.00} B", $size)}
	Else { "" }
}

Function Show_Dialog () {

#	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	Add-Type -AssemblyName System.Windows.Forms

	$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
	$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://dc=domain,dc=com")
	$objSearcher.PageSize = 1000
	$objSearcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=" + [Environment]::UserName + "))"
	$objSearcher.SearchScope = "Subtree"
	$objSearcher.PropertiesToLoad.Add("homeDirectory")
	$objResults = $objSearcher.FindAll()
	$objArray = New-Object -TypeName PSCustomObject

	If ($objResults["0"].Properties["homedirectory"] -ne "") {
		[string]$strUser = $objResults["0"].Properties["homedirectory"] -replace "\\\\domain.com\\documents\\user\\", ""
		$strUserFolder, $strUserAccount = $strUser -split "\\"
		If ($strUserAccount.Length -eq 0) {
			If ($strUserFolder -ne "") {
				$strUserAccount = $strUserFolder
				$strUserFolder = ""
			}
		}
		[string]$strPath = "\\domain.com\documents\cloud\" + $strUserAccount
		If (Test-Path -Path $strPath) {
#			$objPath = Get-ChildItem -Force $strPath | Where-Object {$_.Length -gt 0} | Select-Object Name, CreationTime, @{Name="Size";Expression={Format-FileSize($_.Length)}}
			$objPath = Get-ChildItem -Force $strPath | Where-Object {$_.Length -gt 0} | Sort-Object CreationTime -Descending | Select-Object Name, CreationTime, Length
			If ((Get-ChildItem -Path $strPath -Recurse | Where-Object {$_.PSIsContainer} | Measure-Object).Count -gt 0) {
				[System.Windows.Forms.MessageBox]::Show("На сетевом диске " + [char]171 + "W: (Облачный диск)" + [char]187 + " найдены папки, но для хранения и размещения в сети допустимы только файлы.`r`n`r`nИспользуйте архиватор " + [char]171 + "7-Zip" + [char]187 + " для сжатия папок в один единственный файл данных (правая кнопка мыши на нужной папке -> выбрать в меню 7-Zip -> Добавить к архиву... -> OK).`r`n`r`nПожалуйста, удалите все папки на сетевом диске W.", "Облачное хранение файлов" , 0, [System.Windows.Forms.MessageBoxIcon]::Warning) | out-null
			}
			If (($objPath | Measure-Object ).Count -gt 0) {
				[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | Out-Null
				[xml]$Computer_Dialog_XAML = @"
					<Window
						xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
						xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
						xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
						xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
						x:Name="Window" Title="Облачное хранение файлов: выбор файла для получения ссылки"
						Width="750" Height="350" ShowInTaskbar="True" Background="LightGray" WindowStartupLocation="CenterScreen">
						<Window.Resources>
							<DataTemplate x:Key="HeaderTemplateArrowUp">
								<DockPanel LastChildFill="True" Width="{Binding ActualWidth, RelativeSource={RelativeSource FindAncestor, AncestorType={x:Type GridViewColumnHeader}}}">
									<Path x:Name="ArrowUp" StrokeThickness="1" Fill="Black" Data="M 5,10 L 15,10 L 10,5 L 5,10" DockPanel.Dock="Right" Width="15" HorizontalAlignment="Right" Margin="0,0,5,0" SnapsToDevicePixels="True"/>
									<TextBlock Text="{Binding}" HorizontalAlignment="Center" VerticalAlignment="Center" TextWrapping="Wrap" Padding="20,0,0,0"/>
								</DockPanel>
							</DataTemplate>
							<DataTemplate x:Key="HeaderTemplateArrowDown">
								<DockPanel LastChildFill="True" Width="{Binding ActualWidth, RelativeSource={RelativeSource FindAncestor, AncestorType={x:Type GridViewColumnHeader}}}">
									<Path x:Name="ArrowDown" StrokeThickness="1" Fill="Black" Data="M 5,5 L 10,10 L 15,5 L 5,5" DockPanel.Dock="Right" Width="15" HorizontalAlignment="Right" Margin="0,0,5,0" SnapsToDevicePixels="True"/>
									<TextBlock Text="{Binding}" HorizontalAlignment="Center" VerticalAlignment="Center" TextWrapping="Wrap" Padding="20,0,0,0"/>
								</DockPanel>
							</DataTemplate>
							<DataTemplate x:Key="HeaderTemplateNoArrow">
								<DockPanel LastChildFill="True" Width="{Binding ActualWidth, RelativeSource={RelativeSource FindAncestor, AncestorType={x:Type GridViewColumnHeader}}}">
									<TextBlock Text="{Binding}" HorizontalAlignment="Center" VerticalAlignment="Center" TextWrapping="Wrap" Padding="20,0,20,0"/>
								</DockPanel>
							</DataTemplate>
						</Window.Resources>
						<ScrollViewer VerticalScrollBarVisibility="Auto">
							<StackPanel>
								<StackPanel.Resources>
									<Style x:Key="ListViewStyle" TargetType="{x:Type Control}">
									<Setter Property="Background" Value="LightGray"/>
									<Setter Property="Foreground" Value="Black"/>
									<Setter Property="IsEnabled" Value="True"/>
									<Setter Property="Focusable" Value="True"/>
									<Setter Property="HorizontalContentAlignment" Value="Center"/>
									<Style.Triggers>
										<Trigger Property="ItemsControl.AlternationIndex" Value="1">
											<Setter Property="Background" Value="White"/>
											<Setter Property="Foreground" Value="Black"/>
										</Trigger>
									</Style.Triggers>
									</Style>
									<Style TargetType="{x:Type GridViewColumnHeader}">
										<Setter Property="HorizontalContentAlignment" Value="Center"/>
										<Setter Property="VerticalContentAlignment" Value="Center"/>
										<Setter Property="Background" Value="Transparent"/>
										<Setter Property="Foreground" Value="Black"/>
										<Setter Property="BorderBrush" Value="Transparent"/>
										<Setter Property="FontWeight" Value="Bold"/>
										<Setter Property="FontWeight" Value="Bold"/>
										<Setter Property="Padding" Value="0,0,0,0"/>
										<Setter Property="ContentTemplate">
											<Setter.Value>
												<DataTemplate>
													<TextBlock Text="{Binding}" HorizontalAlignment="Center" VerticalAlignment="Center" TextWrapping="Wrap" Padding="20,0,20,0"/>
												</DataTemplate>
											</Setter.Value>
										</Setter>
									</Style>
								</StackPanel.Resources>
								<Grid Margin="0,0,0,0">
									<TextBlock x:Name="TextBlock" Width="270" Height="23" Margin="10,10,10,10" HorizontalAlignment="Left" VerticalAlignment="Top" TextWrapping="Wrap">
										<TextBlock.Inlines>
											<Run FontWeight="Bold" FontSize="12" Text="Выберите файл для получения ссылки:"/>
											<LineBreak />
										</TextBlock.Inlines>
									</TextBlock>
									<ListView Name="ListView" Width="710" Height="200" Margin="0,40,0,0" HorizontalAlignment="Center" VerticalAlignment="Top" AlternationCount="2" ItemContainerStyle="{StaticResource ListViewStyle}">
										<ListView.View>
											<GridView>
												<GridViewColumn Width="300" x:Name="NameColumn" DisplayMemberBinding="{Binding Path=Name}"><GridViewColumnHeader x:Name="NameHeader">Имя файла</GridViewColumnHeader></GridViewColumn>
												<GridViewColumn Width="90" x:Name="SizeFormatColumn" DisplayMemberBinding="{Binding Path=SizeFormat}"><GridViewColumnHeader x:Name="SizeFormatHeader">Размер</GridViewColumnHeader></GridViewColumn>
												<GridViewColumn Width="140" x:Name="SizeBitesColumn" DisplayMemberBinding="{Binding Path=SizeBites}"><GridViewColumnHeader x:Name="SizeBitesHeader">Размер в байтах</GridViewColumnHeader></GridViewColumn>
												<GridViewColumn Width="150" x:Name="DateTimeColumn" DisplayMemberBinding="{Binding Path=DateTime}"><GridViewColumnHeader x:Name="DateTimeHeader">Дата / время</GridViewColumnHeader></GridViewColumn>
											</GridView>
										</ListView.View>
									</ListView>
									<CheckBox x:Name="Retry" Content="При неудаче пробовать получить ссылку каждые 30 секунд" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="10,200,0,0" IsChecked="True"/>
									<Button x:Name="OK" Content="OK" Width="75" Height="23" Margin="-130,280,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
									<Button x:Name="Cancel" Content="Cancel" Width="75" Height="23" Margin="130,280,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
								</Grid>
							</StackPanel>
						</ScrollViewer>
					</Window>
"@
				If ($PSVersionTable.PSVersion.Major -gt 2) {
					Try {
						$Window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $Computer_Dialog_XAML) )
					} Catch {
						Write-Host "ERROR	Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered." -ForegroundColor Red
						$XAML_Problem = $true
					}
				} Else {
					$XAML_Problem = $true
				}

				If ($XAML_Problem) {

					$objForm = New-Object System.Windows.Forms.Form
					$objForm.Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
					$objForm.Text = "Облачное хранение файлов"
					$objForm.Size = New-Object System.Drawing.Size(700,140)
					$objForm.StartPosition = "CenterScreen"
# CenterScreen, Manual, WindowsDefaultLocation, WindowsDefaultBounds, CenterParent
					$objForm.AutoScroll = $true
					$objForm.MinimizeBox = $false
					$objForm.MaximizeBox = $false
					$objForm.WindowState = "Normal"
# Maximized, Minimized, Normal
					$objForm.SizeGripStyle = "Hide"
# Auto, Hide, Show
					$objForm.Opacity = 1.0
# 1.0 is fully opaque; 0.0 is invisible

#$Image = [system.drawing.image]::FromFile("$($Env:Public)\Pictures\Sample Pictures\Oryx Antelope.jpg")
#$Form.BackgroundImage = $Image
#$Form.BackgroundImageLayout = "None"
# None, Tile, Center, Stretch, Zoom

					$objLabel = New-Object System.Windows.Forms.Label
					$objLabel.Location = New-Object System.Drawing.Size(10,10) 
					$objLabel.Size = New-Object System.Drawing.Size(580,20) 
					$objLabel.Text = "Выберите файл для получения ссылки:"
					$objLabel.Font = New-Object System.Drawing.Font("Times New Roman",12,[System.Drawing.FontStyle]::Bold)
					$objLabel.BackColor = "Transparent"
					$objForm.Controls.Add($objLabel)

					$objComboBox = New-Object System.Windows.Forms.ComboBox
					$objComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList;
					$objComboBox.DataBindings.DefaultDataSourceUpdateMode = 0
					$objComboBox.Name = "ComboBox"
					$objComboBox.Location = New-Object System.Drawing.Size(10,40) 
					$objComboBox.Size = New-Object System.Drawing.Size(580,25)
# Шрифт общего списка:
					$objComboBox.Font = $ComboBoxFont

#					Write-Host $objPath
					$objFiles = New-Object PSObject
					$strCount = 0

					Foreach ($objResult in $objPath) {
						Add-Member -InputObject $objFiles -MemberType NoteProperty -Name $strCount -Value $objResult.Name
						$strCount++
#						If ($objResult.Size -ne "") {
						$objComboBox.Items.Add("[" + $objResult.CreationTime.ToString("yyyy-MM-dd") + " / " + $objResult.CreationTime.ToString("HH:mm:ss") + "] " + [char]171 + "W:\" + $objResult.Name + [char]187 + " [" + (Format-FileSize $objResult.Length) + "]") | out-null
#						} Else {
#							$objComboBox.Items.Add($objResult.Name + " [" +  $objResult.CreationTime + "] ") | out-null
#						}
					}
#					If (($objPath | Measure-Object ).Count -gt 0) { $objComboBox.SetSelected(0, $true) }
					$objComboBox.SelectedIndex = 0
					$objForm.Controls.Add($objComboBox) 

# Got rid of the block of code related to KeyPreview and KeyDown events.
					$OKButton = New-Object System.Windows.Forms.Button
					$OKButton.Location = New-Object System.Drawing.Size(600,39)
					$OKButton.Size = New-Object System.Drawing.Size(75,23)
					$OKButton.Text = "OK"
# Got rid of the Click event for the OK button, and instead just assigned its DialogResult property to OK.
					$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
					$objForm.Controls.Add($OKButton)
# Setting the form's AcceptButton property causes it to automatically intercept the Enter keystroke and
# treat it as clicking the OK button (without having to write your own KeyDown events).
					$objForm.AcceptButton = $OKButton

					$objForm.KeyPreview = $true
					$objForm.Add_KeyDown({If ($_.KeyCode -eq "Escape") {$objForm.Close()}})

					$objForm.Topmost = $true

# Now, instead of having events in the form assign a value to a variable outside of their scope, the code that calls the dialog
# instead checks to see if the user pressed OK and selected something from the box, then grabs that value.
					$result = $objForm.ShowDialog()

					If ($result -eq [System.Windows.Forms.DialogResult]::OK -and $objComboBox.SelectedIndex -ge 0) {
						$strURL = [int]$objComboBox.SelectedIndex
						[int[]][char[]][System.Text.Encoding]::UTF8.GetBytes($objFiles.$strURL) | % { $strURLencoded += "%{0:X2}" -f $_ }

						Add-Member -InputObject $objArray -MemberType NoteProperty -Name "FilePath" -Value $strPath
						Add-Member -InputObject $objArray -MemberType NoteProperty -Name "FileName" -Value $objFiles.$strURL
						Add-Member -InputObject $objArray -MemberType NoteProperty -Name "User" -Value $strUserAccount
						Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Retry" -Value "True"
						Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Cancel" -Value "False"

					} Else {
						Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Cancel" -Value "True"
#						$objArray.Add([string]"")
					}
				} Else {
					$ListView = $Window.FindName('ListView')
					$CheckboxRetry = $Window.FindName('Retry')
					$ButtonOK = $Window.FindName('OK')
					$ButtonCancel = $Window.FindName('Cancel')

					$objFiles = New-Object PSObject
					Foreach ($objResult in $objPath) {
						$ListViewItem = New-Object PSObject
						Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "Name" -Value $objResult.Name
						Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "SizeFormat" -Value (Format-FileSize $objResult.Length)
						Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "SizeBites" -Value $objResult.Length
						Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "DateTime" -Value ($objResult.CreationTime.ToString("yyyy-MM-dd") + " / " + $objResult.CreationTime.ToString("HH:mm:ss"))
						$ListView.Items.Add($ListViewItem)
						Remove-Variable -Name ListViewItem -ErrorAction SilentlyContinue
					}

					$Listview.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription("DateTime", "Descending")))
					$script:ColumnHeaders = @{"Name"=""; "SizeBites" = ""; "DateTime"=""}
					$script:ColumnHeaders.GetEnumerator() | % { 
						$ColumnHeaderName = $($_.key)
						($Window.FindName($ColumnHeaderName + "Header")).Add_Click({
							param ($ColumnHeader)
							$ColumnHeaderName = $ColumnHeader.Name.Replace("Header", "")
							$ColumnHeaderValue = $script:ColumnHeaders[$ColumnHeaderName]
							$Listview.Items.SortDescriptions.Clear()

							$script:ColumnHeaders.GetEnumerator() | % { 
								(($Window.FindName($($_.key) + "Header"))).Column.HeaderTemplate = $Window.Resources["HeaderTemplateNoArrow"]
							}

							If ($ColumnHeaderValue -eq "descending") {
								$Listview.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription ($ColumnHeaderName, "Ascending")))
								$ColumnHeader.Column.HeaderTemplate = $Window.Resources["HeaderTemplateArrowDown"]
								$Listview.Items.Refresh()
								$script:ColumnHeaders[$ColumnHeaderName] = "ascending"
							} ElseIf ($ColumnHeaderValue -eq "ascending") {
								$Listview.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($ColumnHeaderName, "Descending")))
								$ColumnHeader.Column.HeaderTemplate = $Window.Resources["HeaderTemplateArrowUp"]
								$Listview.Items.Refresh()
								$script:ColumnHeaders[$ColumnHeaderName] = "descending"
							} Else {
								$Listview.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($ColumnHeaderName, "Ascending")))
								$ColumnHeader.Column.HeaderTemplate = $Window.Resources["HeaderTemplateArrowDown"]
#								$ColumnHeader.Column.SortMode = "Automatic"
								$Listview.Items.Refresh()
								$script:ColumnHeaders[$ColumnHeaderName] = "ascending"
							}
						})
					}

					$ButtonOK.Add_Click({
						If ($ListView.SelectedItems.Count -gt 0) {
#							[System.Windows.Forms.MessageBox]::Show(("Выбран файл: " + $ListView.SelectedItem.Name + " (" + $ListView.SelectedItem.Size + ")"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
							[int[]][char[]][System.Text.Encoding]::UTF8.GetBytes($ListView.SelectedItem.Name) | % { $strURLencoded += "%{0:X2}" -f $_ }
							Add-Member -InputObject $objArray -MemberType NoteProperty -Name "FilePath" -Value $strPath
							Add-Member -InputObject $objArray -MemberType NoteProperty -Name "FileName" -Value $ListView.SelectedItem.Name
							Add-Member -InputObject $objArray -MemberType NoteProperty -Name "User" -Value $strUserAccount
							If ($CheckboxRetry.IsChecked) {
								Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Retry" -Value "True"
							} Else {
								Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Retry" -Value "False"
							}
							Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Cancel" -Value "False"
							$Window.Close()
						} Else {
							[System.Windows.Forms.MessageBox]::Show(("Необходимо выбрать файл для получения ссылки!"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
						}
					})
					$ButtonCancel.Add_Click({
						Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Cancel" -Value "True"
						$Window.Close()
					})

					$Window.ShowDialog() | Out-Null

					If (-not ($objArray.Cancel)) {
						Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Cancel" -Value "True"
					}

					Remove-Variable -Name ColumnHeaders -Scope Script -ErrorAction SilentlyContinue
				}
			} Else {
				[System.Windows.Forms.MessageBox]::Show("На сетевом диске " + [char]171 + "W: (Облачный диск)" + [char]187 + " не найдено подходящих к размещению файлов.", "Облачное хранение файлов" , 0, [System.Windows.Forms.MessageBoxIcon]::Warning) | out-null
				Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Cancel" -Value "True"
			}
		} Else {
			[System.Windows.Forms.MessageBox]::Show("Ошибка: путь к каталогу облачного диска, заданный в аккаунте пользователя не найден.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", "Облачное хранение файлов", 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
			Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Cancel" -Value "True"
		}
	} Else {
		[System.Windows.Forms.MessageBox]::Show("Ошибка: в аккаунте пользователя не найден каталог облачного диска.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", "Облачное хранение файлов" , 0, [System.Windows.Forms.MessageBoxIcon]::Warning) | out-null
		Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Cancel" -Value "True"
	}
	Return $objArray
}

Function Get_URL ($objArray) {

#	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	Add-Type -AssemblyName System.Windows.Forms
#	[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
	Add-Type -AssemblyName System.Drawing
	Add-Type -AssemblyName System.Web

	$objForm = New-Object System.Windows.Forms.Form
	$objForm.Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
	$objForm.Text = "Облачное хранение файлов"
	$objForm.Size = New-Object System.Drawing.Size(690,110) 
	$objForm.StartPosition = "CenterScreen"
# CenterScreen, Manual, WindowsDefaultLocation, WindowsDefaultBounds, CenterParent
	$objForm.AutoScroll = $true
	$objForm.MinimizeBox = $false
	$objForm.MaximizeBox = $false
	$objForm.WindowState = "Normal"
	$objForm.SizeGripStyle = "Hide"
# Auto, Hide, Show
	$objForm.Opacity = 0.8
# 1.0 is fully opaque; 0.0 is invisible

#$Image = [system.drawing.image]::FromFile("$($Env:Public)\Pictures\Sample Pictures\Oryx Antelope.jpg")
#$Form.BackgroundImage = $Image
#$Form.BackgroundImageLayout = "None"
# None, Tile, Center, Stretch, Zoom

	$objProgressBar = New-Object System.Windows.Forms.ProgressBar
	$objProgressBar.DataBindings.DefaultDataSourceUpdateMode = 0
	$objProgressBar.Minimum = 0
	$objProgressBar.Maximum = 100
	$objProgressBar.Step = 5
	$objProgressBar.Name = "ProgressBar"
	$objProgressBar.Location = New-Object System.Drawing.Size(10,10)
	$objProgressBar.Size = New-Object System.Drawing.Size(655,25)
	$objForm.Controls.Add($objProgressBar)

	$objStatusBar = New-Object Windows.Forms.StatusBar
	$objStatusBar.DataBindings.DefaultDataSourceUpdateMode = 0
	$objStatusBar.Name = "StatusBar"
	$objStatusBar.Location = New-Object System.Drawing.Size(5,40)
	$objStatusBar.Size = New-Object System.Drawing.Size(655,25)
	$objStatusBar.Text = "[00%] Запуск проверок на получение ссылки..."
	$objForm.Controls.Add($objStatusBar)

	$objTimer_OnTick = {$objProgressBar.PerformStep()}

	$objTimer = New-Object System.Windows.Forms.Timer
	$objTimer.Add_Tick($objTimer_OnTick)
	$objTimer.Interval = 100
	$objTimer.Start()

	$objForm.Show()| Out-Null

	$strURL = ""

# If "old" method of choice:
	If (($objArray | Measure-Object ).Count -eq 2) {
		$objArray = $objArray[1]
	}
# Check incoming params:
	If (($objArray.Cancel) -and ($objArray.Cancel -eq "False")) {
		$objProgressBar.Value = 10
		$objStatusBar.Text = "[10%] Получение и обработка массива данных из формы ввода..."
#		$objProgressBar.PerformStep()
		If ($objArray.FilePath) {
			$strFilePath = $objArray.FilePath
		}
		If ($objArray.FileName) {
			$strFileName = $objArray.FileName
		}
		If ($objArray.User) {
			$strUser = $objArray.User
		}
		If ($objArray.Retry) {
			$strRetry = $objArray.Retry
		}

		$objForm.Text = 'Облачное хранение файлов: "' + $strFileName + '"'

		If (Test-Path -LiteralPath ($strFilePath + "/" + $strFileName)) {
			$objProgressBar.Value = 20
			$objStatusBar.Text = "[20%] Успешная проверка: исходный файл существует..."

			$objProgressBar.Value = 30
			$objStatusBar.Text = "[30%] Попытка подключения к удаленному серверу для проверки наличия файла в облаке..."

			$strURI	= "https://api.dropboxapi.com/2/files/list_folder"
			$strBody	= ConvertTo-Json @{
				"path" = "/Public/" + $strUser
				"recursive" = $false
				"include_media_info" = $false
				"include_deleted" = $false
				"include_has_explicit_shared_members" = $false
				"include_mounted_folders" = $false
			}
			$objWebResponseListFolder = Get_WebResponse $strURI $strBody

			If ([int]$objWebResponseListFolder.Response.StatusCode -eq "200") {
#			If ($objWebResponseListFolder.Response.StatusCode -eq "OK") {
#				Write-Host ("Success: '" + [int]$objWebResponseListFolder.Response.StatusCode + "' ('" + $objWebResponseListFolder.Response.StatusDescription + "') [GOT INFO FROM SERVER]") -ForegroundColor Green
				$objProgressBar.Value = 40
				$objStatusBar.Text = "[40%] Успешное подключение к удаленному серверу. Проверка существования файла..."

#				$objWebResponseResultListFolder = $objWebResponseListFolder.Result | ConvertFrom-JSON
				$objWebResponseResultListFolder = ConvertFrom-JSON $objWebResponseListFolder.Result

				$strFileID = ""
				Foreach ($objTemp in $objWebResponseResultListFolder.entries) {
					If ($objTemp.name -eq $strFileName) {
						$strFileID = $objTemp.id
					}
				}

				If ($strFileID -ne "") {
					$objProgressBar.Value = 50
					$objStatusBar.Text = "[50%] Конечный файл найден на удаленном сервере. Проверка существования ссылки для этого файла..."

					$strURI	= "https://api.dropboxapi.com/2/sharing/list_shared_links"
					$strBody	= ConvertTo-Json @{
#						"path" = "/Public/" + $strUser + "/" + $strFileName
						"path" = $strFileID
						"direct_only" = $true
					}

#write-host ("Запрос на проверку существования ссылки: " + $strBody)
					$objWebResponseListSharedLinks = Get_WebResponse $strURI $strBody
#write-host ("Ответ на запрос существования ссылки: " + $objWebResponseListSharedLinks.Result)

					If (([int]$objWebResponseListSharedLinks.Response.StatusCode -eq "200") -or ([int]$objWebResponseListSharedLinks.Response.StatusCode -eq "409")) {

#write-host ("Код выхода на запрос существования ссылки: " + [int]$objWebResponseListSharedLinks.Response.StatusCode)
						If ([int]$objWebResponseListSharedLinks.Response.StatusCode -eq "200") {
#							$objWebResponseResultListSharedLinks = $objWebResponseListSharedLinks.Result | ConvertFrom-JSON
							$objWebResponseResultListSharedLinks = ConvertFrom-JSON $objWebResponseListSharedLinks.Result
						}

						If (($objWebResponseResultListSharedLinks.links.Count -eq 0) -or ([int]$objWebResponseListSharedLinks.Response.StatusCode -eq "409")) {
							$objProgressBar.Value = 55
							$objStatusBar.Text = "[55%] Ссылка для файла не найдена, попытка создания ссылки..."
							$strURI	= "https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings"

							$strBody	= ConvertTo-Json @{
#								"path" = "/Public/" + $strUser + "/" + $strFileName
								"path" = $strFileID
							}

							$objWebResponseCreateSharedLink = Get_WebResponse $strURI $strBody

							If ([int]$objWebResponseCreateSharedLink.Response.StatusCode -eq "200") {

								$strURI	= "https://api.dropboxapi.com/2/sharing/list_shared_links"
								$strBody	= ConvertTo-Json @{
#									"path" = "/Public/" + $strUser + "/" + $strFileName
									"path" = $strFileID
									"direct_only" = $true
								}
								$objWebResponseListSharedLinks = Get_WebResponse $strURI $strBody

								If ([int]$objWebResponseListSharedLinks.Response.StatusCode -eq "200") {
#									$objWebResponseResultListSharedLinks = $objWebResponseListSharedLinks.Result | ConvertFrom-JSON
									$objWebResponseResultListSharedLinks = ConvertFrom-JSON $objWebResponseListSharedLinks.Result
								} Else {
									$objProgressBar.Value = 100
									$objStatusBar.Text = "[100%] Ошибка: невозможно проверить созданную ссылку для файла, код ошибки: '" + $objWebResponseListSharedLinks.Response.StatusCode + "'."
									$objForm.Close()
									[System.Windows.Forms.MessageBox]::Show("Ошибка: невозможно проверить созданную ссылку для файла, код ошибки: '" + $objWebResponseListSharedLinks.Response.StatusCode + "'.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
									$strURL = "no"
								}
							} Else {
##								$objWebResponseResultCreateSharedLink = $objWebResponseCreateSharedLink.Result | ConvertFrom-JSON
#								$objWebResponseResultCreateSharedLink = ConvertFrom-JSON $objWebResponseCreateSharedLink.Result
								$objProgressBar.Value = 100
								$objStatusBar.Text = "[100%] Ошибка: невозможно создать ссылку для файла, код ошибки: '" + $objWebResponseCreateSharedLink.Response.StatusCode + "'."
								$objForm.Close()
								[System.Windows.Forms.MessageBox]::Show("Ошибка: невозможно создать ссылку для файла, код ошибки: '" + $objWebResponseCreateSharedLink.Response.StatusCode + "'.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
								$strURL = "no"
							}
						} Else {
#							$objWebResponseResultListSharedLinks = $objWebResponseListSharedLinks.Result | ConvertFrom-JSON
							$objWebResponseResultListSharedLinks = ConvertFrom-JSON $objWebResponseListSharedLinks.Result
						}

						If ($strURL -ne "no") {

							If ($objWebResponseResultListSharedLinks.links[0].name -ne "") {
								$objProgressBar.Value = 60
								$objStatusBar.Text = "[60%] Ссылка для файла существует. Данные файла успешно получены. Проверка на соответствие исходному файлу..."

								If ((Get-Item -LiteralPath ($strFilePath + "/" + $strFileName)).length -gt 0) {
									$objProgressBar.Value = 70
									$objStatusBar.Text = "[70%] Успешная проверка: размер исходного файла больше нуля (" + (Get-Item -LiteralPath ($strFilePath + "/" + $strFileName)).length + " байт)..."

									If ($objWebResponseResultListSharedLinks.links[0].size -gt 0) {
										$objProgressBar.Value = 80
										$objStatusBar.Text = "[80%] Успешная проверка: размер конечного файла больше нуля (" + $objWebResponseResultListSharedLinks.links[0].size + " байт)..."

										If ((Get-Item -LiteralPath ($strFilePath + "/" + $strFileName)).length -eq $objWebResponseResultListSharedLinks.links[0].size) {
											$objProgressBar.Value = 90
											$objStatusBar.Text = "[90%] Успешная проверка: размеры исходного и конечного файла совпадают. Создание ссылки..."

											$objTimer.Stop()
											$objTimer.Enabled = $false
											$objForm.Visible = $false
											$objProgressBar.Visible = $false
											$objStatusBar.Visible = $false

											$objForm.Size = New-Object System.Drawing.Size(700,160)
											$objForm.Opacity = 1.0

											$objLabel = New-Object System.Windows.Forms.Label
											$objLabel.Location = New-Object System.Drawing.Size(10,10) 
											$objLabel.Size = New-Object System.Drawing.Size(665,20) 
											$objLabel.Text = 'Ссылка для скачивания файла "W:\' + $objWebResponseResultListSharedLinks.links[0].name + '":'
											$objLabel.Font = New-Object System.Drawing.Font("Times New Roman",12,[System.Drawing.FontStyle]::Bold)
											$objLabel.BackColor = "Transparent"
											$objForm.Controls.Add($objLabel)

											$objTextBox = New-Object System.Windows.Forms.TextBox 
											$objTextBox.Location = New-Object System.Drawing.Size(10,40) 
											$objTextBox.Size = New-Object System.Drawing.Size(665,25) 

#											If ($objWebResponseResultListSharedLinks.links[0].url.Substring($objWebResponseResultListSharedLinks.links[0].url.LastIndexOf("/") + 1) -eq ($strFileName + "?dl=0")) {
												$objTextBox.Text = $objWebResponseResultListSharedLinks.links[0].url.Replace("?dl=0","?dl=1")
												$clipboard = $objWebResponseResultListSharedLinks.links[0].url.Replace("?dl=0","?dl=1")
#											} Else {
#												$objTextBox.Text = $objWebResponseResultListSharedLinks.links[0].url
#												$clipboard = $objWebResponseResultListSharedLinks.links[0].url
#												[System.Windows.Forms.MessageBox]::Show("Предупреждение: имя файла содержит нестандартные (возможно русские) символы.`r`n`r`nСсылка будет создана без возможности прямого скачивания.", "Облачное хранение файлов" , 0, [System.Windows.Forms.MessageBoxIcon]::Warning) | out-null
#											}
											$objForm.Controls.Add($objTextBox)

											$OKButton = New-Object System.Windows.Forms.Button
											$OKButton.Location = New-Object System.Drawing.Size(120,75)
											$OKButton.Size = New-Object System.Drawing.Size(180,23)
											$OKButton.Text = "Скопировать в буфер обмена"
											$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
											$objForm.Controls.Add($OKButton)
											$objForm.AcceptButton = $OKButton

											$CancelButton = New-Object System.Windows.Forms.Button
											$CancelButton.Location = New-Object System.Drawing.Size(400,75)
											$CancelButton.Size = New-Object System.Drawing.Size(75,23)
											$CancelButton.Text = "Cancel"
											$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
											$objForm.Controls.Add($CancelButton)
											$objForm.CancelButton = $CancelButton

											$objForm.KeyPreview = $true
											$objForm.Add_KeyDown({If ($_.KeyCode -eq "Escape") {$objForm.Close()}})

											$objForm.Topmost = $true

											$result = $objForm.ShowDialog()

											If ($result -eq "OK") {
												[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
												Add-Type -Assembly PresentationCore
												[System.Windows.Forms.Clipboard]::Clear()
												[System.Windows.Forms.Clipboard]::SetText($clipboard)
												If ([System.Windows.Forms.Clipboard]::ContainsText() -and ([System.Windows.Forms.Clipboard]::GetText() -eq $clipboard)) {
													[System.Windows.Forms.MessageBox]::Show("Ссылка успешно скопирована в буфер обмена.`r`n`r`nВоспользуйтесь вставкой из буфера или комбинацией клавиш:`r`n[CTRL + V] или [CTRL + Insert]", "Облачное хранение файлов", 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
												} Else {
													$objTextBox.Copy()
													$objTextBox.Dispose()
													If (test-path "C:\Windows\System32\clip.exe") {
														$clipboard | clip
													} Else {
														$clipboard | Set-Clipboard
													}
													[System.Windows.Forms.MessageBox]::Show("Ссылка успешно скопирована в буфер обмена.`r`n`r`nВоспользуйтесь вставкой из буфера или комбинацией клавиш:`r`n[CTRL + V] или [CTRL + Insert]", "Облачное хранение файлов", 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
												}
											}

											$objForm.Close()
											$strURL = "yes"

										} Else {
											$objProgressBar.Value = 100
											$objStatusBar.Text = "[100%] Ошибка: файл в облаке имеет размер, отличный от размера в облачном диске."
											$objForm.Close()
											[System.Windows.Forms.MessageBox]::Show("Ошибка: файл в облаке имеет размер, отличный от размера в облачном диске.`r`n`r`nЕсли это сообщение появляется снова и снова и прошло более 30 минут спустя размещения файла в облачном диске, пожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
											$strURL = "no"
										}
									} Else {
										$objProgressBar.Value = 100
										$objStatusBar.Text = "[100%] Ошибка: конечный файл на удаленном сервере имеет нулевой размер."
										$objForm.Close()
										[System.Windows.Forms.MessageBox]::Show("Ошибка: конечный файл на удаленном сервере имеет нулевой размер.`r`n`r`nЕсли это сообщение появляется снова и снова и прошло более 30 минут спустя размещения файла в облачном диске, пожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
										$strURL = "no"
									}
								} Else {
									$objProgressBar.Value = 100
									$objStatusBar.Text = "[100%] Ошибка: файл в облачном диске имеет нулевой размер."
									$objForm.Close()
									[System.Windows.Forms.MessageBox]::Show("Ошибка: файл в облачном диске имеет нулевой размер.`r`n`r`nПожалуйста, проверьте файл (он должен быть доступен и открываться).", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
									$strURL = "no"
								}
							} Else {
								$objProgressBar.Value = 100
								$objStatusBar.Text = "[100%] Ошибка: получен пустой ответ от сервера."
								$objForm.Close()
								[System.Windows.Forms.MessageBox]::Show("Ошибка: получен пустой ответ от сервера.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
								$strURL = "no"
							}
						}
					} ElseIf ([int]$objWebResponseListSharedLinks.Response.StatusCode -eq "400") {
						$objProgressBar.Value = 100
						$objStatusBar.Text = "[100%] Ошибка: получен отказ в обработке данных с удаленного сервера."
						$objForm.Close()
						[System.Windows.Forms.MessageBox]::Show("Фатальная ошибка: получен отказ в обработке данных с удаленного сервера.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
						$strURL = "no"
					} ElseIf ($objWebResponseListSharedLinks.Response.StatusCode) {
						$objProgressBar.Value = 100
						$objStatusBar.Text = "[100%] Ошибка: получен неизвестный код обработки запроса ('" + $objWebResponseListSharedLinks.Response.StatusCode + "') с удаленного сервера."
						$objForm.Close()
						[System.Windows.Forms.MessageBox]::Show("Фатальная ошибка: получен неизвестный код обработки запроса ('" + $objWebResponseListSharedLinks.Response.StatusCode + "') с удаленного сервера.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
						$strURL = "no"
					} Else {
						$objProgressBar.Value = 100
						$objStatusBar.Text = "[100%] Ошибка: отсутствует код обработки запроса с удаленного сервера."
						$objForm.Close()
						[System.Windows.Forms.MessageBox]::Show("Фатальная ошибка: отсутствует код обработки запроса с удаленного сервера.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
						$strURL = "no"
					}
				} Else {
					$objProgressBar.Value = 100
					$objStatusBar.Text = "[100%] Конечный файл не найден на удаленном сервере, пожалуйста, попробуйте позже."
					$objForm.Close()
					[System.Windows.Forms.MessageBox]::Show("Конечный файл не найден на удаленном сервере, пожалуйста, попробуйте позже...`r`n`r`nВозможно, если размер файла достаточно велик, процесс закачивания его в сеть Интернет займет продолжительное время.`r`n`r`nЕсли это сообщение появляется снова и снова и прошло более 30 минут с момента размещения файла в облачном диске, пожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Warning) | out-null
					$strURL = "no"
				}
			} ElseIf ([int]$objWebResponseListFolder.Response.StatusCode -eq "409") {
#			} ElseIf ($objWebResponse.Response.StatusCode -eq "Conflict") {
#				Write-Host ("Error: '" + [int]$objWebResponse.Response.StatusCode + "' ('" + $objWebResponse.Response.StatusDescription + "') [USER FOLDER NOT FOUND ON SERVER]") -ForegroundColor Red
				$objProgressBar.Value = 100
				$objStatusBar.Text = "[100%] Ошибка: каталог пользователя не найден на удаленном сервере."
				$objForm.Close()
				[System.Windows.Forms.MessageBox]::Show("[100%] Фатальная ошибка: каталог пользователя не найден на удаленном сервере.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
				$strURL = "no"
			} ElseIf ([int]$objWebResponseListFolder.Response.StatusCode -eq "400") {
#			} ElseIf ($objWebResponse.Response.StatusCode -eq "BadRequest") {
#				Write-Host ("Error: '" + [int]$objWebResponse.Response.StatusCode + "' ('" + $objWebResponse.Response.StatusDescription + "') [ERROR IN INPUT PARAMETERS]") -ForegroundColor Red
				$objProgressBar.Value = 100
				$objStatusBar.Text = "[100%] Ошибка: получен отказ в обработке данных с удаленного сервера."
				$objForm.Close()
				[System.Windows.Forms.MessageBox]::Show("Фатальная ошибка: получен отказ в обработке данных с удаленного сервера.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
				$strURL = "no"
			} ElseIf ($objWebResponseListFolder.Response.StatusCode) {
#				Write-Host ("Error: '" + [int]$objWebResponse.Response.StatusCode + "' ('" + $objWebResponse.Response.StatusDescription + "') [CAN NOT CONNECT TO SERVER]") -ForegroundColor Red
				$objProgressBar.Value = 100
				$objStatusBar.Text = "[100%] Ошибка: получен неизвестный код обработки запроса ('" + $objWebResponse.Response.StatusCode + "') с удаленного сервера."
				$objForm.Close()
				[System.Windows.Forms.MessageBox]::Show("Фатальная ошибка: получен неизвестный код обработки запроса ('" + $objWebResponse.Response.StatusCode + "') с удаленного сервера.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
				$strURL = "no"
			} Else {
#				Write-Host ("Error: '" + [int]$objWebResponse.Response.StatusCode + "' ('" + $objWebResponse.Response.StatusDescription + "') [UNKNOWN]") -ForegroundColor Red
				$objProgressBar.Value = 100
				$objStatusBar.Text = "[100%] Ошибка: отсутствует код обработки запроса с удаленного сервера."
				$objForm.Close()
				[System.Windows.Forms.MessageBox]::Show("Ошибка: отсутствует код обработки запроса с удаленного сервера (возможно проблемы с подключением).`r`n`r`nЕсли это сообщение появляется снова и снова и прошло более 30 минут спустя размещения файла в облачном диске, пожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
				$strURL = "no"
			}
		} Else {
			$objProgressBar.Value = 100
			$objStatusBar.Text = "[100%] Ошибка: файл не найден в облачном диске."
			$objForm.Close()
			[System.Windows.Forms.MessageBox]::Show("Фатальная ошибка: файл не найден в облачном диске.`r`n`r`nПожалуйста, обратитесь в IT-отдел.", 'Облачное хранение файлов: "' + $strFileName + '"', 0, [System.Windows.Forms.MessageBoxIcon]::Error) | out-null
			$strURL = "no"
		}

		If (($strRetry -eq "True") -and ($strURL -eq "no")) {
			Get_URL_Retry $objArray
		}
	}
}

Function Get_WebResponse ($URI, $Body) {

	$objArray = New-Object -TypeName PSCustomObject
#	$EncodedToken = [System.Text.Encoding]::UTF8.GetBytes($OriginalToken)
#	$OriginalToken = [System.Text.Encoding]::ASCII.GetString($EncodedToken)
	$Token		= @()
	$Method		= "POST"
	$ContentType	= "Application/json"
	$Headers	= @{"Authorization" = "Bearer " + $Token}

	Try {
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
		[System.Net.ServicePointManager]::DefaultConnectionLimit = 1024
		$objWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
#		$objWebProxy = [System.Net.WebRequest]::DefaultWebProxy
		$objWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
#		$objWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
		$objWebConnection = [System.Net.WebRequest]::Create($URI)
		$objWebConnection.Proxy = $objWebProxy
		$objWebConnection.Method = $Method
		$objWebConnection.ContentType = $ContentType
		$objWebConnection.Headers.Add("Authorization", "Bearer " + ([System.Text.Encoding]::UTF8.GetString($Token)))
		$objWebConnection.Timeout = 10000
		$objWebStream = $objWebConnection.GetRequestStream()
# Errors with non-latin chars!
#		$Body = [byte[]][char[]]$Body
		$Body = [Text.Encoding]::ASCII.GetBytes($Body)
		$objWebStream.Write($Body, 0, $Body.Length)
		$objWebStream.Flush()
		$objWebStream.Close()
		$objWebResponse = $objWebConnection.GetResponse()
		If ([int]$objWebResponse.StatusCode -eq "200") {
#		If ($objWebResponse.StatusCode -eq "OK") {
			$objWebResponseStream = $objWebConnection.GetResponse().GetResponseStream()
			$objWebResponseStreamReader = New-Object System.IO.StreamReader($objWebResponseStream) 
			$objWebResult = $objWebResponseStreamReader.ReadToEnd()
		} Else {
			$objWebResult = @()
		}
	} Catch [System.Net.WebException] {
      		$objWebResponse = $_.Exception.Response
		$objWebResult = @()
	}

# The same on Powershell 3.0:
#	Try {
#		$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList "Domain\name", (ConvertTo-SecureString "password" -AsPlainText -Force)
#		$objWebResult = Invoke-WebRequest -Uri $URI -Method $Method -Headers $Headers -ContentType $ContentType -Body $Body -TimeoutSec 10
#		$objWebResult = Invoke-WebRequest -Proxy ([System.Net.WebRequest]::GetSystemWebProxy()).GetProxy($URI) -ProxyCredential ([System.Net.CredentialCache]::DefaultCredentials) -Uri $URI -Method $Method -Headers $Headers -ContentType $ContentType -Body $Body -TimeoutSec 10
#	} Catch {
#		$objWebResponse = $_.Exception.Response.StatusCode.Value__
#	}

	Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Response" -Value $objWebResponse
	Add-Member -InputObject $objArray -MemberType NoteProperty -Name "Result" -Value $objWebResult

	Return $objArray
}

Function Get_URL_Retry ($objArray) {

	Add-Type -AssemblyName System.Windows.Forms

	If ($objArray.FileName) {
		$strFileName = $objArray.FileName
	}

	$objForm = New-Object System.Windows.Forms.Form
	$objForm.Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
	$objForm.Text = 'Облачное хранение файлов: "' + $strFileName + '"'
	$objForm.Size = New-Object System.Drawing.Size(700,160)
	$objForm.StartPosition = "CenterScreen"
# CenterScreen, Manual, WindowsDefaultLocation, WindowsDefaultBounds, CenterParent
	$objForm.AutoScroll = $true
	$objForm.MinimizeBox = $false
	$objForm.MaximizeBox = $false
	$objForm.WindowState = "Normal"
# Maximized, Minimized, Normal
	$objForm.SizeGripStyle = "Hide"
# Auto, Hide, Show
	$objForm.Opacity = 1.0
# 1.0 is fully opaque; 0.0 is invisible

#$Image = [system.drawing.image]::FromFile("$($Env:Public)\Pictures\Sample Pictures\Oryx Antelope.jpg")
#$Form.BackgroundImage = $Image
#$Form.BackgroundImageLayout = "None"
# None, Tile, Center, Stretch, Zoom

	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(50,30)
	$objLabel.Size = New-Object System.Drawing.Size(625,20)
	$objLabel.Text = "Через 30 секунд можно снова проверить доступность файла для скачивания"
	$objLabel.Font = New-Object System.Drawing.Font("Times New Roman",12,[System.Drawing.FontStyle]::Bold)
	$objLabel.BackColor = "Transparent"
	$objForm.Controls.Add($objLabel)

	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(120,75)
	$OKButton.Size = New-Object System.Drawing.Size(180,23)
	$OKButton.Text = "Попробовать снова"
	$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$objForm.Controls.Add($OKButton)
	$objForm.AcceptButton = $OKButton

	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(400,75)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Закрыть"
	$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$objForm.Controls.Add($CancelButton)
	$objForm.CancelButton = $CancelButton

	$objForm.KeyPreview = $true
	$objForm.Add_KeyDown({If ($_.KeyCode -eq "Escape") {$objForm.Close()}})

	$objForm.Topmost = $true

	$result = $objForm.ShowDialog()

	If ($result -eq "OK") {
		Start-Sleep -s 30
		Get_URL $objArray
	}
}

If ($PSVersionTable.PSVersion.Major -lt 3) {
#	Function ConvertFrom-Json([string] $json) {
#		[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | out-null
#		Add-Type -AssemblyName System.Web.Extensions
#		$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
#		write-output (new-object -type PSObject -property $ser.DeserializeObject($json))
##		write-output ($ser.DeserializeObject($json))
#	}
#	Function ConvertTo-Json([psobject] $item) {
#		[System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | out-null
#		$ser =  New-Object System.Web.Script.Serialization.JavaScriptSerializer 
##		$hashed = @{}
##		$item.psobject.properties | %{ $hashed.($_.Name) = $_.Value }
##		write-output $ser.Serialize($hashed) 
#		write-output $ser.Serialize($item) 
#	}
	Function ConvertFrom-Json {
		param(
			[Parameter(ValueFromPipeline=$true)]
			[string]$json
		)
		begin {
			Add-Type -AssemblyName System.Web.Extensions
			$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
		} process {
			,$ser.DeserializeObject($json)
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

[array]$objArray = Show_Dialog
Get_URL $objArray
