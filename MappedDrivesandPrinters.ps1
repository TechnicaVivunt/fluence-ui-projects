<#
.SYNOPSIS
    Remote Mapped Drives, User Printers, and Local Printers Lookup (Inkore Fluent UI)

.DESCRIPTION
    - Enter a computer name (default: local)
    - Load user profiles from that computer
    - For selected user, remotely gather:
        * Mapped drives
        * User-mapped printers
        * Local printers (Print Management)
    - Generate a batch file to remap drives/printers and echo local printers
#>

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -Path (Join-Path $scriptRoot "Fluence.Wpf.dll")

$app = [System.Windows.Application]::Current
if (-not $app) { $app = New-Object System.Windows.Application }

[Fluence.Wpf.ApplicationThemeManager]::Apply(
    [Fluence.Wpf.ApplicationTheme]::Auto,
    [Fluence.Wpf.BackdropType]::Mica,
    $true)

[Fluence.Wpf.ApplicationAccentColorManager]::ApplyCustomAccent(
    [System.Windows.Media.Color]::FromRgb(0x02, 0x3C, 0x74)
)



# -----------------------------
# Shared Styles
# -----------------------------
$stylesXaml = @"
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    xmlns:ui="clr-namespace:Fluence.Wpf.Controls;assembly=Fluence.Wpf">
    <SolidColorBrush x:Key="AccentFillColorDefaultBrush" Color="#023c74"/>
    <SolidColorBrush x:Key="AccentFillColorSecondaryBrush" Color="#023c74"/>
    <SolidColorBrush x:Key="AccentFillColorTertiaryBrush" Color="#023c74"/>
    <SolidColorBrush x:Key="AccentFillColorDisabledBrush" Color="#023c74"/>
    <Style x:Key="UnifiedButton"
           TargetType="ui:Button"
           BasedOn="{StaticResource {x:Type ui:Button}}">

        <Setter Property="Appearance" Value="Accent"/>
        <Setter Property="FontSize" Value="14"/>
        <Setter Property="Padding" Value="12,6"/>
        <Setter Property="Height" Value="44"/>
        <Setter Property="HorizontalAlignment" Value="Stretch"/>

    </Style>

</ResourceDictionary>
"@





$globalStyles = [System.Windows.Markup.XamlReader]::Parse($stylesXaml)

# -----------------------------
# XAML UI
# -----------------------------
$localComputer = $env:COMPUTERNAME

$mainXaml = @"
<ui:FluenceWindow
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:ui="clr-namespace:Fluence.Wpf.Controls;assembly=Fluence.Wpf"
    Title="Mapped Resources Lookup"
    Width="820"
    Height="750"
    WindowStartupLocation="CenterScreen"
    SystemBackdropType="Mica"
    ExtendsContentIntoTitleBar="True"
    Background="Transparent">

    <DockPanel>

        <!-- MAIN CONTENT -->
        <StackPanel Margin="24,24,24,0">

            <!-- PAGE HEADER -->
            <StackPanel Margin="0,0,0,20">
                <TextBlock Text="Mapped Drives &amp; Printers Lookup"
                           ui:TextBlockExtensions.Typography="TitleLarge"
                           FontSize="28"
                           FontWeight="Bold"
                           Foreground="{DynamicResource TextFillColorPrimaryBrush}"/>

                <TextBlock x:Name="ComputerLabel"
                           Text="Target Computer:"
                           ui:TextBlockExtensions.Typography="Subtitle"
                           FontSize="16"
                           Margin="0,4,0,0"
                           Foreground="{DynamicResource TextFillColorSecondaryBrush}"/>
            </StackPanel>


            <!-- COMPUTER INPUT -->
            <TextBlock Text="Computer Name:"
                       ui:TextBlockExtensions.Typography="Title"
                       Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                       FontSize="14"
                       Margin="0,0,0,4"/>

            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                <TextBox x:Name="ComputerInput"
                         ui:TextBlockExtensions.Typography="Display"
                         Width="220"
                         Height="32"
                         FontSize="14"
                         Margin="0,0,10,0"/>

                <ui:Button x:Name="LoadUsersBtn"
                           Style="{DynamicResource UnifiedButton}"
                           Content="Load Users"
                           Height="32"
                           MinWidth="140"/>
            </StackPanel>


            <!-- USER SELECTION -->
            <TextBlock Text="Select user profile:"
                       ui:TextBlockExtensions.Typography="Subtitle"
                       Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                       FontSize="14"
                       Margin="0,12,0,4"/>

            <ComboBox x:Name="UserCombo"
                      Height="32"
                      FontSize="14"
                      MinWidth="360"/>


            <!-- LOOKUP BUTTON -->
            <ui:Button x:Name="LookupBtn"
                       Style="{DynamicResource UnifiedButton}"
                       Content="Lookup Mapped Resources"
                       Margin="0,15,0,0"/>


            <!-- OUTPUT BOX -->
            <Border Background="{DynamicResource LayerFillColorDefaultBrush}"
            CornerRadius="6"
            Padding="10"
            Margin="0,20,0,0">

            <TextBox x:Name="OutputBox"
                 FontSize="14"
                 AcceptsReturn="True"
                 VerticalScrollBarVisibility="Auto"
                 BorderThickness="0"
                 Background="Transparent"
                 Foreground="{DynamicResource TextFillColorPrimaryBrush}"
                 IsReadOnly="True"
                 TextWrapping="Wrap"
                 Height="200"/>
            </Border>

            <!-- SAVE BATCH BUTTON -->
            <ui:Button x:Name="SaveBatchBtn"
                       Style="{DynamicResource UnifiedButton}"
                       Content="Generate Remap Batch File"
                       Margin="0,10,0,0"/>


            <!-- CLOSE BUTTON -->
            <ui:Button x:Name="CloseBtn"
                       Style="{DynamicResource UnifiedButton}"
                       Content="Close"
                       Margin="0,20,0,0"/>

        </StackPanel>

    </DockPanel>
