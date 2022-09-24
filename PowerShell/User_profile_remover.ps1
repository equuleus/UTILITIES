Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force

$LDAP			= "LDAP://dc=domain,dc=com"
#$Login			= "NT AUTHORITY\LOCAL SERVICE"
#$Login			= "NT AUTHORITY\NETWORK SERVICE"
# Автоматический ввод данных для входа на компьюьтер:
$Login			= "DOMAIN\administrator"
$Password		= "password"

$LogPath		= "D:\"
$LogFileName		= (Get-Date -format "yyyy-MM-dd_HH-mm-ss") + ".txt"
$LogFullFileName	= $LogPath + "\" + $LogFileName

$PathCurrent		= Split-Path -parent $MyInvocation.MyCommand.Definition
$PathTemp		= "$env:TEMP\PROFILES"
$PathBackup		= "D:\BACKUP"
$7zip			= $PathCurrent + "\7-Zip\7za.exe"

Function Write-Log ($LogFullFileName, $MessageText) {
	If ($MessageText -ne "") {
		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + $MessageText
	}
	Write-Host $MessageText
	If ($LogFullFileName -ne "") {
		$MessageText | Out-File -Encoding Unicode -Append -Force -FilePath $LogFullFileName
	}
}

Write-Log $LogFullFileName "[START]"

Function Format-FileSize() {
	Param ([long]$size)
	If	($size -gt 1TB)	{[string]::Format("{0:0.00} TB", $size / 1TB)}
	ElseIf	($size -gt 1GB)	{[string]::Format("{0:0.00} GB", $size / 1GB)}
	ElseIf	($size -gt 1MB)	{[string]::Format("{0:0.00} MB", $size / 1MB)}
	ElseIf	($size -gt 1KB)	{[string]::Format("{0:0.00} kB", $size / 1KB)}
	ElseIf	($size -gt 0)	{[string]::Format("{0:0.00} B", $size)}
	Else			{""}
}