</ui:FluenceWindow>
"@


[xml]$xmlMain = $mainXaml
$window = [System.Windows.Markup.XamlReader]::Parse($mainXaml)


$window.Resources.MergedDictionaries.Add($globalStyles)

# -----------------------------
# Bind controls
# -----------------------------
$HeaderTitle   = $window.FindName("HeaderTitle")
$ComputerLabel = $window.FindName("ComputerLabel")
$ComputerInput = $window.FindName("ComputerInput")
$LoadUsersBtn  = $window.FindName("LoadUsersBtn")
$UserCombo     = $window.FindName("UserCombo")
$LookupBtn     = $window.FindName("LookupBtn")
$OutputBox     = $window.FindName("OutputBox")
$SaveBatchBtn  = $window.FindName("SaveBatchBtn")
$CloseBtn      = $window.FindName("CloseBtn")

$window.Title = "Mapped Resources - $localComputer"
$ComputerLabel.Text = "Target Computer:"
$ComputerInput.Text = $localComputer
$OutputBox.FontFamily = "Consolas"

# Track current target computer
$script:CurrentComputer = $localComputer

# -----------------------------
# Remote helper: get user profiles
# -----------------------------
function Invoke-RemoteGetUsers {
    param(
        [string]$ComputerName
    )

    $sb = {
        function Get-LocalUserProfiles {
            $profileListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
            $profiles = @()

            Get-ChildItem $profileListKey | ForEach-Object {
                $sid = $_.PSChildName

                if ($sid -notmatch '^S-1-5-21-\d+-\d+-\d+-\d+$') {
                    return
                }

                $props = Get-ItemProperty $_.PsPath
                $profilePath = $props.ProfileImagePath

                $friendly = $null
                try {
                    $sidObj = New-Object System.Security.Principal.SecurityIdentifier($sid)
                    $nt     = $sidObj.Translate([System.Security.Principal.NTAccount])
                    $friendly = $nt.Value
                } catch {
                    $friendly = "Unknown user"
                }

                $profiles += [PSCustomObject]@{
                    SID          = $sid
                    FriendlyName = $friendly
                    ProfilePath  = $profilePath
                }
            }

            return $profiles
        }

        Get-LocalUserProfiles
    }

    try {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $sb -ErrorAction Stop
    } catch {
        throw $_
    }
}

# -----------------------------
# Remote helper: get resources for user
# -----------------------------
function Invoke-RemoteGetResources {
    param(
        [string]$ComputerName,
        [string]$SID,
        [string]$ProfilePath
    )

    $sb = {
        param($sid, $profilePath)

        function Get-MappedDrivesForUser {
            param(
                [string]$SID,
                [string]$ProfilePath
            )

            $tempHiveName = $null
            $rootKey      = $null
            $loadedTemp   = $false

            $liveRoot = "Registry::HKEY_USERS\$SID"
            if (Test-Path $liveRoot) {
                $rootKey = $liveRoot
            }
            else {
                $ntUserDat = Join-Path $ProfilePath 'NTUSER.DAT'
                if (-not (Test-Path $ntUserDat)) {
                    return @()
                }

                $tempHiveName = "TempHive_$($SID.Replace('-','_'))"
                $hkuTemp      = "HKU\$tempHiveName"
                $rootKey      = "Registry::HKEY_USERS\$tempHiveName"

                try {
                    reg load $hkuTemp $ntUserDat | Out-Null
                    $loadedTemp = $true
                } catch {
                    return @()
                }
            }

            $driveKey = Join-Path $rootKey 'Network'
            $results  = @()

            if (Test-Path $driveKey) {
                Get-ChildItem $driveKey | ForEach-Object {
                    $letter = $_.PSChildName
                    $props  = Get-ItemProperty $_.PsPath
                    $path   = $props.RemotePath
                    $results += [PSCustomObject]@{
                        DriveLetter = $letter
                        Path        = $path
                    }
                }
            }

            if ($loadedTemp -and $tempHiveName) {
                reg unload "HKU\$tempHiveName" | Out-Null
            }

            return $results
        }

        function Get-MappedPrintersForUser {
            param(
                [string]$SID,
                [string]$ProfilePath
            )

            $tempHiveName = $null
            $rootKey      = $null
            $loadedTemp   = $false

            $liveRoot = "Registry::HKEY_USERS\$SID"
            if (Test-Path $liveRoot) {
                $rootKey = $liveRoot
            }
            else {
                $ntUserDat = Join-Path $ProfilePath 'NTUSER.DAT'
                if (-not (Test-Path $ntUserDat)) {
                    return @()
                }

                $tempHiveName = "TempHive_$($SID.Replace('-','_'))"
                $hkuTemp      = "HKU\$tempHiveName"
                $rootKey      = "Registry::HKEY_USERS\$tempHiveName"

                try {
                    reg load $hkuTemp $ntUserDat | Out-Null
                    $loadedTemp = $true
                } catch {
                    return @()
                }
            }

            $printerKey = Join-Path $rootKey 'Printers\Connections'
            $results    = @()

            if (Test-Path $printerKey) {
                Get-ChildItem $printerKey | ForEach-Object {
                    $raw = $_.PSChildName
                    $clean = $raw -replace ',', '\'
                    if ($clean -notmatch '^\\\\') {
                        $clean = "\\$clean"
                    }

                    $results += [PSCustomObject]@{
                        PrintServer = ($clean -split '\\')[2]
                        PrinterName = ($clean -split '\\')[3]
                        FullPath    = $clean
                    }
                }
            }

            if ($loadedTemp -and $tempHiveName) {
                reg unload "HKU\$tempHiveName" | Out-Null
            }

            return $results
        }

        function Get-LocalPrinters {
            try {
                $printers = Get-Printer -ErrorAction Stop
                $ports    = Get-PrinterPort -ErrorAction Stop

                $results = foreach ($p in $printers) {
                    $port = $ports | Where-Object { $_.Name -eq $p.PortName }

                    [PSCustomObject]@{
                        Name       = $p.Name
                        PortName   = $p.PortName
                        DriverName = $p.DriverName
                        PortInfo   = if ($port) { $port.PrinterHostAddress } else { "" }
                    }
                }

                return $results
            }
            catch {
                return @()
            }
        }

        [PSCustomObject]@{
            Drives        = Get-MappedDrivesForUser   -SID $sid -ProfilePath $profilePath
            Printers      = Get-MappedPrintersForUser -SID $sid -ProfilePath $profilePath
            LocalPrinters = Get-LocalPrinters
        }
    }

    try {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $sb -ArgumentList $SID, $ProfilePath -ErrorAction Stop
    } catch {
        throw $_
    }
}

# -----------------------------
# Load Users button
# -----------------------------
$LoadUsersBtn.Add_Click({
    $comp = $ComputerInput.Text.Trim()
    if (-not $comp) {
        $comp = $localComputer
        $ComputerInput.Text = $comp
    }

    $script:CurrentComputer = $comp
    $OutputBox.Text = "Loading user profiles from $comp ..."
    $UserCombo.Items.Clear()

    try {
        $profiles = Invoke-RemoteGetUsers -ComputerName $comp

        if (-not $profiles -or $profiles.Count -eq 0) {
            $OutputBox.Text = "No user profiles found on $comp."
            return
        }

        foreach ($u in $profiles) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = "{0} ({1})" -f $u.FriendlyName, $u.SID
            $item.Tag     = $u
            [void]$UserCombo.Items.Add($item)
        }

        $UserCombo.SelectedIndex = 0
        $OutputBox.Text = "Loaded $($profiles.Count) user profile(s) from $comp."
        $ComputerLabel.Text = "Target Computer: $comp"
    }
    catch {
        $OutputBox.Text = "Failed to load users from $comp.`r`n$_"
    }
})