Function Computer_Search ($LDAP, $LogFullFileName) {
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null

	$objForm = New-Object System.Windows.Forms.Form
	$objForm.Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
	$objForm.Text = "Удаление профилей пользователей: поиск компьютеров в сети"
	$objForm.Size = New-Object System.Drawing.Size(690,110) 
	$objForm.StartPosition = "CenterScreen"
	$objForm.AutoScroll = $True
	$objForm.MinimizeBox = $False
	$objForm.MaximizeBox = $False
	$objForm.WindowState = "Normal"
	$objForm.SizeGripStyle = "Hide"
	$objForm.Opacity = 0.8

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
	$objStatusBar.Text = "[00%] Поиск всех доступных компьютеров в доменной сети..."
	$objForm.Controls.Add($objStatusBar)

	$objTimer_OnTick = {$objProgressBar.PerformStep()}

	$objTimer = New-Object System.Windows.Forms.Timer
	$objTimer.Add_Tick($objTimer_OnTick)
	$objTimer.Interval = 100
	$objTimer.Start()

	$objForm.Show() | Out-Null

	$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
	$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($LDAP)
	$objSearcher.PageSize = 1000
	$objSearcher.Filter = "(&(objectCategory=computer)(objectClass=computer))"
	$objSearcher.SearchScope = "Subtree"
	$colProplist = "objectSid", "sAMAccountName", "cn", "dNSHostName", "name", "description", "operatingSystem", "operatingSystemVersion", "company", "l"
	Foreach ($i in $colPropList) {$objSearcher.PropertiesToLoad.Add($i) | out-null}
	Remove-Variable -Name i -ErrorAction SilentlyContinue
	Remove-Variable -Name colPropList -ErrorAction SilentlyContinue
	$colResults = $objSearcher.FindAll()
	Remove-Variable -Name objSearcher -ErrorAction SilentlyContinue

	$ComputerList = @()
	$ID = 1
	$CounterCurrent = 0
	$CounterTotal = ($colResults | Measure-Object).Count

	Write-Log $LogFullFileName "[INFO]	Запуск тестирования доступности компьютеров..."
	ForEach ($Computer in $colResults) {
		$CounterCurrent = $CounterCurrent + 1
		$objProgressBar.Value = (100 / $CounterTotal) * $CounterCurrent
		$objStatusBar.Text = "[" + $CounterCurrent + " / " + $CounterTotal + "] Проверка доступности компьютера """ + $Computer.Properties["cn"] + """ (" + $Computer.Properties["operatingSystem"] + " [" + $Computer.Properties["operatingSystemVersion"] + "])"
		If (
			($Computer.Properties["operatingSystem"] -ne "") -and 
			($Computer.Properties["operatingSystem"] -ne "unknown") -and
			(-not ($Computer.Properties["operatingSystem"] -match "server"))
		) {
# !!!!!!!!!!!!!!!!!!!
#			If (Test-Connection -ComputerName $Computer.Properties["cn"] -Count 1 -ErrorAction SilentlyContinue -Quiet) {
				$objStatusBar.Text = "[" + $CounterCurrent + " / " + $CounterTotal + "] Проверка компьютера """ + $Computer.Properties["cn"] + """ (" + $Computer.Properties["operatingSystem"] + " [" + $Computer.Properties["operatingSystemVersion"] + "]): в сети (доступен)"
				Write-Log $LogFullFileName ("[RESULT]	[" + $CounterCurrent + " / " + $CounterTotal + "] Проверка компьютера """ + $Computer.Properties["cn"] + """ (" + $Computer.Properties["operatingSystem"] + " [" + $Computer.Properties["operatingSystemVersion"] + "]): в сети (доступен)")
				$ComputerStatus = "Online"
# !!!!!!!!!!!!!!!!!!!
#			} Else {
#				$objStatusBar.Text = "[" + $CounterCurrent + " / " + $CounterTotal + "] Проверка компьютера """ + $Computer.Properties["cn"] + """ (" + $Computer.Properties["operatingSystem"] + " [" + $Computer.Properties["operatingSystemVersion"] + "]): не в сети (отключен)"
#				Write-Log $LogFullFileName ("[RESULT]	[" + $CounterCurrent + " / " + $CounterTotal + "] Проверка компьютера """ + $Computer.Properties["cn"] + """ (" + $Computer.Properties["operatingSystem"] + " [" + $Computer.Properties["operatingSystemVersion"] + "]): не в сети (отключен)")
#				$ComputerStatus = "Offline"
#			}
			If ($ID -lt 100) {
				If ($ID -lt 10) {
					$ComputerID = "00" + $ID
				} Else {
					$ComputerID = "0" + $ID
				}
			} Else {
				$ComputerID = $ID
			}
			$CurrentComputer = New-Object -TypeName PSObject -Property @{
				ID = $ComputerID -as [string]
				Name = $Computer.Properties["cn"] -as [string]
				DNSName = $Computer.Properties["dNSHostName"] -as [string]
				Description = $Computer.Properties["description"] -as [string]
				Status = $ComputerStatus -as [string]
				SID = ((New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList @($Computer.Properties["objectSid"][0],0)).Value).ToString() -as [string]
			}
			$ID = $ID + 1
			$ComputerList += , $CurrentComputer
			Remove-Variable -Name ComputerID -ErrorAction SilentlyContinue
			Remove-Variable -Name ComputerStatus -ErrorAction SilentlyContinue
			Remove-Variable -Name CurrentComputer -ErrorAction SilentlyContinue
		} Else {
			If (($Computer.Properties["operatingSystem"] -ne "") -and ($Computer.Properties["operatingSystem"] -ne "unknown")) {
				$MessageTextTemp = " (" + $Computer.Properties["operatingSystem"]
				If (($Computer.Properties["operatingSystemVersion"] -ne "") -and ($Computer.Properties["operatingSystemVersion"] -ne "unknown")) {
					$MessageTextTemp += " [" + $Computer.Properties["operatingSystemVersion"] + "])"
				} Else {
					$MessageTextTemp += ")"
				}
			}
			Write-Log $LogFullFileName ("[RESULT]	[" + $CounterCurrent + " / " + $CounterTotal + "] Компьютер """ + $Computer.Properties["cn"] + """" + $MessageTextTemp + " не является стандартной рабочей станцией")
			Remove-Variable -Name MessageTextTemp -ErrorAction SilentlyContinue
		}
	}
	Remove-Variable -Name CounterTotal -ErrorAction SilentlyContinue
	Remove-Variable -Name CounterCurrent -ErrorAction SilentlyContinue
	Remove-Variable -Name ID -ErrorAction SilentlyContinue
	Remove-Variable -Name colResults -ErrorAction SilentlyContinue

	$objTimer.Stop()
	Remove-Variable -Name objTimer -ErrorAction SilentlyContinue

	$objForm.Close()
	Remove-Variable -Name objProgressBar -ErrorAction SilentlyContinue
	Remove-Variable -Name objStatusBar -ErrorAction SilentlyContinue
	Remove-Variable -Name objForm -ErrorAction SilentlyContinue

	Return $ComputerList
#	Remove-Variable -Name ComputerList -ErrorAction SilentlyContinue
}

Function Computer_Dialog ($LogFullFileName, $ComputerList) {
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | Out-Null
#Build the GUI
	[xml]$Computer_Dialog_XAML = @"
		<Window
			xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
			xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
			xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
			xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
			x:Name="Window" Title="Удаление профилей пользователей: выбор компьютеров"
			Width="1000" Height="500" ShowInTaskbar="True" Background="LightGray" WindowStartupLocation="CenterScreen">
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
							<Setter Property="IsEnabled" Value="False"/>
							<Setter Property="Focusable" Value="True"/>
							<Setter Property="IsHitTestVisible" Value="{Binding RelativeSource={RelativeSource Self}, Path=IsEnabled}"/>
							<Setter Property="HorizontalContentAlignment" Value="Center"/>
							<Style.Triggers>
								<Trigger Property="ItemsControl.AlternationIndex" Value="1">
									<Setter Property="Background" Value="White"/>
									<Setter Property="Foreground" Value="Black"/>
								</Trigger>
								<DataTrigger Binding="{Binding Path=Status}" Value="Online">
									<Setter Property="IsEnabled" Value="True"/>
								</DataTrigger>
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
								<Run FontWeight="Bold" FontSize="12" Text="Выберите компьютер(ы) для сканирования:"/>
								<LineBreak />
							</TextBlock.Inlines>
						</TextBlock>
						<ListView Name="ListView" Width="970" Height="370" Margin="0,40,0,0" HorizontalAlignment="Center" VerticalAlignment="Top" AlternationCount="2" ItemContainerStyle="{StaticResource ListViewStyle}">
							<ListView.View>
								<GridView>
									<GridViewColumn Width="30">
										<GridViewColumn.CellTemplate>
											<DataTemplate>
												<CheckBox HorizontalAlignment="Center" VerticalAlignment="Center" Tag="{Binding Path=Checkbox}" IsChecked="{Binding RelativeSource={RelativeSource AncestorType={x:Type ListViewItem}}, Path=IsSelected}"/>
											</DataTemplate>
										</GridViewColumn.CellTemplate>
									</GridViewColumn>
									<GridViewColumn Width="75" x:Name="IDColumn" DisplayMemberBinding="{Binding Path=ID}"><GridViewColumnHeader x:Name="IDHeader">ID</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="75" x:Name="NameColumn" DisplayMemberBinding="{Binding Path=Name}"><GridViewColumnHeader x:Name="NameHeader">Name</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="160" x:Name="DNSNameColumn" DisplayMemberBinding="{Binding Path=DNSName}"><GridViewColumnHeader x:Name="DNSNameHeader">DNSName</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="225" x:Name="DescriptionColumn" DisplayMemberBinding="{Binding Path=Description}"><GridViewColumnHeader x:Name="DescriptionHeader">Description</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="75" x:Name="StatusColumn" DisplayMemberBinding="{Binding Path=Status}"><GridViewColumnHeader x:Name="StatusHeader">Status</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="300" x:Name="SIDColumn" DisplayMemberBinding="{Binding Path=SID}"><GridViewColumnHeader x:Name="SIDHeader">SID</GridViewColumnHeader></GridViewColumn>
								</GridView>
							</ListView.View>
						</ListView>
						<CheckBox x:Name="SelectAll" Content="Выделить (снять выделение) всех" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="10,400,0,0" IsChecked="False"/>
						<Button x:Name="OK" Content="OK" Width="75" Height="23" Margin="-130,430,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
						<Button x:Name="Cancel" Content="Cancel" Width="75" Height="23" Margin="130,430,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
					</Grid>
				</StackPanel>
			</ScrollViewer>
		</Window>
"@
	Try {
		$Window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $Computer_Dialog_XAML) )
	} Catch {
		$XAML_Problem = $True
	}

	If ($XAML_Problem) {
		Write-Log $LogFullFileName "[ERROR]		Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered."
		Return @()
	} Else {
		$ListView = $Window.FindName('ListView')
		$CheckboxSelectAll = $Window.FindName('SelectAll')
		$ButtonOK = $Window.FindName('OK')
		$ButtonCancel = $Window.FindName('Cancel')

		ForEach ($Computer In $ComputerList) {
			ForEach ($ComputerData In $Computer) {
				$ListViewItem = New-Object PSObject
				Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "ID" -Value $ComputerData.ID
				Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "Name" -Value $ComputerData.Name
				Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "DNSName" -Value $ComputerData.DNSName
				Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "Description" -Value $ComputerData.Description
				Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "Status" -Value $ComputerData.Status
				Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "SID" -Value $ComputerData.SID
				$ListView.Items.Add($ListViewItem)
				Remove-Variable -Name ListViewItem -ErrorAction SilentlyContinue
			}
		}

		$script:ColumnHeaders = @{"ID"=""; "Name"=""; "DNSName"=""; "Description" = ""; "Status" = ""; "SID" = ""}
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
#					$ColumnHeader.Column.SortMode = "Automatic"
					$Listview.Items.Refresh()
					$script:ColumnHeaders[$ColumnHeaderName] = "ascending"
				}
			})
		}

		$ListView.Add_SelectionChanged({
			If ($ListView.SelectedItems.Count -gt 0) {
# Remove "passive" from selected:
				$SelectedItemsRemove = @()
				If ($ListView.SelectedItems.Count -gt 1) {
					ForEach ($SelectedItem In $ListView.SelectedItems) {
						If ($SelectedItem.Status -eq "Offline") {
							$SelectedItemsRemove += , $SelectedItem
						}
					}
				} Else {
					If ($ListView.SelectedItem.Status -eq "Offline") {
						$SelectedItemsRemove += , $ListView.SelectedItem
					}
				}
				ForEach ($SelectedItem In $SelectedItemsRemove) {
					$ListView.SelectedItems.Remove($SelectedItem)
				}
				Remove-Variable -Name SelectedItem -ErrorAction SilentlyContinue
				Remove-Variable -Name SelectedItemsRemove -ErrorAction SilentlyContinue
# Check if all "active" are selected:
				$FlagAllSelected = "yes"
				ForEach ($CurrentItem In $ListView.Items) {
					If ($CurrentItem.Status -ne "Offline") {
						$FlagItemChecked = "no"
						If ($ListView.SelectedItems.Count -gt 1) {
							ForEach ($SelectedItem In $ListView.SelectedItems) {
								If ($CurrentItem.ID -eq $SelectedItem.ID) {
									$FlagItemChecked = "yes"
								}
							}
							Remove-Variable -Name SelectedItem -ErrorAction SilentlyContinue
						} Else {
							If ($CurrentItem.ID -eq $ListView.SelectedItem.ID) {
								$FlagItemChecked = "yes"
							}
						}
						If (($FlagItemChecked -eq "yes") -and ($FlagAllSelected -eq "yes")) {
							$FlagAllSelected = "yes"
						} Else {
							$FlagAllSelected = "no"
						}
						Remove-Variable -Name FlagItemChecked -ErrorAction SilentlyContinue
					}
				}
				Remove-Variable -Name CurrentItem -ErrorAction SilentlyContinue
# Save selection if not all selected:
				If ($FlagAllSelected -eq "yes") {
					$script:SavedSelectedItems = @()
					$CheckboxSelectAll.IsChecked = $True
				} Else {
					$SelectedItems = @()
					If ($ListView.SelectedItems.Count -gt 1) {
						ForEach ($SelectedItem In $ListView.SelectedItems) {
							$SelectedItems += , $SelectedItem
						}
						Remove-Variable -Name SelectedItem -ErrorAction SilentlyContinue
					} Else {
						$SelectedItems += , $ListView.SelectedItem
					}
					$script:SavedSelectedItems = $SelectedItems
					Remove-Variable -Name SelectedItems -ErrorAction SilentlyContinue
					$CheckboxSelectAll.IsChecked = $False
				}
			} Else {
				$script:SavedSelectedItems = @()
				$CheckboxSelectAll.IsChecked = $False
			}
		})

		$CheckboxSelectAll.Add_Click({
# Checked "CheckboxSelectAll"
			If ($CheckboxSelectAll.IsChecked -eq $True) {
#				[System.Windows.Forms.MessageBox]::Show(("Выбрать всех - да"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
				ForEach ($CurrentItem In $ListView.Items) {
					If ($CurrentItem.Status -ne "Offline") {
						$FlagItemAdd = "yes"
						If ($ListView.SelectedItems.Count -gt 0) {
							If ($ListView.SelectedItems.Count -gt 1) {
								ForEach ($SelectedItem In $ListView.SelectedItems) {
									If ($CurrentItem.ID -eq $SelectedItem.ID) {
										$FlagItemAdd = "no"
									}
								}
							} Else {
								If ($CurrentItem.ID -eq $ListView.SelectedItem.ID) {
									$FlagItemAdd = "no"
								}
							}
						}
						If ($FlagItemAdd -eq "yes") {
							$SelectedItems += , $CurrentItem
						}
						Remove-Variable -Name FlagItemAdd -ErrorAction SilentlyContinue
					}
				}
				If ($SelectedItems.Count -gt 0) {
					ForEach ($CurrentItem In $SelectedItems) {
						$ListView.SelectedItems.Add($CurrentItem)
					}
				}
				Remove-Variable -Name SelectedItems -ErrorAction SilentlyContinue
			}
# UnChecked "CheckboxSelectAll"
			If ($CheckboxSelectAll.IsChecked -eq $False) {
#				[System.Windows.Forms.MessageBox]::Show(("Выбрать всех - нет"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
				$ListView.UnselectAll()
				If ($FlagManualSelection -eq $False) {
					$SavedSelectedItems = $script:SavedSelectedItems
					If ($SavedSelectedItems.Count -gt 0) {
						ForEach ($CurrentItem In $SavedSelectedItems) {
							$ListView.SelectedItems.Add($CurrentItem)
						}
					}
					$script:SavedSelectedItems = @()
					Remove-Variable -Name SavedSelectedItems -ErrorAction SilentlyContinue
				}
			}
		})
		$ButtonOK.Add_Click({
			If ($ListView.SelectedItems.Count -gt 0) {
				$script:objComputerList = New-Object -TypeName PSCustomObject
				$ComputerList = @()
#				[System.Windows.Forms.MessageBox]::Show(("Всего выбрано: " + $ListView.SelectedItems.Count), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
				If ($ListView.SelectedItems.Count -gt 1) {
					ForEach ($CurrentItem In $ListView.SelectedItems) {
#						[System.Windows.Forms.MessageBox]::Show(("Выбрана позиция: " + $CurrentItem.ID + " (" + $CurrentItem.ComputerName + ")"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
						$SelectedComputer = New-Object -TypeName PSObject -Property @{
							ID = $CurrentItem.ID -as [string]
							Name = $CurrentItem.Name -as [string]
							DNSName = $CurrentItem.DNSName -as [string]
							Description = $CurrentItem.Description -as [string]
							Status = $CurrentItem.Status -as [string]
							SID = $CurrentItem.SID -as [string]
						}
						$ComputerList += , $SelectedComputer
						Remove-Variable -Name SelectedComputer -ErrorAction SilentlyContinue
					}
				} Else {
#					[System.Windows.Forms.MessageBox]::Show(("Выбрана позиция: " + $ListView.SelectedItem.ID + " (" + $ListView.SelectedItem.ComputerName + ")"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
					$ComputerList += $ListView.SelectedItem
				}
				Add-Member -InputObject $script:objComputerList -MemberType NoteProperty -Name "Selection" -Value $ComputerList
				Remove-Variable -Name ComputerList -ErrorAction SilentlyContinue
				$Window.Close()
			} Else {
				[System.Windows.Forms.MessageBox]::Show(("Не выбрано ни одной позиции"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
			}
		})
		$ButtonCancel.Add_Click({
			$Window.Close()
		})
 
		$Window.ShowDialog() | Out-Null

		Remove-Variable -Name SavedSelectedItems -Scope Script -ErrorAction SilentlyContinue
		Remove-Variable -Name ColumnHeaders -Scope Script -ErrorAction SilentlyContinue
		$ComputerList = $script:objComputerList
		Remove-Variable -Name objComputerList -Scope Script -ErrorAction SilentlyContinue
		If (($ComputerList | Measure-Object).Count -gt 0) {
			Return $ComputerList
		} Else {
			Return @()
		}
	}
}

Function Get_Credential ($Login, $Password, $LogFullFileName) {
	If (($Login -ne "") -and ($Login -ne $null) -and ($Password -ne "") -and ($Password -ne $null)) {
		$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Login, (ConvertTo-SecureString $Password -AsPlainText -Force)
	} Else {
		If (($Login -ne "") -and ($Login -ne $null)) {
#			Write-Log $LogFullFileName ("[ERROR]		Не задано значение ""Password"" в конфигурации!")
			$Credential = Get-Credential -Credential $Login
		} Else {
			Write-Log $LogFullFileName ("[ERROR]		Не задано значение ""Login"" в конфигурации!")
			$Credential = $null
		}
	}
	Return $Credential
}

Function Profile_Search ($LDAP, $LogFullFileName, $Credential, $ComputerList) {

	$objDomain = New-Object System.DirectoryServices.DirectoryEntry($LDAP)
	$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
	$objSearcher.SearchRoot = $objDomain
	$objSearcher.PageSize = 1000
	$objSearcher.Filter = "(&(objectCategory=user)(company=*)(l=*))"
#	$objSearcher.Filter = "(&(objectCategory=user)(company=ООО " + [char]171 + "Габел Девелопмент" + [char]187 + ")(l=Санкт-Петербург))"
#	$objSearcher.Filter = "(&(objectCategory=user)(company=ООО " + [char]171 + "Петра-8" + [char]187 + ")(l=Москва))"
	$objSearcher.SearchScope = "Subtree"
	$colProplist = "objectSid", "objectGUID", "sAMAccountName", "displayName", "description", "company", "l"
	Foreach ($i in $colPropList) {$objSearcher.PropertiesToLoad.Add($i) | out-null}
	$colResults = $objSearcher.FindAll()

	$ComputerList = $ComputerList.Selection

	$ProfileList = @()
	$ID = 1

	ForEach ($Computer in $ComputerList) {
		$ComputerName	= $Computer.Name
		If (Test-Connection -ComputerName $ComputerName -Count 1 -ErrorAction SilentlyContinue -Quiet) {
			Write-Log $LogFullFileName ("[INFO]		Обработка данных по компьютеру: " + $ComputerName)
			$ADDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
			$ADRoot = $ADDomain.GetDirectoryEntry()
			$ADSearcher = [System.DirectoryServices.DirectorySearcher] $ADRoot
			$ADSearcher.Filter = "(sAMAccountName=" + $ComputerName + "`$)"
			$ADSearcher.PropertiesToLoad.Add("description") | out-null
			$ADResults = $ADSearcher.FindAll()
			ForEach ($ADComputer In $ADResults) {
				$ComputerDescriptionAD = $ADComputer.Properties.Item("description")
			}
			Remove-Variable -Name ADResults -ErrorAction SilentlyContinue
			Remove-Variable -Name ADSearcher -ErrorAction SilentlyContinue
			Remove-Variable -Name ADRoot -ErrorAction SilentlyContinue
			Remove-Variable -Name ADDomain -ErrorAction SilentlyContinue

#			$ComputerDescriptionAD		= (Get-ADComputer -LDAPFilter ("(name=" + $ComputerName + ")") -SearchBase "dc=domain,dc=com" -Properties description).Description
			If ($ComputerDescriptionAD) {
				Write-Log $LogFullFileName ("[RESULT]	Найдено описание компьютера """ + $ComputerName + """ в Active Directory: " + $ComputerDescriptionAD)
			}
			$ComputerDescriptionLOCAL	= (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName).Description
			If ($ComputerDescriptionLOCAL) {
				Write-Log $LogFullFileName ("[RESULT]	Найдено описание компьютера """ + $ComputerName + """ в настройках самого ПК: " + $ComputerDescriptionLOCAL)
			}
			If (($ComputerDescriptionAD) -and ($ComputerDescriptionLOCAL) -and ($ComputerDescriptionAD -eq $ComputerDescriptionLOCAL)) {
				Write-Log $LogFullFileName ("[INFO]	Совпадение описания компьютера """ + $ComputerName + """ в настройках самого ПК (" + $ComputerDescriptionLOCAL + ") и Active Directory (" + $ComputerDescriptionAD + ")")
				$ComputerDescription = $ComputerDescriptionLOCAL
				$ComputerSystemDrive = Get-ChildItem "Env:SystemDrive"
# Reading from registry and transforming to valid path:
#				Try {
#					$RemoteRegistry = New-Object -TypeName System.Management.ManagementClass -ArgumentList ("\\" + $ComputerName + "\Root\default:StdRegProv")
#				} Catch {
#					Write-Warning $_.exception.message
#					$RemoteRegistryProblem = $true
#				}
#				If (-not ($RemoteRegistryProblem)) {
#               	                 If (($RemoteRegistry.GetStringValue($HKLM, "SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList", "ProfilesDirectory")).ReturnValue -ne 0) {Throw "Failed to get registry value"}
#				} Else {
#					Remove-Variable -Name RemoteRegistryProblem -ErrorAction SilentlyContinue
#				}
				$ComputerRegistryProfilesDirectory = Invoke-Command -ScriptBlock {Return (((Get-ItemProperty -Path ("HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList") -Name "ProfilesDirectory").ProfilesDirectory) -Replace "`%SystemDrive`%", $ComputerSystemDrive)} -ComputerName $ComputerName -Credential $Credential
				$ComputerRegistryDefault = Invoke-Command -ScriptBlock {Return (((Get-ItemProperty -Path ("HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList") -Name "Default").Default) -Replace "`%SystemDrive`%", $ComputerSystemDrive)} -ComputerName $ComputerName -Credential $Credential
				$ComputerRegistryPublic = Invoke-Command -ScriptBlock {Return (((Get-ItemProperty -Path ("HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList") -Name "Public").Public) -Replace "`%SystemDrive`%", $ComputerSystemDrive)} -ComputerName $ComputerName -Credential $Credential
# Reading profiles directory:
				$ComputerProfilesDirectories = Invoke-Command -ScriptBlock {
					param ($ComputerRegistryProfilesDirectory)
					$ComputerProfilesDirectories = (Get-ChildItem $ComputerRegistryProfilesDirectory | WHERE {$_.Attributes -eq "Directory"})
					Return $ComputerProfilesDirectories
				} -ArgumentList $ComputerRegistryProfilesDirectory -ComputerName $ComputerName -Credential $Credential
					Write-Log $LogFullFileName ("[RESULT]	Найдено " + (($ComputerProfilesDirectories | Measure-Object).Count) + " дополнительн(ая/ых) папк(а/и)")
					Write-Log $LogFullFileName ""
				Foreach ($CurrentComputerProfilesDirectory in $ComputerProfilesDirectories) {
# If it is not a "Public" or "Default" folder:
					If (($CurrentComputerProfilesDirectory -ne $ComputerRegistryDefault) -and ($CurrentComputerProfilesDirectory -ne $ComputerRegistryPublic)) {
						$FlagProfileFound = "no"
# Searching a same profile folder in a registry:
						Write-Log $LogFullFileName ("[INFO]	Обработка текущей папки: " + ($ComputerRegistryProfilesDirectory + "\" + $CurrentComputerProfilesDirectory))
						Get-WmiObject -Class Win32_UserProfile -ComputerName $ComputerName | Where-Object -FilterScript {$_.SID -Like "S-1-5-21-*"} | Foreach-Object {
							$CurrentComputerProfileImagePath = Invoke-Command -ScriptBlock {
								param ($SID)
								Return ((Get-ItemProperty -Path ("HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\" + $SID) -Name "ProfileImagePath").ProfileImagePath)
							} -ArgumentList $_.SID -ComputerName $ComputerName -Credential $Credential
							Write-Log $LogFullFileName ("[INFO]	Проверяем профиль по данным из реестра: " + $CurrentComputerProfileImagePath)
# If we found a coorect SID, reading info:
							If (($ComputerRegistryProfilesDirectory + "\" + $CurrentComputerProfilesDirectory) -eq $CurrentComputerProfileImagePath) {
								Write-Log $LogFullFileName ("[RESULT]	Найдено совпадение SID """ + $_.SID + """ для папки: " + $CurrentComputerProfilesDirectory)
# Searching in AD:
#								Write-Log $LogFullFileName ("[INFO]	Поиск в " + (($colResults | Measure-Object ).Count) + " пользователях из базы объектов Active Directory...")
								Foreach ($objResult in $colResults) {
#									Write-Log $LogFullFileName ("[INFO]	Текущая позиция: " + $objItem.description + " | " + $ComputerDescription)
									$objItem = $objResult.Properties
									If ($FlagProfileFound -eq "no") {
#									If ($objItem.description -eq $ComputerDescription) {
#										Write-Log $LogFullFileName ("[RESULT]	Совпадение описания компьютера """ + $ComputerName + """ (" + $ComputerDescription + ") и пользователя (" + $objItem["description"] + ") из базы объектов Active Directory: " + $objItem["sAMAccountName"] + " (" + $objItem["displayName"] + ")")
										[string]$objectSid	= ((New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList @($objResult.Properties["objectSid"][0],0)).Value).ToString()
										If ($objectSid -eq $_.SID) {
										Write-Log $LogFullFileName ("[RESULT]	Совпадение SID пользователя ПК из базы объектов Active Directory: " + $objectSid)
											[string]$objectGUID	= (New-Object -TypeName System.Guid -ArgumentList @(,($objItem["objectGUID"][0]))).ToString()
											[string]$sAMAccountName	= $objItem["sAMAccountName"]
											[string]$displayName	= $objItem["displayName"]
											[string]$description	= $objItem["description"]
											[string]$company	= $objItem["company"]
											[string]$l		= $objItem["l"]
# Get current profile local GUID from Registry
											$CurrentComputerRegistryProfileGUID = Invoke-Command -ScriptBlock {
												param ($SID)
												Return ((Get-ItemProperty -Path ("HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\" + $SID) -Name "Guid").Guid)
											} -ArgumentList $_.SID -ComputerName $ComputerName -Credential $Credential
											If (("{" + $objectGUID + "}") -eq $CurrentComputerRegistryProfileGUID) {
												Write-Log $LogFullFileName ("[RESULT]	Совпадение GUID пользователя ПК из базы объектов Active Directory: " + $objectGUID)
												$userAccount = [WMI] ("\\$ComputerName\root\cimv2:Win32_SID.SID='{0}'" -f $_.SID)
												$CurrentProfile = New-Object PSObject
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ID" -Value $ID
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ComputerName" -Value $ComputerName
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ComputerDescription" -Value $ComputerDescription
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "LocalPath" -Value $_.LocalPath
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "UserName" -Value ("{0}\{1}" -f $userAccount.ReferencedDomainName,$userAccount.AccountName)
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "UserDescription" -Value $description
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "LastUseTime" -Value $_.LastUseTime
#												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "LastUseTime" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($_.LastUseTime))
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "Loaded" -Value $_.Loaded
												Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "SID" -Value $_.SID
												$ID = $ID + 1

												$ProfileList += , $CurrentProfile
												Write-Log $LogFullFileName ("[RESULT]	Дабавлены в массив полные данные по папке `"" + ($ComputerRegistryProfilesDirectory + "\" + $CurrentComputerProfilesDirectory) + "`" (данные с реестра компьютера и Active Directory): " + $CurrentProfile)
												Remove-Variable -Name CurrentProfile -ErrorAction SilentlyContinue
												$FlagProfileFound = "yes"
											}
											Remove-Variable -Name objectGUID -ErrorAction SilentlyContinue
											Remove-Variable -Name sAMAccountName -ErrorAction SilentlyContinue
											Remove-Variable -Name displayName -ErrorAction SilentlyContinue
											Remove-Variable -Name description -ErrorAction SilentlyContinue
											Remove-Variable -Name company -ErrorAction SilentlyContinue
											Remove-Variable -Name l -ErrorAction SilentlyContinue
										}
										Remove-Variable -Name objectSid -ErrorAction SilentlyContinue
									}
								}
# USER NOT FOUND IN AD (no match with user & computer decription):
								If ($FlagProfileFound -eq "no") {
									$userAccount = [WMI] ("\\$ComputerName\root\cimv2:Win32_SID.SID='{0}'" -f $_.SID)
									$CurrentProfile = New-Object PSObject
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ID" -Value $ID
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ComputerName" -Value $ComputerName
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ComputerDescription" -Value $ComputerDescription
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "LocalPath" -Value $_.LocalPath
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "UserName" -Value ("{0}\{1}" -f $userAccount.ReferencedDomainName,$userAccount.AccountName)
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "UserDescription" -Value $description
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "LastUseTime" -Value $_.LastUseTime
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "Loaded" -Value $_.Loaded
									Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "SID" -Value $_.SID
									$ID = $ID + 1

									$ProfileList += , $CurrentProfile
									Write-Log $LogFullFileName ("[RESULT]	Дабавлены в массив частичные данные по папке `"" + ($ComputerRegistryProfilesDirectory + "\" + $CurrentComputerProfilesDirectory) + "`" (только информация с реестра компьютера, в Active Directory профиль не найден): " + $CurrentProfile)
									Remove-Variable -Name CurrentProfile -ErrorAction SilentlyContinue

									$FlagProfileFound = "yes"
								}
							}
						}
# NOT FOUND IN REGISTRY information about current profile folder:
						If ($FlagProfileFound -eq "no") {
							$CurrentProfile = New-Object PSObject
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ID" -Value $ID
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ComputerName" -Value $ComputerName
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "ComputerDescription" -Value $ComputerDescription
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "LocalPath" -Value ($ComputerRegistryProfilesDirectory + "\" + $CurrentComputerProfilesDirectory)
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "UserName" -Value ""
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "UserDescription" -Value ""
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "LastUseTime" -Value ""
#							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "LastUseTime" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($_.LastUseTime))
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "Loaded" -Value $False
							Add-Member -InputObject $CurrentProfile -MemberType NoteProperty -Name "SID" -Value ""
							$ID = $ID + 1
							$ProfileList += , $CurrentProfile
							Write-Log $LogFullFileName ("[RESULT]	Дабавлены в массив данные только по папке `"" + ($ComputerRegistryProfilesDirectory + "\" + $CurrentComputerProfilesDirectory) + "`" (информация в реестре компьютера и Active Directory не найдена): " + $CurrentProfile)
							Remove-Variable -Name CurrentProfile -ErrorAction SilentlyContinue

							$FlagProfileFound = "yes"
						}
						Remove-Variable -Name FlagProfileFound -ErrorAction SilentlyContinue
						Write-Log $LogFullFileName ""
					}
				}
			}
			Remove-Variable -Name ComputerDescriptionLOCAL -ErrorAction SilentlyContinue
			Remove-Variable -Name ComputerDescriptionAD -ErrorAction SilentlyContinue
		} Else {
			Write-Log $LogFullFileName ("[INFO]	Компьютер """ + $Computer + """ отключен, поиск профилей по нему невозможен.")
		}

# Use WMI to find all users with a profile on the servers 
#	Try {
#		[array]$users = Get-WmiObject -ComputerName $computer Win32_UserProfile -Filter "LocalPath Like 'C:\\Users\\%'" -ea stop
#	}
#	Catch {
#		Write-Warning "$($error[0]) "
#		Break
#	}
# Compile the profile list and remove the path prefix leaving just the usernames 
#	$profilelist = $profilelist + $users.localpath -replace "C:\\users\\"
# Filter the user names to show only unique values left to prevent duplicates from profile existing on multiple computers 
#	$uniqueusers = $ProfileList | Select-Object -Unique | Sort-Object
	}

	Remove-Variable -Name ComputerList -ErrorAction SilentlyContinue
	Remove-Variable -Name Computer -ErrorAction SilentlyContinue
	Remove-Variable -Name ComputerName -ErrorAction SilentlyContinue
	Remove-Variable -Name ID -ErrorAction SilentlyContinue
#	Write-Host ("Финальный массив: ")
#	Write-Host ($ProfileList)
	Return $ProfileList
#	Remove-Variable -Name ProfileList -ErrorAction SilentlyContinue
}

Function Profile_Dialog ($LogFullFileName, $ProfileList) {
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | Out-Null
#Build the GUI
	[xml]$Profile_Dialog_XAML = @"
		<Window
			xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
			xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
			xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
			xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
			x:Name="Window" Title="Удаление профилей пользователей: выбор профилей" WindowStartupLocation="CenterScreen"
			Width="1470" Height="500" ShowInTaskbar="True" Background="LightGray">
			<ScrollViewer VerticalScrollBarVisibility="Auto">
				<StackPanel>
					<StackPanel.Resources>
						<Style x:Key="ListViewStyle" TargetType="{x:Type Control}">
							<Setter Property="Background" Value="LightGray"/>
							<Setter Property="Foreground" Value="Black"/>
							<Setter Property="IsEnabled" Value="False"/>
							<Setter Property="Focusable" Value="True"/>
							<Setter Property="IsHitTestVisible" Value="{Binding RelativeSource={RelativeSource Self}, Path=IsEnabled}"/>
							<Style.Triggers>
								<Trigger Property="ItemsControl.AlternationIndex" Value="1">
									<Setter Property="Background" Value="White"/>
									<Setter Property="Foreground" Value="Black"/>
								</Trigger>
								<DataTrigger Binding="{Binding Path=Loaded}" Value="False">
									<Setter Property="IsEnabled" Value="True"/>
								</DataTrigger>
							</Style.Triggers>
						</Style>
						<Style TargetType="{x:Type GridViewColumnHeader}">
							<Setter Property="HorizontalContentAlignment" Value="Center"/>
							<Setter Property="Background" Value="Transparent"/>
							<Setter Property="Foreground" Value="Black"/>
							<Setter Property="BorderBrush" Value="Transparent"/>
							<Setter Property="FontWeight" Value="Bold"/>
						</Style>
					</StackPanel.Resources>
					<Grid Margin="0,0,0,0">
						<TextBlock x:Name="TextBlock" Width="230" Height="23" Margin="10,10,10,10" HorizontalAlignment="Left" VerticalAlignment="Top" TextWrapping="Wrap">
							<TextBlock.Inlines>
								<Run FontWeight="Bold" FontSize="12" Text="Выберите профил(ь/и) для удаления:"/>
								<LineBreak />
							</TextBlock.Inlines>
						</TextBlock>
						<ListView Name="ListView" Width="1440" Height="330" Margin="0,40,0,0" HorizontalAlignment="Center" VerticalAlignment="Top" AlternationCount="2" ItemContainerStyle="{StaticResource ListViewStyle}">
							<ListView.View>
								<GridView>
									<GridViewColumn Width="30">
										<GridViewColumn.CellTemplate>
											<DataTemplate>
												<CheckBox HorizontalAlignment="Center" VerticalAlignment="Center" Tag="{Binding Path=Checkbox}" IsChecked="{Binding RelativeSource={RelativeSource AncestorType={x:Type ListViewItem}}, Path=IsSelected}"/>
											</DataTemplate>
										</GridViewColumn.CellTemplate>
									</GridViewColumn>
									<GridViewColumn Width="30" x:Name="IDColumn" DisplayMemberBinding="{Binding Path=ID}"><GridViewColumnHeader x:Name="IDHeader">ID</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="100" x:Name="ComputerNameColumn" DisplayMemberBinding="{Binding Path=ComputerName}"><GridViewColumnHeader x:Name="ComputerNameHeader">Computer Name</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="200" x:Name="ComputerDescriptionColumn" DisplayMemberBinding="{Binding Path=ComputerDescription}"><GridViewColumnHeader x:Name="ComputerDescriptionHeader">Computer Description</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="180" x:Name="LocalPathColumn" DisplayMemberBinding="{Binding Path=LocalPath}"><GridViewColumnHeader x:Name="LocalPathHeader">Local Path</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="200" x:Name="UserNameColumn" DisplayMemberBinding="{Binding Path=UserName}"><GridViewColumnHeader x:Name="UserNameHeader">User Name</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="200" x:Name="UserDescriptionColumn" DisplayMemberBinding="{Binding Path=UserDescription}"><GridViewColumnHeader x:Name="UserDescriptionHeader">User Description</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="140" x:Name="LastUseTimeColumn" DisplayMemberBinding="{Binding Path=LastUseTime}"><GridViewColumnHeader x:Name="LastUseTimeHeader">Last Use Time</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="50" x:Name="LoadedColumn" DisplayMemberBinding="{Binding Path=Loaded}"><GridViewColumnHeader x:Name="LoadedHeader">Loaded</GridViewColumnHeader></GridViewColumn>
									<GridViewColumn Width="300" x:Name="SIDColumn" DisplayMemberBinding="{Binding Path=SID}"><GridViewColumnHeader x:Name="SIDHeader">SID</GridViewColumnHeader></GridViewColumn>
								</GridView>
							</ListView.View>
						</ListView>
						<CheckBox x:Name="SelectAll" Content="Выделить (снять выделение) всех" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="10,330,0,0" IsChecked="False"/>
						<CheckBox x:Name="BackupFolders" Content="Создать архивную копию папки удаляемого профиля" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="10,370,0,0" IsChecked="False"/>
						<CheckBox x:Name="RemoveFolders" Content="Принудительно очистить папку удаляемого профиля" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="10,410,0,0" IsChecked="False"/>
						<Button x:Name="OK" Content="OK" Width="75" Height="23" Margin="-130,430,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
						<Button x:Name="Cancel" Content="Cancel" Width="75" Height="23" Margin="130,430,0,0" HorizontalAlignment="Center" VerticalAlignment="Center"/>
					</Grid>
				</StackPanel>
			</ScrollViewer>
		</Window>
"@
 
#Read XAML
	Try {
		$Window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $Profile_Dialog_XAML) )
	} Catch {
		$XAML_Problem = $True
	}

	If ($XAML_Problem) {
		Write-Log $LogFullFileName "[ERROR]		Unable to load Windows.Markup.XamlReader. Some possible causes for this problem include: .NET Framework is missing PowerShell must be launched with PowerShell -sta, invalid XAML code was encountered."
		$Selection_1 = @()
		$Selection_2 = "0"
		$Selection_3 = "0"
		Return @($Selection_1; $Selection_2; $Selection_3)
	} Else {
#		ForEach ($Name in ($Profile_Dialog_XAML | Select-Xml '//*/@Name' | ForEach { $_.Node.Value})) {
#			New-Variable -Name $Name -Value $Window.FindName($Name) -Force
#		}
##		$Profile_Dialog_XAML.SelectNodes("//*[@Name]") | %{Set-Variable -Name ($_.Name) -Value $Window.FindName($_.Name)}

		$ListView = $Window.FindName('ListView')
		$CheckboxSelectAll = $Window.FindName('SelectAll')
		$CheckboxBackupFolders = $Window.FindName('BackupFolders')
		$CheckboxRemoveFolders = $Window.FindName('RemoveFolders')
		$ButtonOK = $Window.FindName('OK')
		$ButtonCancel = $Window.FindName('Cancel')

		ForEach ($ProfileArray In $ProfileList) {
			ForEach ($ProfileCurrent In $ProfileArray) {
# Store Form Objects In PowerShell
#				If ($ProfileCurrent.Loaded -eq $False) {
#					$ListViewItem = New-Object -TypeName "PSCustomObject"
					$ListViewItem = New-Object PSObject
					Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "ID" -Value $ProfileCurrent.ID
					Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "ComputerName" -Value $ProfileCurrent.ComputerName
					Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "ComputerDescription" -Value $ProfileCurrent.ComputerDescription
					Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "LocalPath" -Value $ProfileCurrent.LocalPath
					Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "UserName" -Value $ProfileCurrent.UserName
					Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "UserDescription" -Value $ProfileCurrent.UserDescription
					If ($ProfileCurrent.LastUseTime -ne "") {
						Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "LastUseTime" -Value ([System.Management.ManagementDateTimeConverter]::ToDateTime($ProfileCurrent.LastUseTime))
					} Else {
						Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "LastUseTime" -Value ""
					}
					Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "Loaded" -Value $ProfileCurrent.Loaded
					Add-Member -InputObject $ListViewItem -MemberType NoteProperty -Name "SID" -Value $ProfileCurrent.SID
					$ListView.Items.Add($ListViewItem)
					Remove-Variable -Name ListViewItem -ErrorAction SilentlyContinue
#				}
#				$ListView.Items.Add([pscustomobject]@{
#					ID = $ProfileCurrent.ID;
#					ComputerName = $ProfileCurrent.ComputerName;
#					ComputerDescription = $ProfileCurrent.ComputerDescription;
#					LocalPath = $ProfileCurrent.LocalPath;
#					UserName = $ProfileCurrent.UserName;
#					UserDescription = $ProfileCurrent.UserDescription;
#					LastUseTime = ([System.Management.ManagementDateTimeConverter]::ToDateTime($ProfileCurrent.LastUseTime));
#					Loaded = $ProfileCurrent.Loaded;
#					SID = $ProfileCurrent.SID
#				})
			}
		}

		$script:ColumnHeaders = @{"ID"=""; "ComputerName"=""; "ComputerDescription"=""; "LocalPath" = ""; "UserName" = ""; "UserDescription" = ""; "LastUseTime" = ""; "Loaded" = ""; "SID" = ""}
		$script:ColumnHeaders.GetEnumerator() | % { 
			$ColumnHeaderName = $($_.key)
#			$ColumnHeaderValue = $($_.value)
			($Window.FindName($ColumnHeaderName + "Header")).Add_Click({
				param ($ColumnHeader)
				$ColumnHeaderName = $ColumnHeader.Name.Replace("Header", "")
				$ColumnHeaderValue = $script:ColumnHeaders[$ColumnHeaderName]
				$Listview.Items.SortDescriptions.Clear()
				If ($ColumnHeaderValue -eq "descending") {
					$Listview.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription ($ColumnHeaderName, "Ascending")))
					$Listview.Items.Refresh()
					$script:ColumnHeaders[$ColumnHeaderName] = "ascending"
				} ElseIf ($ColumnHeaderValue -eq "ascending") {
					$Listview.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($ColumnHeaderName, "Descending")))
					$Listview.Items.Refresh()
					$script:ColumnHeaders[$ColumnHeaderName] = "descending"
				} Else {
					$Listview.Items.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($ColumnHeaderName, "Ascending")))
					$Listview.Items.Refresh()
					$script:ColumnHeaders[$ColumnHeaderName] = "ascending"
				}
			})
		}

		$ListView.Add_SelectionChanged({
			If ($ListView.SelectedItems.Count -gt 0) {
#				[System.Windows.Forms.MessageBox]::Show(("Выбрана позиция: " + $ListView.SelectedItem.ID + " (" + $ListView.SelectedItem.ComputerName + ": " + $ListView.SelectedItem.LocalPath + ")"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
# Remove "passive" from selected:
				$SelectedItemsRemove = @()
				If ($ListView.SelectedItems.Count -gt 1) {
					ForEach ($SelectedItem In $ListView.SelectedItems) {
						If ($SelectedItem.Loaded -eq $True) {
							$SelectedItemsRemove += , $SelectedItem
						}
					}
				} Else {
					If ($ListView.SelectedItem.Loaded -eq $True) {
						$SelectedItemsRemove += , $ListView.SelectedItem
					}
				}
				ForEach ($SelectedItem In $SelectedItemsRemove) {
					$ListView.SelectedItems.Remove($SelectedItem)
				}
				Remove-Variable -Name SelectedItem -ErrorAction SilentlyContinue
				Remove-Variable -Name SelectedItemsRemove -ErrorAction SilentlyContinue
# Check if all "active" are selected:
				$FlagAllSelected = "yes"
				ForEach ($CurrentItem In $ListView.Items) {
					If ($CurrentItem.Loaded -ne $True) {
						$FlagItemChecked = "no"
						If ($ListView.SelectedItems.Count -gt 1) {
							ForEach ($SelectedItem In $ListView.SelectedItems) {
								If ($CurrentItem.ID -eq $SelectedItem.ID) {
									$FlagItemChecked = "yes"
								}
							}
							Remove-Variable -Name SelectedItem -ErrorAction SilentlyContinue
						} Else {
							If ($CurrentItem.ID -eq $ListView.SelectedItem.ID) {
								$FlagItemChecked = "yes"
							}
						}
						If (($FlagItemChecked -eq "yes") -and ($FlagAllSelected -eq "yes")) {
							$FlagAllSelected = "yes"
						} Else {
							$FlagAllSelected = "no"
						}
						Remove-Variable -Name FlagItemChecked -ErrorAction SilentlyContinue
					}
				}
				Remove-Variable -Name CurrentItem -ErrorAction SilentlyContinue
# Save selection if not all selected:
				If ($FlagAllSelected -eq "yes") {
					$script:SavedSelectedItems = @()
					$CheckboxSelectAll.IsChecked = $True
				} Else {
					$SelectedItems = @()
					If ($ListView.SelectedItems.Count -gt 1) {
						ForEach ($SelectedItem In $ListView.SelectedItems) {
							$SelectedItems += , $SelectedItem
						}
						Remove-Variable -Name SelectedItem -ErrorAction SilentlyContinue
					} Else {
						$SelectedItems += , $ListView.SelectedItem
					}
					$script:SavedSelectedItems = $SelectedItems
					Remove-Variable -Name SelectedItems -ErrorAction SilentlyContinue
					$CheckboxSelectAll.IsChecked = $False
				}
			} Else {
				$script:SavedSelectedItems = @()
				$CheckboxSelectAll.IsChecked = $False
			}
#			[System.Windows.Forms.MessageBox]::Show(("Выбрано:" + $Window.CurrentCell.RowIndex), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
		})

#		$CheckboxSelectAll.Add_Checked({})
#		$CheckboxSelectAll.Add_UnChecked({})
		$CheckboxSelectAll.Add_Click({

# Checked "CheckboxSelectAll"
			If ($CheckboxSelectAll.IsChecked -eq $True) {
#				[System.Windows.Forms.MessageBox]::Show(("Выбрать всех - да"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
				ForEach ($CurrentItem In $ListView.Items) {
					If ($CurrentItem.Loaded -ne $True) {
						$FlagItemAdd = "yes"
						If ($ListView.SelectedItems.Count -gt 0) {
							If ($ListView.SelectedItems.Count -gt 1) {
								ForEach ($SelectedItem In $ListView.SelectedItems) {
									If ($CurrentItem.ID -eq $SelectedItem.ID) {
										$FlagItemAdd = "no"
									}
								}
							} Else {
								If ($CurrentItem.ID -eq $ListView.SelectedItem.ID) {
									$FlagItemAdd = "no"
								}
							}
						}
						If ($FlagItemAdd -eq "yes") {
							$SelectedItems += , $CurrentItem
						}
						Remove-Variable -Name FlagItemAdd -ErrorAction SilentlyContinue
					}
				}
				If ($SelectedItems.Count -gt 0) {
					ForEach ($CurrentItem In $SelectedItems) {
						$ListView.SelectedItems.Add($CurrentItem)
					}
				}
				Remove-Variable -Name SelectedItems -ErrorAction SilentlyContinue
			}
# UnChecked "CheckboxSelectAll"
			If ($CheckboxSelectAll.IsChecked -eq $False) {
#				[System.Windows.Forms.MessageBox]::Show(("Выбрать всех - нет"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
				$ListView.UnselectAll()
				If ($FlagManualSelection -eq $False) {
					$SavedSelectedItems = $script:SavedSelectedItems
					If ($SavedSelectedItems.Count -gt 0) {
						ForEach ($CurrentItem In $SavedSelectedItems) {
							$ListView.SelectedItems.Add($CurrentItem)
						}
					}
					$script:SavedSelectedItems = @()
					Remove-Variable -Name SavedSelectedItems -ErrorAction SilentlyContinue
				}
			}
		})
		$ButtonOK.Add_Click({
			$script:objSelection = New-Object -TypeName PSCustomObject
			If ($ListView.SelectedItems.Count -gt 0) {
				$ProfileList = @()
				[System.Windows.Forms.MessageBox]::Show(("Всего выбрано: " + $ListView.SelectedItems.Count), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
				If ($ListView.SelectedItems.Count -gt 1) {
					ForEach ($CurrentItem In $ListView.SelectedItems) {
#						[System.Windows.Forms.MessageBox]::Show(("Выбрана позиция: " + $CurrentItem.ID + " (" + $CurrentItem.ComputerName + ": " + $CurrentItem.LocalPath + ")"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
						$ProfileList += , $CurrentItem
					}
				} Else {
#					[System.Windows.Forms.MessageBox]::Show(("Выбрана позиция: " + $ListView.SelectedItem.ID + " (" + $ListView.SelectedItem.ComputerName + ": " + $ListView.SelectedItem.LocalPath + ")"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
					$ProfileList += $ListView.SelectedItem
				}
				Add-Member -InputObject $script:objSelection -MemberType NoteProperty -Name "Selection_1" -Value $ProfileList
				Remove-Variable -Name ProfileList -ErrorAction SilentlyContinue
				If ($CheckboxBackupFolders.IsChecked -eq $True) {
#					[System.Windows.Forms.MessageBox]::Show(("Создать архивную копию папки удаляемого профиля"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
					Add-Member -InputObject $script:objSelection -MemberType NoteProperty -Name "Selection_2" -Value "1"
				} Else {
					Add-Member -InputObject $script:objSelection -MemberType NoteProperty -Name "Selection_2" -Value "0"
				}
				If ($CheckboxRemoveFolders.IsChecked -eq $True) {
#					[System.Windows.Forms.MessageBox]::Show(("Принудительно очистить папку удаляемого профиля"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
					Add-Member -InputObject $script:objSelection -MemberType NoteProperty -Name "Selection_3" -Value "1"
				} Else {
					Add-Member -InputObject $script:objSelection -MemberType NoteProperty -Name "Selection_3" -Value "0"
				}
				$Window.Close()
			} Else {
				[System.Windows.Forms.MessageBox]::Show(("Не выбрано ни одной позиции"), "Информация" , 0, [System.Windows.Forms.MessageBoxIcon]::Information) | out-null
			}
		})
		$ButtonCancel.Add_Click({
			$Window.Close()
		})
 
		$Window.ShowDialog() | Out-Null

		Remove-Variable -Name SavedSelectedItems -Scope Script -ErrorAction SilentlyContinue
		Remove-Variable -Name ColumnHeaders -Scope Script -ErrorAction SilentlyContinue
		If ($script:objSelection) {
			$Selection = $script:objSelection
			Remove-Variable -Name objSelection -Scope Script -ErrorAction SilentlyContinue
			Return $Selection
		} Else {
			$Selection_1 = @()
			$Selection_2 = "0"
			$Selection_3 = "0"
			Return @($Selection_1; $Selection_2; $Selection_3)
		}
	}
}

Function Profile_Action ($LogFullFileName, $PathTemp, $PathBackup, $7zip, $Credential, $Selection) {
	$Selection_1 = $Selection.Selection_1
	$Selection_2 = $Selection.Selection_2
	$Selection_3 = $Selection.Selection_3
	If ((($Selection_1 | Measure-Object).Count) -gt 0) {
		Write-Log $LogFullFileName ("[INFO]	Выбран(ы) " + (($Selection_1 | Measure-Object).Count) + " профиль(я/ей) для удаления.")
		ForEach ($CurrentProfile In $Selection_1) {
			Write-Log $LogFullFileName ("[INFO]	Данные по выбору: удаляем профиль на ПК """ + $CurrentProfile.ComputerName + """ в папке: " + $CurrentProfile.LocalPath)
			If ($ObjSelection.Selection_2 -eq 1) {
				Write-Log $LogFullFileName "[INFO]	Данные по выбору: создаем архивную копию папки удаляемого профиля."

#		$SourceNetworkDrive = new-object -ComObject WScript.Network
#		$SourceNetworkDrive.MapNetworkDrive($SourceDriveLetter, $SourceServerPath, $false, $Login, $Password)
#		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "[RESULT]	Connected source drive '" + $SourceDriveLetter + "' ('" + $SourceServerPath + "')."

#		$SourceDriveSpace = Get-WmiObject -Class Win32_LogicalDisk -Computername localhost | WHERE {$_.DeviceID -eq $SourceDriveLetter}
#		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "[INFO]	Source drive '" + $SourceDriveLetter + "' free space: " + (Format-FileSize -size $SourceDriveSpace.FreeSpace) + " (of total: " + (Format-FileSize -size $SourceDriveSpace.Size) + ")."

#		$DestinationDriveSpace = Get-WmiObject -Class Win32_LogicalDisk -Computername localhost | WHERE {$_.DeviceID -eq $DestinationDriveLetter}
#		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "[INFO]	Destination drive '" + $DestinationDriveLetter + "' free space: " + (Format-FileSize -size $DestinationDriveSpace.FreeSpace) + " (of total: " + (Format-FileSize -size $DestinationDriveSpace.Size) + ")."


#							$CopyTime = Measure-Command -Expression {
#								Copy-Item -Path $SourceFileCurrent -Destination $DestinationFileCurrent -Force | Out-Null
#							}

#		$SourceNetworkDrive.RemoveNetworkDrive($SourceDriveLetter)
#		$MessageText = (Get-Date -format "HH:mm:ss dd-MM-yyyy") + "	" + "[RESULT]	Disconnected drive '" + $SourceDriveLetter + "'."

				If ((Test-Path ($PathTemp)) -eq $true) {
					Remove-Item $PathTemp -Recurse -Force
				}
				Write-Log $LogFullFileName ("[INFO]	Creating temp folder: " + $PathTemp)
				New-Item -ItemType directory -Path $PathTemp | Out-Null
				If ((Test-Path ($PathBackup)) -ne $true) {
					Write-Log $LogFullFileName ("[INFO]	Creating backup destination folder: " + $PathBackup)
					New-Item -ItemType directory -Path $PathBackup | Out-Null
				}
				If (-not (Test-Path $7zip)) {
					Write-Log $LogFullFileName ("[ERROR]		FILE NOT FOUND '" + $7zip + "'")
#					throw "ERROR: FILE NOT FOUND '" + $7zip + "'"
				} Else {
					Start-Sleep -m 100
					Set-Alias 7z $7zip
					Write-Log $LogFullFileName ("[RESULT]	Creating archive " + $PathBackup + "\" + (Get-Date -format "yyyy-MM-dd") + "_" + $CurrentProfile.ComputerName + "_" + $CurrentProfile.LocalPath + ".7z")
##					7z a -t7z -mx9 ($PathBackup + "\" + (Get-Date -format "yyyy-MM-dd") + "_" + $CurrentProfile.ComputerName + "_" + $CurrentProfile.LocalPath) ($PathTemp + "\*") | Out-Null
# !!!!!!!!!!!!!!!!!!!
#					7z a -t7z -mx9 ($PathBackup + "\" + (Get-Date -format "yyyy-MM-dd") + "_" + $CurrentProfile.ComputerName + "_" + $CurrentProfile.LocalPath) ($PathTemp + "\*")
				}
				If ((Test-Path ($PathTemp)) -eq $true) {
					Write-Log $LogFullFileName ("[INFO]	Removing temp folder: " + $PathTemp)
					Remove-Item $PathTemp -Recurse -Force
				}
			} Else {
				Write-Log $LogFullFileName "[INFO]	Данные по выбору: удаляем профиль без создания архивной копии."
			}
			If ($ObjSelection.Selection_3 -eq 1) {
				Write-Log $LogFullFileName "[INFO]	Данные по выбору: принудительно очищаем папку удаляемого профиля."
			}
		}
	}
}

$Credential = Get_Credential $Login $Password $LogFullFileName
If ($Credential -ne $null) {
	If (($LDAP -ne "") -and ($LDAP -ne $null)) {
		[array]$ComputerList = Computer_Search $LDAP $LogFullFileName
		[array]$ComputerList = Computer_Dialog $LogFullFileName $ComputerList
		If ((($ComputerList.Selection | Measure-Object).Count) -gt 0) {
			[array]$ProfileList = Profile_Search $LDAP $LogFullFileName $Credential $ComputerList
			If ((($ProfileList | Measure-Object).Count) -gt 0) {
				[array]$Selection = Profile_Dialog $LogFullFileName $ProfileList
				If ((($Selection.Selection_1 | Measure-Object).Count) -gt 0) {
					Profile_Action $LogFullFileName $PathTemp $PathBackup $7zip $Credential $Selection
				} Else {
					Write-Log $LogFullFileName "[RESULT]	Не выбрано ни одного профиля для удаления."
				}
			} Else {
				Write-Log $LogFullFileName "[RESULT]	Не найдено ни одного профиля для удаления."
			}
		} Else {
			Write-Log $LogFullFileName "[RESULT]	Не выбрано ни одного компьютера для поиска профилей."
		}
	} Else {
		Write-Log $LogFullFileName "[RESULT]	Не задано значение для поиска по LDAP."
	}
} Else {
	Write-Log $LogFullFileName "[RESULT]	Не заданы значения для подключения к компьютеру (логин и пароль)."
}
Write-Log $LogFullFileName "[END]"

Remove-Variable -Name MessageText -Scope Script -ErrorAction SilentlyContinue
Remove-Variable -Name LogFullFileName -Scope Script -ErrorAction SilentlyContinue
Remove-Variable -Name LogFileName -Scope Script -ErrorAction SilentlyContinue
Remove-Variable -Name LogPath -Scope Script -ErrorAction SilentlyContinue
Remove-Variable -Name Password -Scope Script -ErrorAction SilentlyContinue
Remove-Variable -Name Login -Scope Script -ErrorAction SilentlyContinue
Remove-Variable -Name LDAP -Scope Script -ErrorAction SilentlyContinue