# -----------------------------
# Lookup button
# -----------------------------
$LookupBtn.Add_Click({
    $selected = $UserCombo.SelectedItem
    if (-not $selected) {
        $OutputBox.Text = "Please load users and select a user profile."
        return
    }

    $userObj = $selected.Tag
    $comp    = $script:CurrentComputer

    $OutputBox.Text = "Collecting mapped drives, printers, and local printers from $comp for:`r`n$userObj.FriendlyName ($($userObj.SID))..."

    try {
        $res = Invoke-RemoteGetResources -ComputerName $comp -SID $userObj.SID -ProfilePath $userObj.ProfilePath

        $drives        = $res.Drives
        $printers      = $res.Printers
        $localPrinters = $res.LocalPrinters

        $drivesText = if (-not $drives -or $drives.Count -eq 0) {
            "No mapped drives found."
        } else {
            ($drives | ForEach-Object {
                "Drive {0}:  {1}" -f $_.DriveLetter, $_.Path
            }) -join "`r`n"
        }

        $printersText = if (-not $printers -or $printers.Count -eq 0) {
            "No mapped printers found."
        } else {
            ($printers | ForEach-Object {
                $_.FullPath
            }) -join "`r`n"
        }

        $localPrinterText = if (-not $localPrinters -or $localPrinters.Count -eq 0) {
            "No local printers installed."
        } else {
            ($localPrinters | ForEach-Object {
                "Name: $($_.Name)`r`nPort: $($_.PortName)`r`nDriver: $($_.DriverName)`r`n"
            }) -join "`r`n"
        }

        $OutputBox.Text = @"
Computer: $comp
User: $($userObj.FriendlyName) ($($userObj.SID))
Profile: $($userObj.ProfilePath)

=== MAPPED DRIVES ===
$drivesText

=== MAPPED PRINTERS ===
$printersText

=== LOCAL PRINTERS (Print Management) ===
$localPrinterText
"@
    }
    catch {
        $OutputBox.Text = "Failed to gather resources from $comp.`r`n$_"
    }
})

# -----------------------------
# Batch file generator
# -----------------------------
$SaveBatchBtn.Add_Click({
    $selected = $UserCombo.SelectedItem
    if (-not $selected) {
        $OutputBox.Text = "Please load users and select a user profile first."
        return
    }

    $userObj = $selected.Tag
    $comp    = $script:CurrentComputer

    try {
        $res = Invoke-RemoteGetResources -ComputerName $comp -SID $userObj.SID -ProfilePath $userObj.ProfilePath

        $drives        = $res.Drives
        $printers      = $res.Printers
        $localPrinters = $res.LocalPrinters

        $batch = @()
        $batch += "@echo off"
        $batch += "echo Remapping drives and printers for $($userObj.FriendlyName) on $comp"
        $batch += "echo."

        foreach ($d in $drives) {
            if ($d.Path -and $d.DriveLetter) {
                $batch += "echo Mapping drive $($d.DriveLetter): to $($d.Path)"
                $batch += "net use $($d.DriveLetter): `"$($d.Path)`" /persistent:yes"
            }
        }

        foreach ($p in $printers) {
            if ($p.FullPath) {
                $batch += "echo Adding printer $($p.FullPath)"
                $batch += "rundll32 printui.dll,PrintUIEntry /in /n `"$($p.FullPath)`""
            }
        }

        $batch += "echo."
        $batch += "echo === LOCAL PRINTERS INSTALLED ON $comp MAKE SURE TO READD THESE MANUALLY ==="

        if ($localPrinters -and $localPrinters.Count -gt 0) {
            foreach ($lp in $localPrinters) {
                $batch += "echo Printer: $($lp.Name)"
                $batch += "echo Port: $($lp.PortName)"
                $batch += "echo Driver: $($lp.DriverName)"
                $batch += "echo."
            }
        } else {
            $batch += "echo No local printers found."
        }

        $batch += "echo."
        $batch += "echo Done."
        $batch += "pause"

        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Filter = "Batch File (*.bat)|*.bat"
        $dialog.FileName = "Remap_${comp}_$($userObj.FriendlyName.Replace('\','_')).bat"

        if ($dialog.ShowDialog() -eq "OK") {
            $batch -join "`r`n" | Out-File -FilePath $dialog.FileName -Encoding ASCII
            $OutputBox.Text = "Batch file saved:`r`n$($dialog.FileName)"
        }
    }
    catch {
        $OutputBox.Text = "Failed to generate batch file from $comp.`r`n$_"
    }
})

$CloseBtn.Add_Click({
    $window.Close()
})

$window.add_Closed({
    # Shut down the WPF dispatcher
    [System.Windows.Threading.Dispatcher]::ExitAllFrames()

    # End the PowerShell runspace
    [System.Environment]::Exit(0)
})

$app.Run($window)
